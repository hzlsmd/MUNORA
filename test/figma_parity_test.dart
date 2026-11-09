import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/screens/alerts_screen.dart';
import 'package:munora/services/weather_service.dart';

import 'weather_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'calm preview cannot conceal current hazards and returns to notices',
    (tester) async {
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
            body: AlertsScreen(
              navigate: (_) {},
              city: 'Muntinlupa',
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Active Hazards (1)'), findsOneWidget);
      await tester.tap(find.text('Calm Skies'));
      await tester.pumpAndSettle();
      expect(
        find.text('Preview only — current notices remain active'),
        findsOneWidget,
      );
      expect(find.text('No forecast triggers detected'), findsNothing);
      await tester.ensureVisible(find.text('Return to Current Hazards'));
      await tester.tap(find.text('Return to Current Hazards'));
      await tester.pumpAndSettle();
      expect(find.text('Bring rain protection'), findsOneWidget);
    },
  );
  testWidgets('tips expose all Figma sections and retain local feedback', (
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
    for (final title in [
      'Model Prediction Confidence',
      'AI Personalization Insights',
      'Plan My Activity',
      'Outdoor activity window',
      'Stay Hydrated',
      'Check the UV Index',
      'Plan Outdoor Activities',
      'Travel Prepared',
      'Thunderstorm Safety',
      'Was this guidance helpful?',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.ensureVisible(find.byTooltip('Helpful'));
    await tester.tap(find.byTooltip('Helpful'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'tips.feedback.Muntinlupa',
      ),
      1,
    );
  });
}
