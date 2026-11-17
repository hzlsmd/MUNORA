import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/services/ask_munora_service.dart';
import 'package:munora/widgets/ask_munora_chat.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/services/weather_insights.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_fixture.dart';

import 'ask_munora_service_test.dart' show answer;

void main() {
  for (final width in [320.0, 800.0]) {
    testWidgets('fallback is labeled and retry is manual at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final questions = <String>[];
      final service = AskMunoraService(
        clientFactory: () => MockClient((request) async {
          calls++;
          questions.add(jsonDecode(request.body)['question'] as String);
          return http.Response(
            jsonEncode({
              ...answer(),
              'schemaVersion': 2,
              'advice': 'Bring an umbrella.',
              'explanation': 'Verified forecast summary.',
              'answer': 'Bring an umbrella.\n\nVerified forecast summary.',
              'forecastDate': '2026-11-18',
              'responseType': 'weather_summary',
              'fallbackReason': 'invalid_json',
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              viewInsets: const EdgeInsets.only(bottom: 200),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: AskMunoraChat(city: 'Muntinlupa', service: service),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Do I need an umbrella?'));
      await tester.tap(find.text('Do I need an umbrella?'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('Weather-data summary · AI answer unavailable'),
        findsOneWidget,
      );
      expect(find.text('Forecast date: 2026-11-18 · PHT'), findsOneWidget);
      final retry = find.text('Retry AI answer');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(questions[0], questions[1]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'no automatic request; explicit suggestion submits and clear drops history',
    (tester) async {
      var calls = 0;
      final service = AskMunoraService(
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(answer()), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AskMunoraChat(city: 'Muntinlupa', service: service),
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Do I need an umbrella?'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Bring an umbrella.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear chat'));
      await tester.pumpAndSettle();
      expect(find.text('Bring an umbrella.'), findsNothing);
    },
  );
  testWidgets('clear and city change ignore pending answers; close cancels', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final service = AskMunoraService(
      clientFactory: () => MockClient((_) => pending.future),
    );
    Widget app(String city) => MaterialApp(
      home: Scaffold(
        body: AskMunoraChat(city: city, service: service),
      ),
    );
    await tester.pumpWidget(app('Muntinlupa'));
    await tester.enterText(find.byType(TextField), 'Umbrella?');
    await tester.tap(find.text('Send question'));
    await tester.pump();
    await tester.tap(find.byTooltip('Clear chat'));
    await tester.pump();
    await tester.pumpWidget(app('Manila'));
    pending.complete(http.Response(jsonEncode(answer()), 200));
    await tester.pumpAndSettle();
    expect(find.text('Bring an umbrella.'), findsNothing);
    expect(find.text('Ask MUNORA · Manila'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
  testWidgets('320px and large text with keyboard has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: const Scaffold(body: AskMunoraChat(city: 'Muntinlupa')),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Send question'), findsOneWidget);
  });
  testWidgets('long answer remains paired in follow-up history', (
    tester,
  ) async {
    var calls = 0;
    final requests = <dynamic>[];
    final service = AskMunoraService(
      clientFactory: () => MockClient((request) async {
        calls++;
        requests.add(jsonDecode(request.body));
        return http.Response(
          jsonEncode({...answer(), 'answer': 'a' * 1000}),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskMunoraChat(city: 'Muntinlupa', service: service),
        ),
      ),
    );
    await tester.tap(find.text('Do I need an umbrella?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'And tomorrow?');
    await tester.tap(find.text('Send question'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(requests[1]['history'], [
      {'role': 'user', 'content': 'Do I need an umbrella?'},
      {'role': 'assistant', 'content': 'a' * 600},
    ]);
  });
  testWidgets('failed question stays visible and explicit retry succeeds', (
    tester,
  ) async {
    var calls = 0;
    final service = AskMunoraService(
      clientFactory: () => MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response(
                '{"schemaVersion":1,"error":{"code":"unavailable","message":"private"}}',
                503,
              )
            : http.Response(jsonEncode(answer()), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskMunoraChat(city: 'Muntinlupa', service: service),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Should I bring water?');
    await tester.tap(find.text('Send question'));
    await tester.pumpAndSettle();
    expect(find.text('Should I bring water?'), findsOneWidget);
    expect(calls, 1);
    await tester.enterText(find.byType(TextField), 'My next question');
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('My next question'), findsOneWidget);
    expect(find.text('Bring an umbrella.'), findsOneWidget);
  });
  for (final closeByCity in [false, true]) {
    testWidgets(
      'real Tips modal ${closeByCity ? 'city change' : 'close button'} cancels pending answer',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final pending = Completer<http.Response>();
        final client = _ClosingClient((_) => pending.future);
        final ask = AskMunoraService(clientFactory: () => client);
        final weather = WeatherService(
          endpoint: 'https://weather.example',
          client: MockClient(
            (r) async => http.Response(
              jsonEncode(
                weatherFixture(
                  city: r.url.queryParameters['city'] ?? 'Muntinlupa',
                ),
              ),
              200,
            ),
          ),
        );
        final insights = WeatherInsightsService(
          client: MockClient((_) async => http.Response('{}', 200)),
        );
        addTearDown(weather.dispose);
        addTearDown(insights.dispose);
        var city = 'Muntinlupa';
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return AIScreen(
                    city: city,
                    service: weather,
                    insightsService: insights,
                    askService: ask,
                    navigate: (_) {},
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final opener = find.widgetWithText(FilledButton, 'Ask MUNORA');
        await tester.ensureVisible(opener);
        await tester.tap(opener);
        await tester.pumpAndSettle();
        expect(find.byType(AskMunoraChat), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'Will rain affect my walk?',
        );
        await tester.tap(find.text('Send question'));
        await tester.pump();
        expect(client.closed, false);
        if (closeByCity) {
          update(() => city = 'Manila');
          await tester.pump();
        } else {
          await tester.tap(find.byTooltip('Close Ask MUNORA'));
        }
        await tester.pumpAndSettle();
        expect(client.closed, true);
        expect(find.byType(AskMunoraChat), findsNothing);
        pending.complete(http.Response(jsonEncode(answer()), 200));
        await tester.pumpAndSettle();
        expect(find.text('Bring an umbrella.'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('history trims whole pairs to both message and content bounds', (
    tester,
  ) async {
    final requests = <dynamic>[];
    final service = AskMunoraService(
      clientFactory: () => MockClient((r) async {
        requests.add(jsonDecode(r.body));
        return http.Response(
          jsonEncode({...answer(), 'answer': 'a' * 1000}),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskMunoraChat(city: 'Muntinlupa', service: service),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), 'q' * 600);
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
    }
    final history = requests.last['history'] as List;
    expect(history.length, 4);
    expect(history.map((t) => t['role']).toList(), [
      'user',
      'assistant',
      'user',
      'assistant',
    ]);
    expect(
      history.fold<int>(0, (n, t) => n + (t['content'] as String).length),
      2400,
    );
  });
  testWidgets(
    'new turns reveal loading retry and results above a small keyboard viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final responses = <Completer<http.Response>>[];
      final service = AskMunoraService(
        clientFactory: () => MockClient((_) {
          final pending = Completer<http.Response>();
          responses.add(pending);
          return pending.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: AskMunoraChat(city: 'Muntinlupa', service: service),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'First question');
      await tester.tap(find.text('Send question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      responses[0].complete(
        http.Response(
          jsonEncode({
            ...answer(),
            'answer': List.filled(30, 'Rain is possible.').join(' '),
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Follow-up question');
      await tester.tap(find.text('Send question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find
            .text('Checking fresh weather and preparing an answer…')
            .hitTestable(),
        findsOneWidget,
      );
      responses[1].complete(
        http.Response(
          '{"schemaVersion":1,"error":{"code":"unavailable","message":"private"}}',
          503,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Retry').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      responses[2].complete(http.Response(jsonEncode(answer()), 200));
      await tester.pumpAndSettle();
      expect(find.text('Bring an umbrella.').hitTestable(), findsOneWidget);
      expect(
        find
            .text(
              'AI-generated explanation. Check current forecasts before making plans.',
            )
            .last
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'session evicts old pairs while retaining recent context and clear resets notice',
    (tester) async {
      final sent = <Map<String, dynamic>>[];
      final service = AskMunoraService(
        clientFactory: () => MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          sent.add(body);
          return http.Response(
            jsonEncode({...answer(), 'answer': 'Reply ${body['question']}'}),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AskMunoraChat(city: 'Muntinlupa', service: service),
          ),
        ),
      );
      for (var i = 1; i <= 15; i++) {
        await tester.enterText(find.byType(TextField), 'Question $i');
        await tester.tap(find.text('Send question'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Question 1'), findsNothing);
      expect(find.text('Reply Question 3'), findsNothing);
      expect(find.text('Question 4'), findsOneWidget);
      expect(find.text('Reply Question 15'), findsOneWidget);
      expect(find.textContaining('latest 12 exchanges'), findsOneWidget);
      final history = sent.last['history'] as List;
      expect(history, hasLength(6));
      expect(history.first, {'role': 'user', 'content': 'Question 12'});
      expect(history.last, {
        'role': 'assistant',
        'content': 'Reply Question 14',
      });
      await tester.tap(find.byTooltip('Clear chat'));
      await tester.pumpAndSettle();
      expect(find.textContaining('latest 12 exchanges'), findsNothing);
      expect(find.text('Reply Question 15'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Fresh question');
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
      expect(sent.last['history'], isEmpty);
    },
  );
}

class _ClosingClient extends MockClient {
  bool closed = false;
  _ClosingClient(super.fn);
  @override
  void close() {
    closed = true;
    super.close();
  }
}
