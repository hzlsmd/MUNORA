import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/weather_alerts.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8, 4);
  Map<String, dynamic> calm() {
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'Clear sky';
    for (final point in json['hourly']) {
      point['condition'] = 'Clear sky';
    }
    return json;
  }

  test('benign readings are not converted into alerts', () {
    expect(weatherAlerts(WeatherSnapshot.fromJson(calm()), now), isEmpty);
  });
  test('current rain produces a notice with an explanation', () {
    final alerts = weatherAlerts(
      WeatherSnapshot.fromJson(weatherFixture(updatedAt: now)),
      now,
    );
    expect(alerts.map((a) => a.id), ['rain']);
    expect(alerts.single.reason.toLowerCase(), contains('light rain'));
  });
  test('heat and wind trigger at the existing thresholds', () {
    final json = calm();
    json['current']['temperature'] = 32;
    json['current']['wind'] = 10;
    expect(
      weatherAlerts(WeatherSnapshot.fromJson(json), now).map((a) => a.id),
      ['heat', 'wind'],
    );
    json['current']['temperature'] = 31.9;
    json['current']['wind'] = 9.9;
    expect(weatherAlerts(WeatherSnapshot.fromJson(json), now), isEmpty);
  });
  test('storm notice uses only upcoming six-hour readings', () {
    final json = calm();
    json['hourly'][1]['condition'] = 'Thunderstorm';
    expect(
      weatherAlerts(WeatherSnapshot.fromJson(json), now).map((a) => a.id),
      ['storm'],
    );
    json['hourly'][1]['at'] = now
        .add(const Duration(hours: 7))
        .toIso8601String();
    expect(weatherAlerts(WeatherSnapshot.fromJson(json), now), isEmpty);
  });
  test(
    'stale conditions produce refresh guidance, not calm or active notices',
    () {
      final snapshot = WeatherSnapshot.fromJson(weatherFixture(updatedAt: now));
      expect(
        weatherAlerts(
          snapshot,
          now.add(const Duration(hours: 2)),
        ).map((a) => a.id),
        ['stale'],
      );
    },
  );
}
