import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/weather_recommendations.dart';
import 'package:munora/services/weather_alerts.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 5);
  test(
    'upcoming heat and wind trigger before current conditions become hazardous',
    () {
      final json = weatherFixture(updatedAt: now);
      json['hourly'][1]['temperature'] = 36;
      json['hourly'][1]['high'] = 37;
      json['hourly'][1]['feelsLike'] = 41;
      json['hourly'][1]['windSpeed'] = 12;
      final tips = weatherRecommendations(WeatherSnapshot.fromJson(json), now);
      expect(tips.map((t) => t.id), containsAll(['heat', 'wind']));
      expect(
        tips.firstWhere((t) => t.id == 'heat').reason,
        contains('forecast'),
      );
    },
  );
  test('rain probability and UV use measured forecast fields without fabricated values', () {
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'Clear sky';
    for (final point in json['hourly']) {
      point['condition'] = 'Clear sky';
      point['rainProbability'] = 85;
      point['uvIndex'] = 9;
    }
    final tips = weatherRecommendations(WeatherSnapshot.fromJson(json), now);
    expect(tips.map((t) => t.id), containsAll(['rain', 'uv']));
    expect(
      weatherAlerts(WeatherSnapshot.fromJson(json), now).map((t) => t.id),
      contains('uv'),
    );
    expect(tips.firstWhere((t) => t.id == 'rain').reason, contains('85%'));
  });
}
