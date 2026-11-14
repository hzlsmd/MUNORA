import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/widgets/activity_planner_card.dart';
import 'package:munora/services/planner_preferences.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/weather_insights.dart';
import 'package:munora/models/planning_hour.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/widgets/weather_view.dart';

import 'rain_model_test.dart' show artifact;
import 'weather_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'saved routine highlights a changed same-plan assessment at narrow width',
    (tester) async {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(const Duration(hours: 1));
      final store = PlannerPreferences();
      await store.saveRoutine(
        'Manila',
        ActivityRoutine(
          activity: Activity.walk,
          hour: (start.hour + 8) % 24,
          durationHours: 1,
        ),
      );
      await store.saveAssessment(
        'Manila',
        'walk:${start.toIso8601String()}:1',
        'Earlier forecast',
      );
      final forecast = WeatherInsights(
        fetchedAt: now,
        hours: [
          PlanningHour(
            at: start,
            temperature: 27,
            feelsLike: 28,
            rain: 10,
            uv: 2,
            wind: 2,
            code: 0,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: ActivityPlannerCard(
                    city: 'Manila',
                    insights: forecast,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan My Activity'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Forecast changed since your last check'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'planner selects an activity and saves and removes a routine without forecast data',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityPlannerCard(city: 'Manila', insights: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan My Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check this plan'));
      await tester.tap(find.text('Check this plan'));
      await tester.pumpAndSettle();
      expect(find.text('Insufficient forecast data'), findsOneWidget);
      await tester.ensureVisible(find.text('Save daily routine'));
      await tester.tap(find.text('Save daily routine'));
      await tester.pumpAndSettle();
      expect(
        (await PlannerPreferences().loadRoutine('Manila'))?.activity,
        Activity.exercise,
      );
      await tester.ensureVisible(find.text('Remove routine'));
      await tester.tap(find.text('Remove routine'));
      await tester.pumpAndSettle();
      expect(await PlannerPreferences().loadRoutine('Manila'), isNull);
    },
  );

  testWidgets(
    'checked plan shows full-window AI rain context and walking advice',
    (tester) async {
      final json = weatherFixture()..['source'] = 'Open-Meteo';
      json['current']['weatherCode'] = 61;
      final weather = WeatherSnapshot.fromJson(json);
      final loader = RainModelLoader(
        read: () async => jsonEncode(artifact()..['intercept'] = 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherLiveStatus(
                isLive: true,
                child: ActivityPlannerCard(
                  city: 'Muntinlupa',
                  insights: null,
                  weather: weather,
                  rainModelLoader: loader,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan My Activity'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check this plan'));
      await tester.tap(find.text('Check this plan'));
      await tester.pumpAndSettle();
      expect(find.text('Insufficient forecast data'), findsOneWidget);
      expect(
        find.text('73% chance of rain · full 3-hour outlook'),
        findsOneWidget,
      );
      expect(find.textContaining('route with shelter'), findsOneWidget);
      expect(
        find.textContaining(
          'Probability covers the complete three-hour window',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Commuting'));
      await tester.tap(find.text('Commuting'));
      await tester.pumpAndSettle();
      expect(find.textContaining('73%'), findsNothing);
      await tester.ensureVisible(find.text('Check this plan'));
      await tester.tap(find.text('Check this plan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('extra travel time'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'low AI probability preserves a forecast thunderstorm warning at narrow large text',
    (tester) async {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(const Duration(hours: 1));
      final json = weatherFixture(updatedAt: now)..['source'] = 'Open-Meteo';
      json['current']['weatherCode'] = 0;
      final weather = WeatherSnapshot.fromJson(json);
      final loader = RainModelLoader(
        read: () async => jsonEncode(artifact()..['intercept'] = -5),
      );
      final forecast = WeatherInsights(
        fetchedAt: now,
        hours: [
          PlanningHour(
            at: start,
            temperature: 27,
            feelsLike: 28,
            rain: 10,
            uv: 2,
            wind: 2,
            code: 95,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: WeatherLiveStatus(
                      isLive: true,
                      child: ActivityPlannerCard(
                        city: 'Muntinlupa',
                        insights: forecast,
                        weather: weather,
                        rainModelLoader: loader,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan My Activity'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check this plan'));
      await tester.tap(find.text('Check this plan'));
      await tester.pumpAndSettle();
      expect(find.text('Consider postponing'), findsOneWidget);
      expect(find.textContaining('Thunderstorm forecast'), findsOneWidget);
      expect(
        find.text('<1% chance of rain · full 3-hour outlook'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Existing rain, storm, heat and wind precautions still apply',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
