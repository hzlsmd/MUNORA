import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:munora/screens/alerts_screen.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';

import 'weather_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('alerts follow the selected city rather than demo data', (
    tester,
  ) async {
    final service = WeatherService(
      endpoint: 'https://weather.example',
      client: MockClient((req) async {
        final city = req.url.queryParameters['city']!;
        final data = weatherFixture(city: city);
        if (city == 'Manila') {
          data['current']['condition'] = 'Clear sky';
          for (final point in data['hourly']) {
            point['condition'] = 'Clear sky';
          }
        }
        return http.Response(jsonEncode(data), 200);
      }),
    );
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    Widget screen(String city) => MaterialApp(
      home: Scaffold(
        body: AlertsScreen(navigate: (_) {}, city: city, service: service),
      ),
    );
    await tester.pumpWidget(screen('Muntinlupa'));
    await tester.pumpAndSettle();
    expect(find.text('Bring rain protection'), findsOneWidget);
    expect(find.textContaining('App-generated'), findsWidgets);
    await tester.pumpWidget(screen('Manila'));
    await tester.pumpAndSettle();
    expect(find.text('Bring rain protection'), findsNothing);
    expect(find.text('No forecast triggers detected'), findsOneWidget);
    expect(find.textContaining('not an all-clear'), findsOneWidget);
  });
  testWidgets('tip filters show empty states and expand the actual reason', (
    tester,
  ) async {
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
          body: AIScreen(
            navigate: (_) {},
            city: 'Muntinlupa',
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heat'));
    await tester.pumpAndSettle();
    expect(find.text('No tips in this category right now'), findsOneWidget);
    expect(find.text('Bring rain protection'), findsNothing);
    await tester.tap(find.text('Rain'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Why this suggestion?'));
    await tester.tap(find.text('Why this suggestion?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('light rain in the current estimate.'),
      findsOneWidget,
    );
  });
}
