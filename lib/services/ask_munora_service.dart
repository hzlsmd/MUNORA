import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AskMunoraException implements Exception {
  final String code, message;
  final int? retryAfter;
  const AskMunoraException(this.code, this.message, {this.retryAfter});
}

class AskTurn {
  final String role, content;
  const AskTurn(this.role, this.content);
  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AskFact {
  final String id, label, value;
  const AskFact(this.id, this.label, this.value);
}

class AskAnswer {
  final String city, answer, source, model;
  final DateTime observedAt, generatedAt, forecastUntil;
  final List<AskFact> facts;
  const AskAnswer({
    required this.city,
    required this.answer,
    required this.source,
    required this.model,
    required this.observedAt,
    required this.generatedAt,
    required this.forecastUntil,
    required this.facts,
  });
}

class AskMunoraService {
  static const defaultEndpoint = String.fromEnvironment(
    'ASK_MUNORA_URL',
    defaultValue: 'https://munora-weather.hazelsomido0.workers.dev/ask',
  );
  final String endpoint;
  final http.Client Function() clientFactory;
  final Duration timeout;
  http.Client? _active;
  Completer<void>? _abort;
  AskMunoraService({
    this.endpoint = defaultEndpoint,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 35),
  }) : clientFactory = clientFactory ?? http.Client.new;
  void cancel() {
    _active?.close();
    _active = null;
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
  }

  static const invalid = AskMunoraException(
    'invalid_ai_response',
    'The answer could not be verified. Please try again.',
  );
  Future<AskAnswer> ask({
    required String city,
    required String question,
    List<AskTurn> history = const [],
  }) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw const AskMunoraException(
        'unavailable',
        'Ask MUNORA is not available right now.',
      );
    }
    question = question.trim();
    if (city.isEmpty ||
        question.isEmpty ||
        question.length > 600 ||
        history.length > 6 ||
        history.any(
          (t) =>
              !['user', 'assistant'].contains(t.role) ||
              t.content.isEmpty ||
              t.content.length > 600,
        ) ||
        history.fold<int>(0, (n, t) => n + t.content.length) > 2400) {
      throw const AskMunoraException(
        'invalid_request',
        'Please enter a question of up to 600 characters.',
      );
    }
    final body = jsonEncode({
      'schemaVersion': 1,
      'city': city,
      'question': question,
      'history': history.map((t) => t.toJson()).toList(),
    });
    if (utf8.encode(body).length > 12288) {
      throw const AskMunoraException(
        'invalid_request',
        'Please shorten your question.',
      );
    }
    cancel();
    final client = clientFactory();
    _active = client;
    final abort = Completer<void>();
    _abort = abort;
    final clock = Stopwatch()..start();
    try {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['content-type'] = 'application/json'
        ..body = body;
      final response = await Future.any<http.StreamedResponse>([
        client.send(request),
        abort.future.then(
          (_) => throw const AskMunoraException(
            'cancelled',
            'Question cancelled.',
          ),
        ),
      ]).timeout(timeout);
      final bytes = <int>[];
      await Future.any<void>([
        (() async {
          await for (final chunk in response.stream) {
            if (bytes.length + chunk.length > 16384) throw invalid;
            bytes.addAll(chunk);
          }
        })(),
        abort.future.then(
          (_) => throw const AskMunoraException(
            'cancelled',
            'Question cancelled.',
          ),
        ),
      ]).timeout(timeout - clock.elapsed);
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] is! int ||
          raw['schemaVersion'] != 1) {
        throw invalid;
      }
      if (response.statusCode != 200) {
        final error = raw['error'];
        final code = error is Map ? error['code'] : null;
        if (code == 'rate_limited' && response.statusCode == 429) {
          final retry = int.tryParse(response.headers['retry-after'] ?? '');
          throw AskMunoraException(
            'rate_limited',
            'The question limit has been reached. Please try again later.',
            retryAfter: retry?.clamp(0, 86400),
          );
        }
        if (code == 'weather_unavailable') {
          throw const AskMunoraException(
            'weather_unavailable',
            'Fresh weather is unavailable. Please refresh and try again.',
          );
        }
        if (code == 'unavailable' || code == 'ai_unavailable') {
          throw const AskMunoraException(
            'unavailable',
            'Ask MUNORA is temporarily unavailable. Please try again later.',
          );
        }
        if (code == 'unsupported_city') {
          throw const AskMunoraException(
            'unsupported_city',
            'Ask MUNORA is not available for this city yet.',
          );
        }
        if (code == 'invalid_request') {
          throw const AskMunoraException(
            'invalid_request',
            'Please shorten or rephrase your weather question.',
          );
        }
        throw invalid;
      }
      String str(dynamic value, int max) {
        if (value is! String ||
            value.trim().isEmpty ||
            value.length > max ||
            RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(value)) {
          throw invalid;
        }
        return value;
      }

      DateTime date(dynamic value) {
        final s = str(value, 50);
        if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(s)) throw invalid;
        return DateTime.parse(s).toUtc();
      }

      final observed = date(raw['observedAt']),
          generated = date(raw['generatedAt']),
          until = date(raw['forecastUntil']),
          now = DateTime.now().toUtc();
      if (raw['city'] != city ||
          raw['source'] != 'Open-Meteo' ||
          now.difference(observed) > const Duration(minutes: 30) ||
          observed.difference(now) > const Duration(minutes: 5) ||
          now.difference(generated) > const Duration(minutes: 5) ||
          generated.difference(now) > const Duration(minutes: 5) ||
          !until.isAfter(now) ||
          until.difference(now) > const Duration(days: 3)) {
        throw invalid;
      }
      final facts = raw['facts'];
      if (facts is! List || facts.length > 6) throw invalid;
      final ids = <String>{};
      return AskAnswer(
        city: city,
        answer: str(raw['answer'], 1800),
        source: 'Open-Meteo',
        model: str(raw['model'], 200),
        observedAt: observed,
        generatedAt: generated,
        forecastUntil: until,
        facts: facts.map((f) {
          if (f is! Map) throw invalid;
          final id = str(f['id'], 80);
          if (!ids.add(id)) throw invalid;
          return AskFact(id, str(f['label'], 100), str(f['value'], 180));
        }).toList(),
      );
    } on AskMunoraException {
      rethrow;
    } on FormatException {
      throw invalid;
    } on TimeoutException {
      throw const AskMunoraException(
        'timeout',
        'The answer took too long. Please try again.',
      );
    } catch (_) {
      throw const AskMunoraException(
        'offline',
        'Unable to reach Ask MUNORA. Check your connection and try again.',
      );
    } finally {
      client.close();
      if (identical(_active, client)) {
        _active = null;
        _abort = null;
      }
    }
  }
}
