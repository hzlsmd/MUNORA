import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/screens/forecast_screen.dart';
import 'package:munora/services/weather_service.dart';

import 'weather_fixture.dart';

void main() {
  testWidgets('Forecast switches from five-day view to hourly timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now().toUtc();
    final json = weatherFixture(updatedAt: now);
    final template = Map<String, dynamic>.from(json['hourly'][0]);
    json['hourly'] = List.generate(
      120,
      (i) => {...template, 'at': now.add(Duration(hours: i)).toIso8601String()},
    );
    final service = WeatherService(
      endpoint: 'https://weather.example',
      client: MockClient((_) async => http.Response(jsonEncode(json), 200)),
    );
    addTearDown(service.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForecastScreen(
            navigate: (_) {},
            city: 'Muntinlupa',
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('5-Day Forecast'), findsOneWidget);
    expect(find.text('Hourly'), findsOneWidget);
    await tester.tap(find.text('Hourly'));
    await tester.pumpAndSettle();
    expect(find.text('1-hour intervals'), findsOneWidget);
    expect(find.text('3-Hour'), findsNothing);
  });
}
