import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/widgets/ai_rain_outlook.dart';
import 'package:munora/widgets/weather_view.dart';

import 'rain_model_test.dart' show artifact;
import 'weather_fixture.dart';

WeatherSnapshot weather({Duration age = Duration.zero}) {
  final json = weatherFixture(updatedAt: DateTime.now().subtract(age));
  json['source'] = 'Open-Meteo';
  json['current']['weatherCode'] = 61;
  return WeatherSnapshot.fromJson(json);
}

Widget card(
  WeatherSnapshot weather,
  RainModelLoader loader, {
  bool live = true,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: WeatherLiveStatus(
        isLive: live,
        child: AIRainOutlook(weather: weather, loader: loader),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'model loading does not block weather UI and missing model is unavailable',
    (tester) async {
      final pending = Completer<String>();
      await tester.pumpWidget(
        card(weather(), RainModelLoader(read: () => pending.future)),
      );
      expect(find.text('AI rain outlook'), findsOneWidget);
      expect(find.text('Loading rain model…'), findsOneWidget);
      pending.completeError(StateError('missing'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unavailable.'), findsOneWidget);
      expect(find.textContaining('probability of rain'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'live estimate shows probability and fixed Philippine time window',
    (tester) async {
      final w = weather();
      final loader = RainModelLoader(
        read: () async => jsonEncode(artifact()..['intercept'] = 1),
      );
      await tester.pumpWidget(card(w, loader));
      await tester.pumpAndSettle();
      expect(find.text('73% probability of rain'), findsOneWidget);
      expect(find.text('Muntinlupa · 3-hour rain outlook'), findsOneWidget);
      expect(
        find.text('Weather estimate ${weatherTime(w.observedAt)}'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          weatherTime(w.observedAt.add(const Duration(hours: 3))),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Carry rain protection'), findsOneWidget);
      await tester.pumpWidget(card(w, loader, live: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unavailable.'), findsOneWidget);
      expect(find.textContaining('Saved weather'), findsOneWidget);
      expect(find.textContaining('probability of rain'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('stale observation cannot display a probability', (tester) async {
    await tester.pumpWidget(
      card(
        weather(age: const Duration(minutes: 31)),
        RainModelLoader(read: () async => jsonEncode(artifact())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unavailable.'), findsOneWidget);
    expect(find.textContaining('older than 30 minutes'), findsOneWidget);
    expect(find.textContaining('probability of rain'), findsNothing);
    await tester.tap(find.text('Model details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Model: test-v1.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a pending replacement model cannot reuse an earlier prediction',
    (tester) async {
      final w = weather();
      await tester.pumpWidget(
        card(w, RainModelLoader(read: () async => jsonEncode(artifact()))),
      );
      await tester.pumpAndSettle();
      expect(find.text('50% probability of rain'), findsOneWidget);
      final pending = Completer<String>();
      await tester.pumpWidget(
        card(w, RainModelLoader(read: () => pending.future)),
      );
      await tester.pump();
      expect(find.textContaining('probability of rain'), findsNothing);
      expect(find.text('Loading rain model…'), findsOneWidget);
      pending.completeError(StateError('invalid replacement'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('could not be loaded or validated'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
