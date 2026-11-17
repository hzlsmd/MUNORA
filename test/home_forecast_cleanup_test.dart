import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/home_screen.dart';
import 'package:munora/screens/forecast_screen.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/widgets/ai_rain_outlook.dart';
import 'package:munora/widgets/activity_planner_card.dart';
import 'package:munora/widgets/bottom_nav.dart';
import 'package:munora/widgets/smart_home.dart';
import 'package:munora/widgets/weather_cards.dart';
import 'package:munora/widgets/weather_view.dart';
import 'package:munora/models/weather_snapshot.dart';

import 'weather_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  http.Response forecastResponse() {
    final now = DateTime.now().toUtc();
    final data = weatherFixture(updatedAt: now);
    final sample = Map<String, dynamic>.from(data['hourly'][0]);
    data['hourly'] = List.generate(
      120,
      (i) => {...sample, 'at': now.add(Duration(hours: i)).toIso8601String()},
    );
    return http.Response(jsonEncode(data), 200);
  }

  for (final width in [320.0, 390.0, 1366.0]) {
    testWidgets(
      'Home keeps recommendations last without duplicate planning at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = WeatherService(
          endpoint: 'https://weather.example',
          client: MockClient((_) async => forecastResponse()),
        );
        addTearDown(service.dispose);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        SharedPreferences.setMockInitialValues({
          'planner.routine.Muntinlupa':
              '{"activity":"walk","hour":7,"duration":1}',
        });
        AppScreen? destination;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                ),
                child: HomeScreen(
                  city: 'Muntinlupa',
                  service: service,
                  onCityChange: (_) {},
                  navigate: (s) => destination = s,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AIRainOutlook), findsNothing);
        expect(find.text('Personalize your activity plan'), findsNothing);
        expect(find.text('Check your saved activity plan'), findsNothing);
        expect(find.textContaining('shown separately below'), findsNothing);
        expect(find.byType(WeatherMetrics), findsOneWidget);
        expect(find.text('Forecast outlook'), findsOneWidget);
        expect(find.text('Smart Recommendations'), findsOneWidget);
        expect(find.textContaining('umbrella'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(SmartHome)).dy,
          greaterThan(
            tester.getBottomLeft(find.text('View 5-Day Forecast')).dy,
          ),
        );
        final vertical = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
        );
        final column = tester.widget<SingleChildScrollView>(vertical).child!;
        expect(
          tester.getBottomLeft(find.byType(SmartHome)).dy,
          closeTo(tester.getBottomLeft(find.byWidget(column)).dy, 0.01),
        );
        await tester.ensureVisible(find.text('View 5-Day Forecast'));
        await tester.tap(find.text('View 5-Day Forecast'));
        expect(destination, AppScreen.forecast);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Forecast retains daily and hourly data without current metrics at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = WeatherService(
          endpoint: 'https://weather.example',
          client: MockClient((_) async => forecastResponse()),
        );
        addTearDown(service.dispose);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                ),
                child: ForecastScreen(
                  city: 'Muntinlupa',
                  service: service,
                  navigate: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Current conditions'), findsNothing);
        expect(find.byType(WeatherMetrics), findsNothing);
        expect(find.text('5-Day Forecast'), findsOneWidget);
        await tester.tap(find.text('Hourly'));
        await tester.pumpAndSettle();
        expect(find.byType(HourlyReel), findsOneWidget);
        expect(find.text('1-hour intervals'), findsOneWidget);
        expect(find.byType(WeatherMetrics), findsNothing);
        await tester.tap(find.text('Daily'));
        await tester.pumpAndSettle();
        expect(find.text('5-Day Forecast'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Tips retains its AI outlook and functioning activity planner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'planner.routine.Muntinlupa': '{"activity":"walk","hour":7,"duration":1}',
    });
    final service = WeatherService(
      endpoint: 'https://weather.example',
      client: MockClient((_) async => forecastResponse()),
    );
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AIScreen(
            city: 'Muntinlupa',
            service: service,
            navigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AIRainOutlook), findsOneWidget);
    expect(find.byType(ActivityPlannerCard), findsOneWidget);
    await tester.ensureVisible(find.text('Plan an activity'));
    await tester.tap(find.text('Plan an activity'));
    await tester.pumpAndSettle();
    expect(find.text('Check this plan'), findsOneWidget);
    expect(find.text('Remove routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Smart Recommendations preserves saved-weather advice and warning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherLiveStatus(
                isLive: false,
                child: SmartHome(
                  weather: WeatherSnapshot.fromJson(weatherFixture()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved information'), findsOneWidget);
      expect(find.textContaining('umbrella'), findsOneWidget);
      expect(find.text('Personalize your activity plan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
