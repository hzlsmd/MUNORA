import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/weather_recommendations.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 4);
  Map<String, dynamic> clearWeather() {
    final json = weatherFixture(updatedAt: now);
    json['current']['condition'] = 'clear sky';
    for (final point in json['hourly']) {
      point['condition'] = 'clear sky';
    }
    return json;
  }

  List<WeatherTip> tips(Map<String, dynamic> json) =>
      weatherRecommendations(WeatherSnapshot.fromJson(json), now);

  test(
    'clear weather provides cautious general advice, never promises safety',
    () {
      expect(tips(clearWeather()).map((t) => t.id), ['routine']);
    },
  );
  test('current rain, drizzle and showers trigger rain protection', () {
    for (final condition in [
      'Light rain',
      'Dense drizzle',
      'Moderate rain showers',
    ]) {
      final json = clearWeather();
      json['current']['condition'] = condition;
      expect(tips(json).map((t) => t.id), ['rain']);
    }
  });
  test('rain at the six-hour boundary is explained with forecast time', () {
    final json = clearWeather();
    json['hourly'][2]['condition'] = 'Light rain';
    final tip = tips(json).single;
    expect(tip.id, 'rain');
    expect(tip.reason, contains('7/11 6:00 PM PHT'));
  });
  test(
    'past rain and rain outside the next six hours do not trigger advice',
    () {
      final json = clearWeather();
      json['hourly'][0]['at'] = now
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      json['hourly'][0]['condition'] = 'Heavy rain';
      json['hourly'][2]['at'] = now
          .add(const Duration(hours: 7))
          .toIso8601String();
      json['hourly'][2]['condition'] = 'Heavy rain';
      expect(tips(json).map((t) => t.id), ['routine']);
    },
  );
  test('storm guidance precedes rain, heat and wind tips', () {
    final json = clearWeather();
    json['current']['condition'] = 'Thunderstorm';
    json['current']['temperature'] = 32;
    json['current']['wind'] = 10;
    json['hourly'][1]['condition'] = 'Heavy rain';
    expect(tips(json).map((t) => t.id), ['storm', 'rain', 'heat', 'wind']);
  });
  test('heat and wind thresholds use unrounded numeric measurements', () {
    for (final change in [
      {
        'temperature': 31.99,
        'feelsLike': 34.99,
        'wind': 9.99,
        'expected': 'routine',
      },
      {'temperature': 32, 'expected': 'heat'},
      {'feelsLike': 35, 'expected': 'heat'},
      {'wind': 10, 'expected': 'wind'},
    ]) {
      final json = clearWeather();
      for (final entry in change.entries.where((e) => e.key != 'expected')) {
        json['current'][entry.key] = entry.value;
      }
      expect(tips(json).map((t) => t.id), [change['expected']]);
    }
  });
  test('old or future weather gives only a refresh recommendation', () {
    for (final age in [
      const Duration(minutes: 31),
      const Duration(hours: 25),
      const Duration(minutes: -6),
    ]) {
      final json = weatherFixture(updatedAt: now.subtract(age));
      expect(tips(json).map((t) => t.id), ['stale']);
    }
  });
}
