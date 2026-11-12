import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/push_notifications.dart';
import 'package:munora/services/push_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('default local build attempts cleanup of legacy push and reports pending platform failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      PushSubscriptions.knownKey: ['munora_weather_manila'],
    });
    // No native Firebase host in this test. A default build must still attempt
    // cleanup and preserve its pending state instead of silently skipping it.
    await PushNotifications.instance.cleanupLegacyPush();
    expect(
      PushNotifications.instance.status.value,
      contains('cleanup is pending'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PushSubscriptions.knownKey), [
      'munora_weather_manila',
    ]);
    PushNotifications.instance.status.value = null;
  });
}
