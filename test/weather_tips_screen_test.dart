import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';
import 'weather_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('tips follow selected city and refresh from actual weather data',
      (tester) async {
    var hot = false;
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((req) async {
          final json = weatherFixture(city: req.url.queryParameters['city']!);
          if (hot) json['current']['temperature'] = 33;
          return http.Response(jsonEncode(json), 200);
        }));
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    Widget screen(String city) => MaterialApp(
        home: Scaffold(
            body: AIScreen(navigate: (_) {}, city: city, service: service)));
    await tester.pumpWidget(screen('Muntinlupa'));
    await tester.pumpAndSettle();
    expect(find.text('Bring rain protection'), findsOneWidget);
    expect(find.text('Take breaks from the heat'), findsNothing);
    hot = true;
    await tester.tap(find.byTooltip('Refresh weather'));
    await tester.pumpAndSettle();
    expect(find.text('Take breaks from the heat'), findsOneWidget);
    await tester.pumpWidget(screen('Manila'));
    await tester.pumpAndSettle();
    expect(find.text('Manila'), findsOneWidget);
    expect(find.text('Muntinlupa'), findsNothing);
    expect(find.text('Bring rain protection'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
      'old saved weather shows refresh advice rather than current rain advice',
      (tester) async {
    final json = weatherFixture(
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)));
    SharedPreferences.setMockInitialValues(
        {'weather.v1.Muntinlupa': jsonEncode(json)});
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async => http.Response('{}', 503)));
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AIScreen(
                navigate: (_) {}, city: 'Muntinlupa', service: service))));
    await tester.pumpAndSettle();
    expect(find.text('Refresh before planning'), findsOneWidget);
    expect(find.text('Bring rain protection'), findsNothing);
    expect(find.textContaining('Saved weather.'), findsOneWidget);
  });
}
