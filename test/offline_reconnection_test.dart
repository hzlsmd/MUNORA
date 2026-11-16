import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/widgets/weather_view.dart';

import 'weather_fixture.dart';

void main() {
  testWidgets(
    'offline retains real cached data and reconnect fetches a new snapshot',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final events = StreamController<List<ConnectivityResult>>();
      var requests = 0;
      final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(weatherFixture()), 200);
        }),
      );
      addTearDown(service.dispose);
      addTearDown(events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherView(
              city: 'Muntinlupa',
              service: service,
              connectivityChanges: events.stream,
              builder: (snapshot) => Text('Forecast ${snapshot.city}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      events.add([ConnectivityResult.none]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.text('Forecast Muntinlupa'), findsOneWidget);
      events.add([ConnectivityResult.wifi]);
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.textContaining('Offline'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('two-day cache is retained as reference, not live weather', () async {
    final now = DateTime.utc(2026, 11, 16);
    SharedPreferences.setMockInitialValues({
      'weather.v1.Manila': jsonEncode(
        weatherFixture(
          city: 'Manila',
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
      ),
    });
    final service = WeatherService(
      endpoint: 'https://weather.example',
      now: () => now,
    );
    addTearDown(service.dispose);
    final saved = await service.cached('Manila');
    expect(saved, isNotNull);
    expect(saved!.isUsable(now), isFalse);
  });
}
