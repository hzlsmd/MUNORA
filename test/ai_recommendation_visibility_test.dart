import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/widgets/ai_rain_outlook.dart';
import 'package:munora/widgets/weather_view.dart';

import 'weather_fixture.dart';
import 'rain_model_test.dart' show artifact;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  WeatherService service() => WeatherService(
    endpoint: 'https://weather.example',
    client: MockClient((_) async {
      final json = weatherFixture()..['source'] = 'Open-Meteo';
      json['current']['weatherCode'] = 61;
      return http.Response(jsonEncode(json), 200);
    }),
  );

  testWidgets(
    'Tips shortcut opens and scrolls to the existing planner without resetting activity',
    (tester) async {
      final weather = service();
      addTearDown(weather.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AIScreen(
              navigate: (_) {},
              city: 'Muntinlupa',
              service: weather,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check this plan'), findsNothing);
      await tester.ensureVisible(find.text('Plan an activity'));
      await tester.tap(find.text('Plan an activity'));
      await tester.pumpAndSettle();
      expect(find.text('Check this plan'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Plan My Activity')).dy,
        inInclusiveRange(0, 250),
      );
      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Plan My Activity'));
      await tester.tap(find.text('Plan My Activity'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Plan an activity'));
      await tester.tap(find.text('Plan an activity'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Exercise'))
            .selected,
        isTrue,
      );
      expect(find.text('Forecast-based activity planner'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('entry from Home opens the planner once weather has loaded', (
    tester,
  ) async {
    final weather = service();
    addTearDown(weather.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AIScreen(
            navigate: (_) {},
            city: 'Muntinlupa',
            service: weather,
            openPlannerOnLoad: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Check this plan'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Plan My Activity')).dy,
      inInclusiveRange(0, 250),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'outlook Refresh weather forces a new request past the memory cache',
    (tester) async {
      var requests = 0;
      final model = RainModelLoader(read: () async => jsonEncode(artifact()));
      final weather = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async {
          requests++;
          final json = weatherFixture()..['source'] = 'Open-Meteo';
          json['current']['weatherCode'] = 61;
          if (requests == 1) {
            json['observedAt'] = DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 31))
                .toIso8601String();
          }
          return http.Response(jsonEncode(json), 200);
        }),
      );
      addTearDown(weather.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherView(
              city: 'Muntinlupa',
              service: weather,
              builder: (w) => SingleChildScrollView(
                child: AIRainOutlook(weather: w, loader: model),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('older than 30 minutes'), findsOneWidget);
      expect(requests, 1);
      await tester.ensureVisible(find.text('Refresh weather'));
      await tester.tap(find.text('Refresh weather'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.textContaining('probability of rain'), findsOneWidget);
      expect(find.textContaining('older than 30 minutes'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
