import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/services/notification_service.dart';

import 'weather_fixture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final now = DateTime.utc(2026, 11, 16, 5);
  test('native delivery includes advice, channel, payload and can alert a new event', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'notifications.weather.enabled': true,
    });
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'initialize' ||
          call.method == 'areNotificationsEnabled') {
        return true;
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    final service = NotificationService(
      now: () => now,
      weatherService: () => WeatherService(
        now: () => now,
        endpoint: 'https://weather.example',
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(weatherFixture(updatedAt: now)), 200),
        ),
      ),
    );
    await service.checkWeather();
    expect(calls.map((c) => c.method), contains('createNotificationChannel'));
    final delivered =
        calls.singleWhere((c) => c.method == 'show').arguments as Map;
    expect(delivered['body'], contains('umbrella'));
    expect(jsonDecode(delivered['payload'])['city'], 'Muntinlupa');
    expect(delivered['platformSpecifics']['onlyAlertOnce'], isFalse);
    await service.checkWeather();
    expect(calls.where((c) => c.method == 'show'), hasLength(1));
  });
  test(
    'city change during native posting cancels the previous city alert',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({
        'notifications.weather.enabled': true,
      });
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'show') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selectedCity', 'Manila');
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });
      final service = NotificationService(
        now: () => now,
        weatherService: () => WeatherService(
          now: () => now,
          endpoint: 'https://weather.example',
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode(weatherFixture(updatedAt: now)), 200),
          ),
        ),
      );
      await service.checkWeather();
      expect(calls.map((c) => c.method), contains('cancel'));
    },
  );
}
