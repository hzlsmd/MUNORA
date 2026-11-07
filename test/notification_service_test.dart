import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'background check is silent before opt-in without platform delivery',
    () async {
      final service = NotificationService();
      expect(await service.enabled(), isFalse);
      await service.checkWeather();
    },
  );
  test('persisted opt-in reloads and respects disabling', () async {
    SharedPreferences.setMockInitialValues({
      'notifications.weather.enabled': true,
    });
    final service = NotificationService();
    expect(await service.enabled(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications.weather.enabled', false);
    expect(await service.enabled(), isFalse);
    await service.checkWeather();
  });
  test('unsupported platforms cannot enable notifications', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await NotificationService().setEnabled(true), isFalse);
  });
}
