import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/widgets/ai_rain_plan_advice.dart';
import 'package:munora/widgets/weather_view.dart';

import 'rain_model_test.dart' show artifact;
import 'weather_fixture.dart';

void main() {
  WeatherSnapshot weather({Duration age = Duration.zero}) {
    final json = weatherFixture(
      updatedAt: DateTime.now().toUtc().subtract(age),
    );
    json['source'] = 'Open-Meteo';
    json['current']['weatherCode'] = 61;
    return WeatherSnapshot.fromJson(json);
  }

  testWidgets(
    'planner hides probability for incomplete coverage, stale or saved-only weather',
    (tester) async {
      final w = weather();
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(const Duration(hours: 1));
      final loader = RainModelLoader(
        read: () async => jsonEncode(artifact()..['intercept'] = 1),
      );
      Widget view(WeatherSnapshot value, {int hours = 1, bool live = true}) =>
          MaterialApp(
            home: Scaffold(
              body: WeatherLiveStatus(
                isLive: live,
                child: AIRainPlanAdvice(
                  weather: value,
                  activity: Activity.walk,
                  start: start,
                  durationHours: hours,
                  loader: loader,
                ),
              ),
            ),
          );
      await tester.pumpWidget(view(w));
      await tester.pumpAndSettle();
      expect(
        find.text('73% chance of rain · full 3-hour outlook'),
        findsOneWidget,
      );

      await tester.pumpWidget(view(w, hours: 3));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not cover your entire plan'),
        findsOneWidget,
      );
      expect(find.textContaining('73%'), findsNothing);

      await tester.pumpWidget(view(weather(age: const Duration(minutes: 31))));
      await tester.pumpAndSettle();
      expect(find.textContaining('older than 30 minutes'), findsOneWidget);
      expect(find.textContaining('73%'), findsNothing);

      await tester.pumpWidget(view(w, live: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved weather'), findsOneWidget);
      expect(find.textContaining('73%'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
