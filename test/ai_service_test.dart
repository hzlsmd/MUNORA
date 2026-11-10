import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/models/planning_hour.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/ai_service.dart';
import 'package:munora/services/weather_insights.dart';

import 'weather_fixture.dart';

final aiNow = DateTime.utc(2026, 11, 10, 4, 10);
AiPlan aiPlan({DateTime? now, Activity activity = Activity.walk}) {
  final time = now ?? aiNow;
  final start = DateTime.utc(time.year, time.month, time.day, time.hour + 1);
  return AiPlan.fromWeather(
    WeatherSnapshot.fromJson(weatherFixture(city: 'Manila', updatedAt: time)),
    WeatherInsights(
      fetchedAt: time,
      hours: [
        PlanningHour(
          at: start,
          temperature: 28,
          feelsLike: 30,
          rain: 10,
          uv: 2,
          wind: 2,
          code: 0,
        ),
      ],
    ),
    activity,
    start,
    1,
    time,
  );
}

Map<String, dynamic> aiResponse(AiPlan plan, DateTime now) => {
  ...Map<String, dynamic>.from(plan.payload)
    ..remove('current')
    ..remove('hours')
    ..remove('observedAt'),
  'status': plan.status.name,
  'hazards': plan.hazards,
  'generatedAt': now.toIso8601String(),
  'expiresAt':
      (now.add(const Duration(minutes: 10)).isBefore(plan.validUntil)
              ? now.add(const Duration(minutes: 10))
              : plan.validUntil)
          .toIso8601String(),
  'recommendation': {
    'summary': 'Carry water and prepare for your walk.',
    'reason': 'Rain protection helps with the current conditions.',
    'preparations': ['Carry water.', 'Bring rain protection.'],
  },
};
void main() {
  test(
    'AI plan expires when its current weather observation becomes stale',
    () {
      final start = DateTime.utc(2026, 11, 10, 5),
          json = weatherFixture(city: 'Manila', updatedAt: aiNow);
      final observed = aiNow.subtract(const Duration(hours: 2, minutes: 59));
      json['observedAt'] = observed.toIso8601String();
      final plan = AiPlan.fromWeather(
        WeatherSnapshot.fromJson(json),
        WeatherInsights(
          fetchedAt: aiNow,
          hours: [
            PlanningHour(
              at: start,
              temperature: 28,
              feelsLike: 30,
              rain: 10,
              uv: 2,
              wind: 2,
              code: 0,
            ),
          ],
        ),
        Activity.walk,
        start,
        1,
        aiNow,
      );
      expect(plan.validUntil, observed.add(const Duration(hours: 3)));
    },
  );

  test('partial severe forecast still gives rule guidance but cannot form an AI plan', () {
    final start = DateTime.utc(2026, 11, 10, 5);
    final insights = WeatherInsights(
      fetchedAt: aiNow,
      hours: [PlanningHour(at: start, code: 95)],
    );
    expect(
      () => AiPlan.fromWeather(
        WeatherSnapshot.fromJson(
          weatherFixture(city: 'Manila', updatedAt: aiNow),
        ),
        insights,
        Activity.walk,
        start,
        2,
        aiNow,
      ),
      throwsA(isA<AiException>()),
    );
  });
  test(
    'response fixture expires within the plan at an insight-hour boundary',
    () {
      final time = DateTime.utc(2026, 11, 10, 4, 55),
          plan = aiPlan(now: DateTime.utc(2026, 11, 10, 4, 55));
      expect(
        DateTime.parse(aiResponse(plan, time)['expiresAt'])
            .isAfter(plan.validUntil),
        isFalse,
      );
    },
  );
  test('requests contain only weather context, reuse valid advice and share concurrent work', () async {
    final plan = aiPlan();
    var calls = 0;
    final pending = Completer<http.Response>();
    final service = AiService(
      endpoint: 'https://ai.example/recommendations',
      now: () => aiNow,
      client: MockClient((req) {
        calls++;
        expect(req.method, 'POST');
        expect(req.headers.containsKey('authorization'), false);
        final body = jsonDecode(req.body) as Map;
        expect(body['city'], 'Manila');
        expect(body['activity'], 'walk');
        expect(body.containsKey('prompt'), false);
        return pending.future;
      }),
    );
    addTearDown(service.dispose);
    final a = service.recommend(plan), b = service.recommend(plan);
    pending.complete(http.Response(jsonEncode(aiResponse(plan, aiNow)), 200));
    expect((await a).summary, contains('Carry water'));
    await b;
    await service.recommend(plan);
    expect(calls, 1);
  });
  test('missing or insecure endpoint never performs network work', () async {
    for (final endpoint in [
      '',
      'http://ai.example/recommendations',
      'https://user:secret@ai.example/recommendations',
      'https://ai.example/recommendations?key=secret',
    ]) {
      final service = AiService(
        endpoint: endpoint,
        now: () => aiNow,
        client: MockClient((_) => throw StateError('must not fetch')),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.recommend(aiPlan()),
        throwsA(isA<AiException>()),
      );
    }
  });
  test('outages, quota and malformed, mismatched, expired or unsafe output fall back', () async {
    final plan = aiPlan();
    final invalid = <void Function(Map<String, dynamic>)>[
      (d) => d['city'] = 'Makati',
      (d) => d['activity'] = 'exercise',
      (d) => d['hazards'] = [],
      (d) => d['status'] = 'postpone',
      (d) => d['expiresAt'] = aiNow
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
      (d) => d['recommendation']['summary'] = 'It is completely safe.',
      (d) => d['recommendation']['summary'] = 'x' * 601,
      (d) => d['recommendation']['preparations'] = [],
    ];
    final responses = [
      http.Response('{}', 429),
      http.Response('{}', 503),
      http.Response('x' * 8193, 200),
      http.Response('bad json', 200),
      ...invalid.map((change) {
        final d = aiResponse(plan, aiNow);
        change(d);
        return http.Response(jsonEncode(d), 200);
      }),
    ];
    for (final response in responses) {
      final service = AiService(
        endpoint: 'https://ai.example/recommendations',
        now: () => aiNow,
        client: MockClient((_) async => response),
      );
      addTearDown(service.dispose);
      await expectLater(service.recommend(plan), throwsA(isA<AiException>()));
    }
  });
  test('expired forecast cannot generate or reuse AI advice', () async {
    final plan = aiPlan();
    var time = aiNow;
    final service = AiService(
      endpoint: 'https://ai.example/recommendations',
      now: () => time,
      client: MockClient(
        (_) async => http.Response(jsonEncode(aiResponse(plan, aiNow)), 200),
      ),
    );
    addTearDown(service.dispose);
    await service.recommend(plan);
    time = time.add(const Duration(minutes: 31));
    await expectLater(service.recommend(plan), throwsA(isA<AiException>()));
  });
  test('timeout aborts outstanding request', () async {
    final client = AiPendingClient();
    final service = AiService(
      endpoint: 'https://ai.example/recommendations',
      now: () => aiNow,
      client: client,
      requestTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(service.dispose);
    await expectLater(service.recommend(aiPlan()), throwsA(isA<AiException>()));
    await client.request!.abortTrigger!;
    client.response.complete(
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 500),
    );
  });
}

class AiPendingClient extends http.BaseClient {
  http.AbortableRequest? request;
  final response = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) {
    request = r as http.AbortableRequest;
    return response.future;
  }
}
