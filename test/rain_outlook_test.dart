import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/rain_model.dart';
import 'package:munora/services/rain_outlook.dart';

import 'rain_model_test.dart' show artifact;
import 'weather_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 2, 15);
  WeatherSnapshot weather({
    Duration age = Duration.zero,
    String source = 'Open-Meteo',
    String city = 'Manila',
    double humidity = 80,
  }) {
    final json = weatherFixture(city: city, updatedAt: now.subtract(age));
    json['source'] = source;
    json['current']['weatherCode'] = 61;
    json['current']['humidity'] = humidity;
    return WeatherSnapshot.fromJson(json);
  }

  final model = RainModel.fromJson(artifact());
  RainOutlook outlook(
    WeatherSnapshot w, {
    bool live = true,
    RainModel? useModel,
  }) => evaluateRainOutlook(w, model: useModel ?? model, live: live, now: now);

  test(
    'outlook preserves the model probability and observation anchored window',
    () {
      final result = outlook(weather());
      expect(result.prediction!.probability, .5);
      expect(result.prediction!.estimatedAt, now);
      expect(result.prediction!.windowEnd, DateTime.utc(2026, 11, 14, 5, 15));
      expect(result.unavailableReason, isNull);
    },
  );

  test('outlook distinguishes saved, stale, future, unsupported and missing model states', () {
    final cases = [
      (outlook(weather(), live: false), 'Saved weather'),
      (
        outlook(weather(age: const Duration(minutes: 31))),
        'older than 30 minutes',
      ),
      (
        outlook(weather(age: const Duration(minutes: -6))),
        'ahead of the current time',
      ),
      (outlook(weather(source: 'OpenWeatherMap')), 'weather source'),
      (outlook(weather(city: 'Cebu')), 'supported range'),
      (outlook(weather(humidity: 10)), 'supported range'),
      (
        evaluateRainOutlook(weather(), model: null, live: true, now: now),
        'could not be loaded or validated',
      ),
    ];
    for (final (result, reason) in cases) {
      expect(result.prediction, isNull);
      expect(result.unavailableReason, contains(reason));
    }
  });

  test('missing raw inputs and expired forecast metadata explain why AI is unavailable', () {
    final w = weather();
    final missing = WeatherSnapshot(
      city: w.city,
      temperature: w.temperature,
      feelsLike: w.feelsLike,
      windSpeed: w.windSpeed,
      humidity: null,
      pressure: w.pressure,
      weatherCode: w.weatherCode,
      readings: w.readings,
      source: w.source,
      updatedAt: w.updatedAt,
      observedAt: w.observedAt,
      forecastUntil: w.forecastUntil,
      current: w.current,
      hourly: w.hourly,
      daily: w.daily,
    );
    expect(outlook(missing).prediction, isNull);
    expect(
      outlook(missing).unavailableReason,
      contains('required weather input is missing'),
    );
    final json = weatherFixture(updatedAt: now)..['source'] = 'Open-Meteo';
    json['updatedAt'] = now
        .subtract(const Duration(minutes: 31))
        .toIso8601String();
    json['current']['weatherCode'] = 61;
    final expired = outlook(WeatherSnapshot.fromJson(json));
    expect(expired.prediction, isNull);
    expect(expired.unavailableReason, contains('Weather data has expired'));
  });

  test('complete future plan including exact window end receives supplementary guidance', () {
    final result = rainPlanAdvice(
      outlook(weather()),
      Activity.walk,
      DateTime.utc(2026, 11, 14, 3, 15),
      2,
      now,
    );
    expect(result.covered, isTrue);
    expect(result.message, contains('Keep checking'));
  });

  test('partial, outside, past and invalid plans do not receive a plan probability or advice', () {
    for (final (start, duration) in [
      (DateTime.utc(2026, 11, 14, 4), 2),
      (DateTime.utc(2026, 11, 14, 6), 1),
      (now.subtract(const Duration(minutes: 1)), 1),
      (now, 0),
      (now, 4),
    ]) {
      final result = rainPlanAdvice(
        outlook(weather()),
        Activity.walk,
        start,
        duration,
        now,
      );
      expect(result.covered, isFalse);
      expect(result.message, isNot(contains('Carry rain protection')));
    }
    final unavailable = rainPlanAdvice(
      outlook(weather(), live: false),
      Activity.work,
      now,
      1,
      now,
    );
    expect(unavailable.covered, isFalse);
    expect(unavailable.message, contains('Saved weather'));
  });

  test('60 percent threshold generates activity-specific preparedness, never an all clear', () {
    for (final (activity, expected) in [
      (Activity.commute, 'extra travel time'),
      (Activity.walk, 'route with shelter'),
      (Activity.exercise, 'indoor alternative'),
      (Activity.work, 'during outdoor work'),
    ]) {
      final high = RainOutlook.available(RainPrediction(.6, now, 'test'));
      final low = RainOutlook.available(RainPrediction(.599, now, 'test'));
      expect(
        rainPlanAdvice(high, activity, now, 1, now).message,
        contains(expected),
      );
      expect(
        rainPlanAdvice(low, activity, now, 1, now).message,
        contains('Keep checking'),
      );
    }
  });
}
