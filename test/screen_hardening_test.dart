import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/home_screen.dart';
import 'package:munora/screens/forecast_screen.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/screens/alerts_screen.dart';
import 'package:munora/screens/splash_screen.dart';
import 'package:munora/services/weather_service.dart';

import 'weather_fixture.dart';
import 'open_meteo_test.dart' show openMeteoFixture;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('model attribution and timestamps fit at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = WeatherService(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(openMeteoFixture(DateTime.now().toUtc()))),
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: HomeScreen(
              navigate: (_) {},
              onCityChange: (_) {},
              city: 'Muntinlupa',
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weather data by Open-Meteo'), findsOneWidget);
    expect(find.textContaining('Model estimate'), findsOneWidget);
    expect(find.text('CC BY 4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('splash does not impose a cosmetic three-second startup delay', (
    tester,
  ) async {
    var ready = false;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onDone: () => ready = true)),
    );
    final readyOnFirstFrame = ready;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(readyOnFirstFrame, isTrue);
  });
  for (final screen in ['home', 'forecast', 'ai', 'alerts']) {
    testWidgets('$screen supports 320px width and 2x accessibility text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient(
          (_) async => http.Response(jsonEncode(weatherFixture()), 200),
        ),
      );
      addTearDown(service.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: screen == 'alerts'
                  ? AlertsScreen(
                      navigate: (_) {},
                      city: 'Muntinlupa',
                      service: service,
                    )
                  : screen == 'ai'
                  ? AIScreen(
                      navigate: (_) {},
                      city: 'Muntinlupa',
                      service: service,
                    )
                  : screen == 'home'
                  ? HomeScreen(
                      navigate: (_) {},
                      onCityChange: (_) {},
                      city: 'Muntinlupa',
                      service: service,
                    )
                  : ForecastScreen(
                      navigate: (_) {},
                      city: 'Muntinlupa',
                      service: service,
                    ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (screen == 'home') {
        await tester.tap(find.text('Muntinlupa'));
        await tester.pump();
      } else if (screen == 'forecast') {
        await tester.tap(find.text('3-Hour'));
        await tester.pump();
      } else if (screen == 'ai') {
        expect(find.text('Rule-based weather guidance'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
