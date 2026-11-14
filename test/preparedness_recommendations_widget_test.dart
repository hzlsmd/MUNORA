import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/widgets/preparedness_recommendations.dart';
import 'package:munora/widgets/weather_view.dart';

import 'weather_fixture.dart';
import 'rain_model_test.dart' show artifact;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  WeatherSnapshot weather(String city) {
    final data = weatherFixture(city: city)..['source'] = 'Open-Meteo';
    data['current']['weatherCode'] = 61;
    return WeatherSnapshot.fromJson(data);
  }

  final loader = RainModelLoader(
    read: () async => jsonEncode(artifact()..['intercept'] = 2),
  );
  Widget screen(String city, {bool live = true, double scale = 1}) =>
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: WeatherLiveStatus(
              isLive: live,
              child: SingleChildScrollView(
                child: PreparednessRecommendations(
                  weather: weather(city),
                  loader: loader,
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'contextual advice shows AI forecast and heat sources with location and window',
    (tester) async {
      await tester.pumpWidget(screen('Manila'));
      await tester.pumpAndSettle();
      expect(find.text('Weather recommendations'), findsOneWidget);
      expect(find.text('For Manila'), findsOneWidget);
      expect(find.text('Bring an umbrella or raincoat'), findsOneWidget);
      expect(
        find.textContaining('AI rain prediction · Experimental'),
        findsOneWidget,
      );
      expect(find.textContaining('Weather forecast'), findsOneWidget);
      expect(find.text('Calculated heat index'), findsOneWidget);
      expect(find.textContaining('AI window:'), findsOneWidget);
      expect(find.textContaining('Forecast window:'), findsOneWidget);
      expect(find.textContaining('light clothing'), findsWidgets);
      expect(find.text('Prepare an emergency kit'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'saved mode retains general flood and kit advice without current predictions',
    (tester) async {
      await tester.pumpWidget(screen('Manila', live: false));
      await tester.pumpAndSettle();
      expect(find.text('Bring an umbrella or raincoat'), findsNothing);
      expect(find.textContaining('Saved or expired weather'), findsOneWidget);
      await tester.ensureVisible(find.text('Flood and emergency preparedness'));
      await tester.tap(find.text('Flood and emergency preparedness'));
      await tester.pumpAndSettle();
      expect(find.text('Prepare an emergency kit'), findsOneWidget);
      expect(
        find.textContaining('Never walk or drive through floodwater'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No live flood or typhoon warning feed'),
        findsOneWidget,
      );
      expect(find.text('General preparedness'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'city changes replace contextual location and close previous general expansion',
    (tester) async {
      await tester.pumpWidget(screen('Manila'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Flood and emergency preparedness'));
      await tester.tap(find.text('Flood and emergency preparedness'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen('Makati'));
      await tester.pumpAndSettle();
      expect(find.text('For Makati'), findsOneWidget);
      expect(find.text('For Manila'), findsNothing);
      expect(find.text('Prepare an emergency kit'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the periodic reevaluation removes advice when weather expires', (
    tester,
  ) async {
    final snapshot = weather('Manila');
    var now = snapshot.updatedAt.add(const Duration(minutes: 29, seconds: 59));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherLiveStatus(
            isLive: true,
            child: SingleChildScrollView(
              child: PreparednessRecommendations(
                weather: snapshot,
                loader: loader,
                now: () => now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bring an umbrella or raincoat'), findsOneWidget);
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Bring an umbrella or raincoat'), findsNothing);
    expect(find.textContaining('Saved or expired weather'), findsOneWidget);
    await tester.ensureVisible(find.text('Flood and emergency preparedness'));
    await tester.tap(find.text('Flood and emergency preparedness'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare an emergency kit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 1366.0]) {
    testWidgets(
      'recommendations and expanded general advice fit width $width with 2x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(screen('Manila', scale: 2));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Flood and emergency preparedness'),
        );
        await tester.tap(find.text('Flood and emergency preparedness'));
        await tester.pumpAndSettle();
        expect(find.text('Prepare an emergency kit'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
