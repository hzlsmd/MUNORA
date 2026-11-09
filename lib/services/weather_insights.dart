import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';
import '../models/planning_hour.dart';
import 'open_meteo.dart';

const insightModels = ['ecmwf_ifs025', 'gfs_seamless', 'icon_seamless'];

class WeatherInsights {
  final List<PlanningHour> hours;
  final double? rainProbability,
      uvIndex,
      outdoorTemperature,
      outdoorHumidity,
      outdoorUv;
  final DateTime? outdoorStart, outdoorEnd;
  final int? agreementPercent;
  final DateTime fetchedAt;
  const WeatherInsights({
    required this.fetchedAt,
    this.hours = const [],
    this.rainProbability,
    this.uvIndex,
    this.outdoorTemperature,
    this.outdoorHumidity,
    this.outdoorUv,
    this.outdoorStart,
    this.outdoorEnd,
    this.agreementPercent,
  });

  bool isFresh(DateTime now) =>
      !now.isBefore(fetchedAt) &&
      now.toUtc().hour == fetchedAt.toUtc().hour &&
      now.difference(fetchedAt) < const Duration(minutes: 30);

  static WeatherInsights parse(
    Map<String, dynamic>? detail,
    Map<String, dynamic>? models,
    DateTime now,
  ) {
    double? value(
      Map<String, dynamic>? json,
      String key,
      int i,
      double low,
      double high,
      String unit,
    ) {
      final units = json?['hourly_units'];
      final hourly = json?['hourly'];
      if (units is! Map || hourly is! Map || units[key] != unit) return null;
      final values = hourly[key];
      if (values is! List || i < 0 || i >= values.length) return null;
      final n = values[i];
      return n is num && n.isFinite && n >= low && n <= high
          ? n.toDouble()
          : null;
    }

    List<DateTime> times(Map<String, dynamic>? json) {
      if (json?['hourly_units'] is! Map ||
          json!['hourly_units']['time'] != 'unixtime' ||
          json['hourly'] is! Map) {
        return [];
      }
      final raw = json['hourly']['time'];
      if (raw is! List || raw.isEmpty || raw.length > 96) return [];
      final result = <DateTime>[];
      for (final n in raw) {
        if (n is! int || n < 0 || n > 4102444800) return [];
        final at = DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
        if (result.isNotEmpty &&
            at.difference(result.last) != const Duration(hours: 1)) {
          return [];
        }
        result.add(at);
      }
      return result;
    }

    final hours = times(detail);
    const knownCodes = {
      0,
      1,
      2,
      3,
      45,
      48,
      51,
      53,
      55,
      56,
      57,
      61,
      63,
      65,
      66,
      67,
      71,
      73,
      75,
      77,
      80,
      81,
      82,
      85,
      86,
      95,
      96,
      99,
    };
    final planning = List<PlanningHour>.generate(hours.length, (i) {
      final code = value(detail, 'weather_code', i, 0, 99, 'wmo code');
      return PlanningHour(
        at: hours[i],
        temperature: value(detail, 'temperature_2m', i, -100, 70, '°C'),
        feelsLike: value(detail, 'apparent_temperature', i, -100, 80, '°C'),
        rain: value(detail, 'precipitation_probability', i, 0, 100, '%'),
        uv: value(detail, 'uv_index', i, 0, 30, ''),
        wind: value(detail, 'wind_speed_10m', i, 0, 150, 'm/s'),
        code:
            code != null &&
                code == code.roundToDouble() &&
                knownCodes.contains(code.toInt())
            ? code.toInt()
            : null,
      );
    });
    final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final current = hours.indexOf(hour);
    final rain = value(
      detail,
      'precipitation_probability',
      current,
      0,
      100,
      '%',
    );
    final uv = value(detail, 'uv_index', current, 0, 30, '');
    int? best;
    double? bestScore;
    for (var i = 0; i + 2 < hours.length; i++) {
      if (hours[i].isBefore(now) ||
          hours[i].isAfter(now.add(const Duration(hours: 36)))) {
        continue;
      }
      double score = 0;
      bool eligible = true;
      for (var j = i; j < i + 3; j++) {
        final local = manilaTime(hours[j]);
        final t = value(detail, 'temperature_2m', j, -100, 70, '°C');
        final u = value(detail, 'uv_index', j, 0, 30, '');
        final p = value(detail, 'precipitation_probability', j, 0, 100, '%');
        if (local.hour < 6 ||
            local.hour >= 18 ||
            t == null ||
            u == null ||
            p == null ||
            t > 31 ||
            u > 5 ||
            p > 30 ||
            !planning[j].complete ||
            planning[j].storm ||
            planning[j].wind! >= 10 ||
            planning[j].feelsLike! >= 35 ||
            (planning[j].code! >= 51 && planning[j].code! <= 86)) {
          eligible = false;
          break;
        }
        score += p + t + u;
      }
      if (eligible && (bestScore == null || score < bestScore)) {
        best = i;
        bestScore = score;
      }
    }
    final modelTimes = times(models);
    final next = modelTimes
        .asMap()
        .entries
        .where((e) => !e.value.isBefore(now))
        .take(6)
        .toList();
    double consensus = 0;
    bool complete =
        next.length == 6 &&
        !next.first.value.isAfter(now.add(const Duration(hours: 1)));
    for (final e in next) {
      final readings = insightModels
          .map((m) => value(models, 'precipitation_$m', e.key, 0, 1000, 'mm'))
          .toList();
      if (readings.any((v) => v == null)) {
        complete = false;
        break;
      }
      final wet = readings.where((v) => v! >= .1).length;
      consensus += (wet > 3 - wet ? wet : 3 - wet) / 3;
    }
    return WeatherInsights(
      fetchedAt: now,
      hours: List.unmodifiable(planning),
      rainProbability: rain,
      uvIndex: uv,
      agreementPercent: complete ? (consensus / 6 * 100).round() : null,
      outdoorStart: best == null ? null : hours[best],
      outdoorEnd: best == null
          ? null
          : hours[best].add(const Duration(hours: 3)),
      outdoorTemperature: best == null
          ? null
          : value(detail, 'temperature_2m', best, -100, 70, '°C'),
      outdoorHumidity: best == null
          ? null
          : value(detail, 'relative_humidity_2m', best, 0, 100, '%'),
      outdoorUv: best == null
          ? null
          : value(detail, 'uv_index', best, 0, 30, ''),
    );
  }
}

/// Optional data for the Alerts/Tips panels. Failures never block core weather.
class WeatherInsightsService {
  final http.Client _client;
  final DateTime Function() now;
  final _cache = <String, WeatherInsights>{};
  final _pending = <String, Future<WeatherInsights>>{};
  final _aborts = <Completer<void>>{};
  bool _disposed = false;
  WeatherInsightsService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      now = now ?? DateTime.now;

  Future<Map<String, dynamic>?> _read(Uri uri) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    try {
      final result = await (() async {
        final response = await _client.send(
          http.AbortableRequest('GET', uri, abortTrigger: abort.future)
            ..followRedirects = false,
        );
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 131072) {
          await response.stream.listen(null).cancel();
          return null;
        }
        final bytes = BytesBuilder();
        await for (final part in response.stream) {
          if (bytes.length + part.length > 131072) {
            throw const FormatException('Oversized insights');
          }
          bytes.add(part);
        }
        return jsonDecode(utf8.decode(bytes.takeBytes()))
            as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 15));
      return result;
    } catch (_) {
      return null;
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  Future<WeatherInsights> fetch(String city) {
    if (_disposed || !supportedCities.contains(city)) {
      return Future.value(WeatherInsights(fetchedAt: now().toUtc()));
    }
    final cached = _cache[city];
    if (cached != null &&
        cached.isFresh(now().toUtc()) &&
        now().toUtc().difference(cached.fetchedAt) <
            const Duration(minutes: 10)) {
      return Future.value(cached);
    }
    return _pending.putIfAbsent(
      city,
      () => _fetch(city).whenComplete(() {
        _pending.remove(city);
      }),
    );
  }

  Future<WeatherInsights> _fetch(String city) async {
    final coordinates = openMeteoRequest(city).queryParameters;
    final base = {
      'latitude': coordinates['latitude']!,
      'longitude': coordinates['longitude']!,
      'timezone': 'Asia/Manila',
      'timeformat': 'unixtime',
      'forecast_days': '3',
    };
    final results = await Future.wait([
      _read(
        Uri.parse(openMeteoEndpoint).replace(
          queryParameters: {
            ...base,
            'hourly': 'temperature_2m,relative_humidity_2m,precipitation_probability,uv_index,apparent_temperature,wind_speed_10m,weather_code',
            'wind_speed_unit': 'ms',
          },
        ),
      ),
      _read(
        Uri.parse(openMeteoEndpoint).replace(
          queryParameters: {
            ...base,
            'hourly': 'precipitation',
            'models': insightModels.join(','),
          },
        ),
      ),
    ]);
    final data = WeatherInsights.parse(results[0], results[1], now().toUtc());
    if (!_disposed && results.every((result) => result != null)) {
      _cache[city] = data;
    }
    return data;
  }

  void dispose() {
    _disposed = true;
    for (final a in _aborts) {
      if (!a.isCompleted) a.complete();
    }
    _client.close();
  }
}
