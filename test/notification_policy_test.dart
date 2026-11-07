import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/notification_policy.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8, 5);
  WeatherSnapshot rain({String city = 'Muntinlupa'}) =>
      WeatherSnapshot.fromJson(weatherFixture(city: city, updatedAt: now));

  test('rain produces advice while routine and expired data stay silent', () {
    expect(notificationTips(rain(), now, {}).map((t) => t.id), ['rain']);
    expect(
      notificationTips(rain(), now.add(const Duration(hours: 4)), {}),
      isEmpty,
    );
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'clear sky';
    for (final point in json['hourly']) {
      point['condition'] = 'clear sky';
    }
    expect(notificationTips(WeatherSnapshot.fromJson(json), now, {}), isEmpty);
  });

  test(
    'six-hour suppression is per city and trigger, and clock rollback is quiet',
    () {
      final key = notificationKey('Muntinlupa', 'rain');
      expect(notificationTips(rain(), now, {key: now}), isEmpty);
      expect(
        notificationTips(rain(city: 'Manila'), now, {key: now}),
        hasLength(1),
      );
      expect(
        notificationTips(rain(), now, {
          key: now.subtract(const Duration(hours: 6)),
        }),
        hasLength(1),
      );
      expect(
        notificationTips(rain(), now, {key: now.add(const Duration(hours: 1))}),
        isEmpty,
      );
    },
  );
}
