import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/widgets/weather_view.dart';

import 'weather_fixture.dart';

void main() {
  testWidgets(
    'foreground weather refreshes automatically and pauses in background',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode(weatherFixture(updatedAt: DateTime.now().toUtc())),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeatherView(
              city: 'Muntinlupa',
              service: service,
              builder: (_) => const Text('Weather ready'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 20));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 3);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
