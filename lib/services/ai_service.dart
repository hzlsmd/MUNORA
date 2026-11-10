import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/weather_snapshot.dart';
import 'activity_planner.dart';
import 'weather_insights.dart';
import 'weather_recommendations.dart';

class AiException implements Exception {
  final String message;
  const AiException(this.message);
}

/// A bounded weather/activity context. No user prompt, GPS, name or routine.
class AiPlan {
  final String _encodedPayload;
  Map<String, dynamic> get payload =>
      jsonDecode(_encodedPayload) as Map<String, dynamic>;
  final PlanStatus status;
  final List<String> hazards;
  final DateTime validUntil;
  final DateTime createdAt;
  String get key => _encodedPayload;
  bool isFresh(DateTime now) =>
      !now.toUtc().isBefore(createdAt) && now.toUtc().isBefore(validUntil);

  AiPlan._(
    Map<String, dynamic> payload,
    this.status,
    this.hazards,
    this.validUntil,
    this.createdAt,
  ) : _encodedPayload = jsonEncode(payload);

  factory AiPlan.fromWeather(
    WeatherSnapshot weather,
    WeatherInsights? insights,
    Activity activity,
    DateTime start,
    int durationHours,
    DateTime now,
  ) {
    final utc = now.toUtc();
    final assessment = assessActivity(
      insights,
      activity,
      start,
      durationHours,
      utc,
    );
    if (!weather.isUsable(utc) ||
        insights == null ||
        assessment.status == PlanStatus.unavailable ||
        weather.updatedAt.isAfter(utc) ||
        weather.observedAt.isAfter(utc)) {
      throw const AiException(
        'Refresh the forecast and choose a complete future plan first.',
      );
    }
    final hours =
        insights.hours
            .where(
              (h) =>
                  !h.at.isBefore(start.toUtc()) &&
                  h.at.isBefore(
                    start.toUtc().add(Duration(hours: durationHours)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    // A severe rule can be assessed even with missing measurements; AI needs all inputs.
    if (hours.length != durationHours || hours.any((h) => !h.complete)) {
      throw const AiException(
        'Complete hourly weather is needed for AI advice. Rule-based guidance remains available.',
      );
    }
    final ids = weatherRecommendations(weather, utc)
        .map((t) => t.id)
        .where((id) => const ['storm', 'rain', 'heat', 'wind'].contains(id))
        .toSet();
    final limits = switch (activity) {
      Activity.commute => (60.0, 35.0, 38.0, 8.0, 10.0),
      Activity.exercise => (30.0, 30.0, 32.0, 6.0, 8.0),
      _ => (40.0, 32.0, 35.0, 6.0, 10.0),
    };
    for (final h in hours) {
      if (h.storm) ids.add('storm');
      if (h.rain! >= limits.$1 || h.code! >= 51 && h.code! <= 86) {
        ids.add('rain');
      }
      if (h.temperature! >= limits.$2 || h.feelsLike! >= limits.$3) {
        ids.add('heat');
      }
      if (h.wind! >= limits.$5) ids.add('wind');
    }
    final hazards = List<String>.unmodifiable(
      const ['storm', 'rain', 'heat', 'wind'].where(ids.contains),
    );
    final hourEnd = DateTime.utc(
      insights.fetchedAt.year,
      insights.fetchedAt.month,
      insights.fetchedAt.day,
      insights.fetchedAt.hour + 1,
    );
    final validUntil = [
      weather.updatedAt.add(const Duration(minutes: 30)),
      weather.observedAt.add(const Duration(hours: 3)),
      insights.fetchedAt.add(const Duration(minutes: 30)),
      hourEnd,
      start.toUtc(),
    ].reduce((a, b) => a.isBefore(b) ? a : b);
    if (!utc.isBefore(validUntil)) {
      throw const AiException(
        'Refresh the forecast before requesting AI advice.',
      );
    }
    final payload = <String, dynamic>{
      'version': 1,
      'city': weather.city,
      'activity': activity.name,
      'start': start.toUtc().toIso8601String(),
      'durationHours': durationHours,
      'forecastUpdatedAt': weather.updatedAt.toIso8601String(),
      'observedAt': weather.observedAt.toIso8601String(),
      'insightsFetchedAt': insights.fetchedAt.toUtc().toIso8601String(),
      'current': {
        'temperature': weather.temperature,
        'feelsLike': weather.feelsLike,
        'wind': weather.windSpeed,
        'condition': weather.current.condition,
      },
      'hazards': hazards,
      'hours': hours
          .map(
            (h) => {
              'at': h.at.toUtc().toIso8601String(),
              'temperature': h.temperature,
              'feelsLike': h.feelsLike,
              'rain': h.rain,
              'uv': h.uv,
              'wind': h.wind,
              'code': h.code,
            },
          )
          .toList(),
    };
    // Freeze nested JSON so the cache key cannot change while a request is running.
    return AiPlan._(
      Map<String, dynamic>.unmodifiable(payload),
      assessment.status,
      hazards,
      validUntil,
      utc,
    );
  }
}

class AiRecommendation {
  final String summary, reason;
  final List<String> preparations;
  final DateTime generatedAt, expiresAt;
  const AiRecommendation({
    required this.summary,
    required this.reason,
    required this.preparations,
    required this.generatedAt,
    required this.expiresAt,
  });
  bool isFresh(DateTime now) =>
      now.toUtc().isBefore(expiresAt) &&
      !now.toUtc().isBefore(generatedAt.subtract(const Duration(seconds: 5)));
}

class AiService {
  final http.Client _client;
  final String endpoint;
  final DateTime Function() now;
  final Duration requestTimeout;
  final _pending = <String, Future<AiRecommendation>>{};
  final _cache = <String, AiRecommendation>{};
  final _aborts = <Completer<void>>{};
  bool _disposed = false;
  AiService({
    http.Client? client,
    this.endpoint = const String.fromEnvironment('AI_RECOMMENDATION_URL'),
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 18),
  }) : _client = client ?? http.Client(),
       now = now ?? DateTime.now;

  bool get configured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  Future<AiRecommendation> recommend(AiPlan plan) {
    if (_disposed || !configured) {
      return Future.error(
        const AiException(
          'AI advice is not connected yet. Your rule-based recommendations are available.',
        ),
      );
    }
    if (!plan.isFresh(now())) {
      return Future.error(
        const AiException(
          'Weather has changed or expired. Check your plan again.',
        ),
      );
    }
    final cached = _cache[plan.key];
    if (cached != null && cached.isFresh(now())) return Future.value(cached);
    return _pending.putIfAbsent(
      plan.key,
      () => _load(plan).whenComplete(() {
        _pending.remove(plan.key);
      }),
    );
  }

  Future<AiRecommendation> _load(AiPlan plan) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    try {
      final raw =
          await (() async {
            final request =
                http.AbortableRequest(
                    'POST',
                    Uri.parse(endpoint),
                    abortTrigger: abort.future,
                  )
                  ..followRedirects = false
                  ..headers['Content-Type'] = 'application/json'
                  ..body = jsonEncode(plan.payload);
            final response = await _client.send(request);
            if (response.statusCode != 200) {
              unawaited(
                response.stream.listen(null).cancel().catchError((Object _) {}),
              );
              throw AiException(
                response.statusCode == 429
                    ? 'The free AI limit has been reached. Use the rule-based tips and try again later.'
                    : 'AI advice is temporarily unavailable. Your rule-based recommendations still work.',
              );
            }
            if ((response.contentLength ?? 0) > 8192) {
              unawaited(
                response.stream.listen(null).cancel().catchError((Object _) {}),
              );
              throw const FormatException('Oversized AI response');
            }
            final bytes = BytesBuilder(copy: false);
            await for (final part in response.stream) {
              if (bytes.length + part.length > 8192) {
                throw const FormatException('Oversized AI response');
              }
              bytes.add(part);
            }
            return jsonDecode(utf8.decode(bytes.takeBytes()))
                as Map<String, dynamic>;
          })().timeout(
            requestTimeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw const AiException(
                'AI advice timed out. Your rule-based recommendations are available.',
              );
            },
          );
      if (_disposed || !plan.isFresh(now())) {
        throw const AiException('Weather has expired. Check your plan again.');
      }
      final result = _parse(raw, plan, now().toUtc());
      _cache.removeWhere((_, v) => !v.isFresh(now()));
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      _cache[plan.key] = result;
      return result;
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException(
        'AI advice could not be verified. Your rule-based recommendations are available.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  AiRecommendation _parse(Map<String, dynamic> data, AiPlan plan, DateTime at) {
    void check(bool ok) {
      if (!ok) throw const FormatException('Invalid AI response');
    }

    for (final key in ['version', 'city', 'activity', 'durationHours']) {
      check(data[key] == plan.payload[key]);
    }
    for (final key in ['start', 'forecastUpdatedAt', 'insightsFetchedAt']) {
      check(
        data[key] is String &&
            DateTime.parse(data[key]) == DateTime.parse(plan.payload[key]),
      );
    }
    check(data['status'] == plan.status.name);
    check(
      data['hazards'] is List &&
          jsonEncode(data['hazards']) == jsonEncode(plan.hazards),
    );
    final generated = DateTime.parse(data['generatedAt'] as String).toUtc();
    final expires = DateTime.parse(data['expiresAt'] as String).toUtc();
    check(
      !generated.isAfter(at.add(const Duration(seconds: 5))) &&
          at.difference(generated) < const Duration(minutes: 10),
    );
    check(
      expires.isAfter(at) &&
          !expires.isAfter(plan.validUntil) &&
          !expires.isAfter(generated.add(const Duration(minutes: 10))),
    );
    String text(dynamic value, int max) {
      check(
        value is String &&
            value.trim().isNotEmpty &&
            value.length <= max &&
            !RegExp(
              r'[\x00-\x1f\x7f\d<>]|https?:|www\.|completely safe|perfectly safe|guaranteed|all.clear|no risk|risk.free|definitely safe',
              caseSensitive: false,
            ).hasMatch(value),
      );
      return (value as String).trim();
    }

    final advice = data['recommendation'] as Map<String, dynamic>;
    final preparations = advice['preparations'];
    check(
      preparations is List &&
          preparations.isNotEmpty &&
          preparations.length <= 5,
    );
    return AiRecommendation(
      summary: text(advice['summary'], 600),
      reason: text(advice['reason'], 600),
      preparations: List.unmodifiable(
        (preparations as List).map((s) => text(s, 240)),
      ),
      generatedAt: generated,
      expiresAt: expires,
    );
  }

  void dispose() {
    _disposed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
    _cache.clear();
  }
}
