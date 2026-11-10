import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/ai_service.dart';
import 'package:munora/widgets/ai_recommendation_panel.dart';

import 'ai_service_test.dart' show aiPlan, aiResponse;

void main() {
  testWidgets('visible AI advice disappears at its exact expiry', (
    tester,
  ) async {
    var time = DateTime.utc(2026, 11, 10, 4, 10);
    final plan = aiPlan(now: time);
    final body = aiResponse(plan, time)
      ..['expiresAt'] = time.add(const Duration(seconds: 2)).toIso8601String();
    final service = AiService(
      endpoint: 'https://ai.example/recommendations',
      now: () => time,
      client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiRecommendationPanel(
              plan: plan,
              service: service,
              now: () => time,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Generate AI recommendation'));
    await tester.pumpAndSettle();
    expect(find.text('AI-generated recommendation'), findsOneWidget);
    time = time.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('AI-generated recommendation'), findsNothing);
    expect(find.textContaining('has expired'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'generation is explicit, disables repeated taps, and labels supplementary advice',
    (tester) async {
      final now = DateTime.now().toUtc(),
          plan = aiPlan(now: DateTime.now().toUtc());
      var calls = 0;
      final pending = Completer<http.Response>();
      final service = AiService(
        endpoint: 'https://ai.example/recommendations',
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiRecommendationPanel(plan: plan, service: service),
            ),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Generate AI recommendation'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Preparing your recommendation…'), findsOneWidget);
      pending.complete(http.Response(jsonEncode(aiResponse(plan, now)), 200));
      await tester.pumpAndSettle();
      expect(find.text('AI-generated recommendation'), findsOneWidget);
      expect(find.textContaining('Carry water and prepare'), findsOneWidget);
      expect(find.textContaining('Rule-based hazards: rain'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'changing activity during a pending request discards the old result',
    (tester) async {
      final now = DateTime.now().toUtc(),
          plan = aiPlan(now: DateTime.now().toUtc());
      final pending = Completer<http.Response>();
      final service = AiService(
        endpoint: 'https://ai.example/recommendations',
        client: MockClient((_) => pending.future),
      );
      addTearDown(service.dispose);
      Widget build(AiPlan p) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiRecommendationPanel(plan: p, service: service),
          ),
        ),
      );
      await tester.pumpWidget(build(plan));
      await tester.tap(find.text('Generate AI recommendation'));
      await tester.pump();
      await tester.pumpWidget(
        build(aiPlan(now: now, activity: Activity.exercise)),
      );
      pending.complete(http.Response(jsonEncode(aiResponse(plan, now)), 200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Carry water and prepare'), findsNothing);
      expect(find.text('Generate AI recommendation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'quota failure leaves fallback visible and supports narrow enlarged text',
    (tester) async {
      final service = AiService(
        endpoint: 'https://ai.example/recommendations',
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: AiRecommendationPanel(
                    plan: aiPlan(now: DateTime.now().toUtc()),
                    service: service,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Generate AI recommendation'));
      await tester.tap(find.text('Generate AI recommendation'));
      await tester.pumpAndSettle();
      expect(find.textContaining('free AI limit'), findsOneWidget);
      expect(find.textContaining('Rule-based hazards:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unconfigured AI keeps rule-based fallback without a network call',
    (tester) async {
      final service = AiService(endpoint: '');
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiRecommendationPanel(
              plan: aiPlan(now: DateTime.now().toUtc()),
              service: service,
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Rule-based guidance remains available'),
        findsOneWidget,
      );
      expect(find.text('Generate AI recommendation'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
