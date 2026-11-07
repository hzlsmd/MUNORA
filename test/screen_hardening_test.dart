import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/home_screen.dart';
import 'package:munora/screens/forecast_screen.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/screens/splash_screen.dart';
import 'package:munora/services/weather_service.dart';
import 'weather_fixture.dart';
import 'open_meteo_test.dart' show openMeteoFixture;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('model attribution and timestamps fit at 320px with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = WeatherService(
        client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode(openMeteoFixture(DateTime.now().toUtc()))),
            200)));
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(
                    size: Size(320, 900), textScaler: TextScaler.linear(2)),
                child: HomeScreen(
                    navigate: (_) {},
                    onCityChange: (_) {},
                    city: 'Muntinlupa',
                    service: service)))));
    await tester.pumpAndSettle();
    expect(find.text('Weather data by Open-Meteo'), findsOneWidget);
    expect(find.textContaining('Model estimate'), findsOneWidget);
    expect(find.text('CC BY 4.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('splash does not impose a cosmetic three-second startup delay',
      (tester) async {
    var ready = false;
    await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onDone: () => ready = true)));
    final readyOnFirstFrame = ready;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(readyOnFirstFrame, isTrue);
  });
  for (final screen in ['home', 'forecast', 'ai']) {
    testWidgets('$screen supports 320px width and 2x accessibility text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = WeatherService(
          endpoint: 'https://weather.example',
          client: MockClient(
              (_) async => http.Response(jsonEncode(weatherFixture()), 200)));
      addTearDown(service.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 900), textScaler: TextScaler.linear(2)),
        child: screen == 'ai'
            ? AIScreen(navigate: (_) {})
            : screen == 'home'
                ? HomeScreen(
                    navigate: (_) {},
                    onCityChange: (_) {},
                    city: 'Muntinlupa',
                    service: service)
                : ForecastScreen(
                    navigate: (_) {}, city: 'Muntinlupa', service: service),
      ))));
      await tester.pumpAndSettle();
      if (screen == 'home') {
        await tester.tap(find.text('Muntinlupa'));
        await tester.pump();
      } else if (screen == 'forecast') {
        await tester.tap(find.text('3-Hour'));
        await tester.pump();
      } else {
        final button = find.textContaining('Ask AI About');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('demo chat rejects overlapping submissions', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AIScreen(navigate: (_) {}))));
    final button = find.textContaining('Ask AI About');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'first request');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'second request');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('first request'), findsOneWidget);
    // A rejected second submission remains in the input, not in a second bubble.
    expect(find.text('second request'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'second request');
    await tester.pump(const Duration(milliseconds: 1200));
  });

  testWidgets('demo insights do not advertise unmeasured prediction confidence',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AIScreen(navigate: (_) {}))));
    expect(find.text('85%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chat accepts emoji according to its displayed character limit',
      (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AIScreen(navigate: (_) {}))));
    final button = find.textContaining('Ask AI About');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '\u{1F600}' * 600);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.pump(const Duration(milliseconds: 1200));
  });
}
