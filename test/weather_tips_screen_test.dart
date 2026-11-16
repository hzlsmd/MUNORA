import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';

import 'weather_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'tips follow selected city and refresh from actual weather data',
    (tester) async {
      var hot = false;
      final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((req) async {
          final json = weatherFixture(city: req.url.queryParameters['city']!);
          json['current'].addAll({
            'temperature': hot ? 33 : 26,
            'feelsLike': hot ? 36 : 28,
            'humidity': 60,
          });
          return http.Response(jsonEncode(json), 200);
        }),
      );
      addTearDown(service.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      Widget screen(String city) => MaterialApp(
        home: Scaffold(
          body: AIScreen(navigate: (_) {}, city: city, service: service),
        ),
      );
      await tester.pumpWidget(screen('Muntinlupa'));
      await tester.pumpAndSettle();
      expect(find.text('Weather recommendations'), findsOneWidget);
      expect(find.text('Forecast-based recommendation'), findsNothing);
      expect(find.text('Forecast-based weather guidance'), findsNothing);
      expect(find.text('Stay Hydrated'), findsNothing);
      expect(find.text('Bring an umbrella or raincoat'), findsOneWidget);
      expect(find.text('Wear light clothing and drink water'), findsNothing);
      await tester.ensureVisible(find.text('Heat'));
      await tester.tap(find.text('Heat'));
      await tester.pumpAndSettle();
      hot = true;
      await tester.tap(find.byTooltip('Refresh weather'));
      await tester.pumpAndSettle();
      expect(find.text('Wear light clothing and drink water'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Heat'))
            .selected,
        isTrue,
      );
      expect(find.text('Bring an umbrella or raincoat'), findsNothing);
      await tester.pumpWidget(screen('Manila'));
      await tester.pumpAndSettle();
      expect(find.text('Manila'), findsOneWidget);
      expect(find.text('Muntinlupa'), findsNothing);
      expect(find.text('Bring an umbrella or raincoat'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets(
    'old saved weather shows refresh advice rather than current rain advice',
    (tester) async {
      final json = weatherFixture(
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      SharedPreferences.setMockInitialValues({
        'weather.v1.Muntinlupa': jsonEncode(json),
      });
      final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async => http.Response('{}', 503)),
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
      expect(find.textContaining('Saved or expired weather'), findsOneWidget);
      expect(find.text('Bring an umbrella or raincoat'), findsNothing);
      expect(find.textContaining('Saved weather.'), findsOneWidget);
    },
  );
}
