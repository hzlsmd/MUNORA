import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/home_screen.dart';
import 'package:munora/screens/ai_screen.dart';
import 'package:munora/services/weather_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('city selection remains available when weather fails', (
    tester,
  ) async {
    final service = WeatherService(
      endpoint: 'https://weather.example',
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            navigate: (_) {},
            onCityChange: (city) => selected = city,
            city: 'Muntinlupa',
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manila'));
    await tester.pumpAndSettle();
    expect(selected, 'Manila');
  });
  testWidgets(
    'Android notification controls remain available during an outage',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'notifications.weather.enabled': true,
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
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byTooltip('Notification settings'));
      await tester.pumpAndSettle();
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNotNull);
      expect(find.text('Send test notification'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    },
  );
}
