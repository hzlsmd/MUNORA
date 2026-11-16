import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/push_notifications.dart';
import 'package:munora/services/notification_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  test(
    'background display honors categories, duplicate suppression, and opt-out',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({
        'notifications.weather.enabled': true,
        'selectedCity': 'Manila',
      });
      await const NotificationPreferences(categories: {'storm'}).save();
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
      final now = DateTime.now().toUtc();
      final message = RemoteMessage(
        data: {
          'schema': '2',
          'city': 'Manila',
          'eventId': 'manila:123',
          'issuedAt': now.toIso8601String(),
          'estimateAt': now.toIso8601String(),
          'route': 'alerts',
          'triggers': jsonEncode(['rain', 'storm']),
          'recommendations': jsonEncode({
            'rain': 'Bring an umbrella',
            'storm': 'Seek indoor shelter',
          }),
          'fingerprints': jsonEncode({'rain': 'rain:61', 'storm': 'storm:95'}),
        },
      );
      await Future.wait([
        PushNotifications.instance.displayMessage(message),
        PushNotifications.instance.displayMessage(message),
      ]);
      final show =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      expect(show['body'], contains('Seek indoor shelter'));
      expect(show['body'], isNot(contains('umbrella')));
      expect(show['platformSpecifics']['onlyAlertOnce'], isFalse);
      await PushNotifications.instance.displayMessage(message);
      expect(calls.where((c) => c.method == 'show'), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications.weather.enabled', false);
      await PushNotifications.instance.displayMessage(
        RemoteMessage(data: {...message.data, 'eventId': 'manila:456'}),
      );
      expect(calls.where((c) => c.method == 'show'), hasLength(1));
    },
  );
}
