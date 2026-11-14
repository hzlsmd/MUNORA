import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/preparedness_recommendations.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/services/rain_outlook.dart';

import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 4);
  WeatherSnapshot weather({
    bool rain = false,
    bool storm = false,
    double temperature = 26,
    double humidity = 60,
    double wind = 2,
    DateTime? at,
    String city = 'Manila',
  }) {
    final data = weatherFixture(city: city, updatedAt: at ?? now)
      ..['source'] = 'Open-Meteo';
    data['current'].addAll({
      'temperature': temperature,
      'humidity': humidity,
      'feelsLike': temperature,
      'wind': wind,
      'condition': storm
          ? 'Thunderstorm'
          : rain
          ? 'Light rain'
          : 'Clear sky',
    });
    for (final point in data['hourly']) {
      point['condition'] = 'Clear sky';
    }
    return WeatherSnapshot.fromJson(data);
  }

  RainOutlook outlook(double p, {DateTime? at}) =>
      RainOutlook.available(RainPrediction(p, at ?? now, 'test-v1'));
  const unavailable = RainOutlook.unavailable('Model unavailable');

  test(
    'AI preparation starts at 60 percent and uses the observation window',
    () {
      final low = preparednessRecommendations(
        weather(),
        outlook: outlook(.599),
        live: true,
        now: now,
      );
      expect(low.contextual, isEmpty);
      final high = preparednessRecommendations(
        weather(),
        outlook: outlook(.6),
        live: true,
        now: now,
      );
      final rain = high.contextual.single;
      expect(rain.id, 'rain');
      expect(rain.sources, [PreparednessSource.aiRain]);
      expect(rain.advice.toLowerCase(), contains('umbrella'));
      expect(rain.from, now);
      expect(rain.until, DateTime.utc(2026, 11, 14, 7));
    },
  );

  test(
    'forecast rain survives low or unavailable AI and combines with high AI',
    () {
      for (final ai in [outlook(.1), unavailable]) {
        final result = preparednessRecommendations(
          weather(rain: true),
          outlook: ai,
          live: true,
          now: now,
        );
        expect(result.contextual.single.id, 'rain');
        expect(result.contextual.single.sources, [PreparednessSource.forecast]);
      }
      final both = preparednessRecommendations(
        weather(rain: true),
        outlook: outlook(.8),
        live: true,
        now: now,
      );
      expect(both.contextual.where((r) => r.id == 'rain'), hasLength(1));
      expect(
        both.contextual.single.sources,
        containsAll([PreparednessSource.aiRain, PreparednessSource.forecast]),
      );
    },
  );

  test(
    'combined rain keeps later forecast precautions beyond the AI window',
    () {
      final data = weatherFixture(city: 'Manila', updatedAt: now)
        ..['source'] = 'Open-Meteo';
      data['current'].addAll({
        'temperature': 26,
        'humidity': 60,
        'feelsLike': 26,
        'condition': 'Clear sky',
      });
      for (final point in data['hourly']) {
        point['condition'] = 'Clear sky';
      }
      data['hourly'][1]['at'] = now
          .add(const Duration(hours: 5))
          .toIso8601String();
      data['hourly'][1]['condition'] = 'Light rain';
      final rain = preparednessRecommendations(
        WeatherSnapshot.fromJson(data),
        outlook: outlook(.8),
        live: true,
        now: now,
      ).contextual.single;
      expect(rain.until, DateTime.utc(2026, 11, 14, 7));
      expect(rain.forecastFrom, now);
      expect(rain.forecastUntil, DateTime.utc(2026, 11, 14, 10));
      expect(rain.reason, contains('5:00 PM PHT'));
    },
  );

  test('supported heat index produces clothing and water advice below temperature trigger', () {
    final result = preparednessRecommendations(
      weather(temperature: 31, humidity: 80),
      outlook: unavailable,
      live: true,
      now: now,
    );
    final heat = result.contextual.single;
    expect(heat.id, 'heat');
    expect(heat.sources, [PreparednessSource.heatIndex]);
    expect(heat.advice, contains('light clothing'));
    expect(heat.advice, contains('water'));
  });

  test(
    'simultaneous storms heat wind and AI rain retain independent precautions',
    () {
      final result = preparednessRecommendations(
        weather(storm: true, temperature: 34, humidity: 70, wind: 12),
        outlook: outlook(.1),
        live: true,
        now: now,
      );
      expect(
        result.contextual.map((r) => r.id),
        containsAll(['storm', 'heat', 'wind']),
      );
      expect(result.contextual.first.id, 'storm');
      expect(result.contextual.first.advice.toLowerCase(), contains('indoors'));
    },
  );

  test('saved and expired weather suppress contextual advice while retaining preparedness', () {
    for (final live in [true, false]) {
      final data = live
          ? weather(rain: true, at: now.subtract(const Duration(hours: 2)))
          : weather(rain: true);
      final result = preparednessRecommendations(
        data,
        outlook: outlook(.9),
        live: live,
        now: now,
      );
      expect(result.contextual, isEmpty);
      expect(result.unavailableReason, isNotNull);
      expect(result.general.map((r) => r.id), [
        'flood_preparedness',
        'emergency_kit',
      ]);
      expect(
        result.general.every(
          (r) => r.sources.single == PreparednessSource.general,
        ),
        isTrue,
      );
      expect(
        result.general.every((r) => r.from == null && r.until == null),
        isTrue,
      );
    }
  });

  test('expired mismatched unsupported and malformed predictions cannot create AI advice', () {
    for (final ai in [
      outlook(.9, at: now.subtract(const Duration(minutes: 31))),
      outlook(.9, at: now.add(const Duration(minutes: 1))),
      outlook(double.nan),
      outlook(1.1),
    ]) {
      final result = preparednessRecommendations(
        weather(),
        outlook: ai,
        live: true,
        now: now,
      );
      expect(result.contextual, isEmpty);
    }
  });

  test('future thunderstorm forecast prompts indoor planning without a current-storm claim', () {
    final data = weatherFixture(city: 'Manila', updatedAt: now)
      ..['source'] = 'Open-Meteo';
    data['current'].addAll({
      'temperature': 26,
      'feelsLike': 26,
      'humidity': 60,
      'condition': 'Clear sky',
    });
    for (final point in data['hourly']) {
      point['condition'] = 'Clear sky';
    }
    data['hourly'][1]['condition'] = 'Thunderstorm';
    final result = preparednessRecommendations(
      WeatherSnapshot.fromJson(data),
      outlook: unavailable,
      live: true,
      now: now,
    );
    expect(result.contextual.single.id, 'storm');
    expect(result.contextual.single.reason, contains('forecast'));
    expect(result.contextual.single.from, now);
  });
}
