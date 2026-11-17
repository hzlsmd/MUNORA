import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/services/ask_munora_service.dart';

Map<String, dynamic> answer() {
  final now = DateTime.now().toUtc();
  return {
    'schemaVersion': 1,
    'city': 'Muntinlupa',
    'answer': 'Bring an umbrella.',
    'observedAt': now.toIso8601String(),
    'generatedAt': now.toIso8601String(),
    'forecastUntil': now.add(const Duration(hours: 3)).toIso8601String(),
    'source': 'Open-Meteo',
    'model': 'model',
    'facts': [
      {'id': 'rain', 'label': 'Rain', 'value': 'Possible'},
    ],
  };
}

void main() {
  test(
    'accepts structured fallback and rejects inconsistent metadata',
    () async {
      final structured = {
        ...answer(),
        'schemaVersion': 2,
        'advice': 'Bring an umbrella.',
        'explanation': 'Verified forecast summary.',
        'answer': 'Bring an umbrella.\n\nVerified forecast summary.',
        'forecastDate': '2026-11-18',
        'responseType': 'weather_summary',
        'fallbackReason': 'invalid_json',
      };
      final service = AskMunoraService(
        clientFactory: () =>
            MockClient((_) async => http.Response(jsonEncode(structured), 200)),
      );
      final result = await service.ask(
        city: 'Muntinlupa',
        question: 'Tomorrow?',
      );
      expect(result.isFallback, true);
      expect(result.forecastDate, '2026-11-18');
      expect(result.advice, 'Bring an umbrella.');
      for (final patch in [
        {'responseType': 'fake'},
        {'fallbackReason': 'raw private model text'},
        {'forecastDate': '2026-02-31'},
        {'explanation': 42},
        {'answer': 'Injected different prose'},
      ]) {
        final bad = AskMunoraService(
          clientFactory: () => MockClient(
            (_) async =>
                http.Response(jsonEncode({...structured, ...patch}), 200),
          ),
        );
        await expectLater(
          bad.ask(city: 'Muntinlupa', question: 'Tomorrow?'),
          throwsA(isA<AskMunoraException>()),
        );
      }
    },
  );

  test(
    'sends only bounded city question history and accepts validated answer',
    () async {
      final service = AskMunoraService(
        clientFactory: () => MockClient((r) async {
          expect(r.followRedirects, false);
          expect(jsonDecode(r.body), {
            'schemaVersion': 2,
            'city': 'Muntinlupa',
            'question': 'Umbrella?',
            'history': [],
          });
          expect(r.headers.containsKey('authorization'), false);
          return http.Response(jsonEncode(answer()), 200);
        }),
      );
      expect(
        (await service.ask(city: 'Muntinlupa', question: 'Umbrella?')).answer,
        'Bring an umbrella.',
      );
    },
  );
  test(
    'rejects wrong city stale future malformed and oversized data',
    () async {
      for (final patch in [
        {'city': 'Manila'},
        {
          'observedAt': DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'generatedAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        },
        {'facts': 'bad'},
        {'answer': 'x' * 1801},
      ]) {
        final service = AskMunoraService(
          clientFactory: () => MockClient(
            (_) async =>
                http.Response(jsonEncode({...answer(), ...patch}), 200),
          ),
        );
        await expectLater(
          service.ask(city: 'Muntinlupa', question: 'Hi'),
          throwsA(isA<AskMunoraException>()),
        );
      }
    },
  );
  test('validates endpoint and input before network and maps quota', () async {
    final bad = AskMunoraService(endpoint: 'http://unsafe');
    await expectLater(
      bad.ask(city: 'Muntinlupa', question: 'Hi'),
      throwsA(isA<AskMunoraException>()),
    );
    final service = AskMunoraService(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          '{"schemaVersion":1,"error":{"code":"rate_limited","message":"secret"}}',
          429,
          headers: {'retry-after': '60'},
        ),
      ),
    );
    try {
      await service.ask(city: 'Muntinlupa', question: 'Hi');
      fail('Expected quota');
    } on AskMunoraException catch (e) {
      expect(e.code, 'rate_limited');
      expect(e.message, isNot(contains('secret')));
      expect(e.retryAfter, 60);
    }
  });
  test(
    'bounded response, invalid inputs, timeout and explicit cancellation',
    () async {
      var calls = 0;
      final service = AskMunoraService(
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response('x' * 16385, 200);
        }),
      );
      for (final args in [
        ('', const <AskTurn>[]),
        ('x' * 601, const <AskTurn>[]),
        ('Hi', [const AskTurn('system', 'bad')]),
        ('Hi', List.filled(7, const AskTurn('user', 'q'))),
        ('Hi', List.filled(5, AskTurn('user', 'x' * 600))),
      ]) {
        await expectLater(
          service.ask(city: 'Muntinlupa', question: args.$1, history: args.$2),
          throwsA(isA<AskMunoraException>()),
        );
      }
      expect(calls, 0);
      await expectLater(
        service.ask(city: 'Muntinlupa', question: 'Hi'),
        throwsA(isA<AskMunoraException>()),
      );
      final pending = Completer<http.Response>();
      final slow = AskMunoraService(
        timeout: const Duration(milliseconds: 10),
        clientFactory: () => MockClient((_) => pending.future),
      );
      await expectLater(
        slow.ask(city: 'Muntinlupa', question: 'Hi'),
        throwsA(
          isA<AskMunoraException>().having((e) => e.code, 'code', 'timeout'),
        ),
      );
      final cancelled = AskMunoraService(
        clientFactory: () => MockClient((_) => pending.future),
      );
      final future = cancelled.ask(city: 'Muntinlupa', question: 'Hi');
      cancelled.cancel();
      await expectLater(
        future,
        throwsA(
          isA<AskMunoraException>().having((e) => e.code, 'code', 'cancelled'),
        ),
      );
      pending.complete(http.Response(jsonEncode(answer()), 200));
    },
  );
  test(
    'rejects old generated time distant horizon controls and duplicate facts',
    () async {
      for (final patch in [
        {
          'generatedAt': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 6))
              .toIso8601String(),
        },
        {
          'forecastUntil': DateTime.now()
              .toUtc()
              .add(const Duration(days: 4))
              .toIso8601String(),
        },
        {'answer': 'bad\u0000text'},
        {
          'facts': [
            {'id': 'same', 'label': 'Rain', 'value': 'Wet'},
            {'id': 'same', 'label': 'Rain', 'value': 'Wet'},
          ],
        },
      ]) {
        final service = AskMunoraService(
          clientFactory: () => MockClient(
            (_) async =>
                http.Response(jsonEncode({...answer(), ...patch}), 200),
          ),
        );
        await expectLater(
          service.ask(city: 'Muntinlupa', question: 'Hi'),
          throwsA(isA<AskMunoraException>()),
        );
      }
    },
  );
}
