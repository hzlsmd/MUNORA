import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/push_notifications.dart';
import 'package:munora/services/push_state.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const messaging = MethodChannel('plugins.flutter.io/firebase_messaging');

  test('legacy cleanup unsubscribes and unregisters using the current Messaging API', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    setupFirebaseCoreMocks();
    addTearDown(() => TestFirebaseCoreHostApi.setUp(null));
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(messaging, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'Messaging#setAutoInitEnabled':
          return {'isAutoInitEnabled': call.arguments['enabled']};
        case 'Messaging#unsubscribeFromTopic':
        case 'Messaging#unregister':
          return null;
        default:
          throw PlatformException(
            code: 'unsupported-api',
            message: call.method,
          );
      }
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        messaging,
        null,
      ),
    );
    SharedPreferences.setMockInitialValues({
      PushSubscriptions.knownKey: ['munora_weather_manila'],
      PushSubscriptions.confirmedKey: 'munora_weather_manila',
    });
    await PushNotifications.instance.cleanupLegacyPush();
    expect(
      PushNotifications.instance.status.value,
      contains('Previous push subscriptions removed'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PushSubscriptions.knownKey), isEmpty);
    expect(prefs.getString(PushSubscriptions.confirmedKey), isNull);
    expect(calls.map((c) => c.method), [
      'Messaging#setAutoInitEnabled',
      'Messaging#unsubscribeFromTopic',
      'Messaging#unregister',
    ]);
    expect(calls.first.arguments['enabled'], isFalse);
    expect(calls[1].arguments['topic'], 'munora_weather_manila');
    PushNotifications.instance.status.value = null;
  });
}
