import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/notification_policy.dart';
import 'package:munora/services/notification_preferences.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 5);
  final weather = WeatherSnapshot.fromJson(weatherFixture(updatedAt: now));
  test('preferences round trip and filter categories', () async {
    SharedPreferences.setMockInitialValues({});
    const preferences = NotificationPreferences(
      categories: {'storm'},
      quietStart: 22,
      quietEnd: 7,
    );
    await preferences.save();
    final loaded = await NotificationPreferences.load();
    expect(loaded.categories, {'storm'});
    expect(loaded.isQuiet(DateTime.utc(2026, 11, 16, 15)), isTrue);
    expect(loaded.isQuiet(now), isFalse);
    expect(
      selectNotificationTips(weather, now, {}, preferences: loaded),
      isEmpty,
    );
  });
  test('unchanged event is suppressed but changed weather can alert after cooldown', () {
    final tip = selectNotificationTips(weather, now, {}).single;
    final record = NotificationRecord(
      now.subtract(const Duration(hours: 2)),
      notificationFingerprint(weather, tip, now),
    );
    expect(selectNotificationTips(weather, now, {'rain': record}), isEmpty);
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'heavy rain';
    final changed = WeatherSnapshot.fromJson(json);
    expect(
      selectNotificationTips(changed, now, {'rain': record}).map((t) => t.id),
      ['rain'],
    );
    expect(
      selectNotificationTips(weather, now, {
        'rain': NotificationRecord(now, 'different'),
      }),
      isEmpty,
    );
  });
  test('quiet hours and stale data never deliver weather alerts', () {
    expect(
      selectNotificationTips(
        weather,
        now,
        {},
        preferences: const NotificationPreferences(
          quietStart: 12,
          quietEnd: 15,
        ),
      ),
      isEmpty,
    );
    expect(
      selectNotificationTips(weather, now.add(const Duration(days: 1)), {}),
      isEmpty,
    );
  });
  test(
    'clear-weather suggestions are optional and only sent during daytime',
    () {
      final json = weatherFixture(updatedAt: now);
      json['current']['condition'] = 'Clear sky';
      for (final point in json['hourly']) {
        point['condition'] = 'Clear sky';
      }
      final calm = WeatherSnapshot.fromJson(json);
      expect(selectNotificationTips(calm, now, {}), isEmpty);
      expect(
        selectNotificationTips(
          calm,
          now,
          {},
          preferences: const NotificationPreferences(categories: {'clear'}),
        ).single.id,
        'clear',
      );
    },
  );
  test('worsening forecast changes the fingerprint even before current rain starts', () {
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'Clear sky';
    final initial = WeatherSnapshot.fromJson(json);
    final tip = selectNotificationTips(initial, now, {}).single;
    final before = notificationFingerprint(initial, tip, now);
    json['hourly'][0]['condition'] = 'Heavy rain';
    final changed = WeatherSnapshot.fromJson(json);
    expect(notificationFingerprint(changed, tip, now), isNot(before));
  });
}
