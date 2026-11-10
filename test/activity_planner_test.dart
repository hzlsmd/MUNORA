import 'package:flutter_test/flutter_test.dart';
import 'package:munora/models/planning_hour.dart';
import 'package:munora/services/activity_planner.dart';
import 'package:munora/services/weather_insights.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 0);
  PlanningHour hour(
    int i, {
    double temp = 27,
    double rain = 10,
    double wind = 2,
    int? code = 0,
    double? uv = 2,
  }) => PlanningHour(
    at: now.add(Duration(hours: i)),
    temperature: temp,
    feelsLike: temp,
    rain: rain,
    uv: uv,
    wind: wind,
    code: code,
  );
  WeatherInsights data(List<PlanningHour> hours) =>
      WeatherInsights(fetchedAt: now, hours: hours);
  test('all supported precipitation codes require precautions', () {
    for (final code in [51, 61, 82, 85, 86]) {
      expect(
        assessActivity(
          data([hour(1, code: code)]),
          Activity.walk,
          now.add(const Duration(hours: 1)),
          1,
          now,
        ).status,
        PlanStatus.caution,
      );
    }
  });
  test('exercise is more cautious than commuting in the same heat', () {
    final forecast = data([hour(1, temp: 31)]);
    expect(
      assessActivity(
        forecast,
        Activity.exercise,
        now.add(const Duration(hours: 1)),
        1,
        now,
      ).status,
      PlanStatus.caution,
    );
    expect(
      assessActivity(
        forecast,
        Activity.commute,
        now.add(const Duration(hours: 1)),
        1,
        now,
      ).status,
      PlanStatus.favorable,
    );
  });
  test('storm overrides low rain and incomplete UV', () {
    final result = assessActivity(
      data([hour(1, code: 95, uv: null)]),
      Activity.walk,
      now.add(const Duration(hours: 1)),
      1,
      now,
    );
    expect(result.status, PlanStatus.postpone);
    expect(result.reasons.join(' '), contains('Thunderstorm'));
  });
  test('known storm is retained even when another hour is missing', () {
    final result = assessActivity(
      data([hour(1, code: 95)]),
      Activity.walk,
      now.add(const Duration(hours: 1)),
      2,
      now,
    );
    expect(result.status, PlanStatus.postpone);
  });
  test('worst hour controls the entire window', () {
    final result = assessActivity(
      data([hour(1), hour(2, wind: 16)]),
      Activity.walk,
      now.add(const Duration(hours: 1)),
      2,
      now,
    );
    expect(result.status, PlanStatus.postpone);
    expect(result.reasons.join(' '), contains('16.0 m/s'));
  });
  test('missing hours, unknown codes and stale data are insufficient', () {
    final start = now.add(const Duration(hours: 1));
    expect(
      assessActivity(data([hour(1)]), Activity.walk, start, 2, now).status,
      PlanStatus.unavailable,
    );
    expect(
      assessActivity(
        data([hour(1, code: null)]),
        Activity.walk,
        start,
        1,
        now,
      ).status,
      PlanStatus.unavailable,
    );
    expect(
      assessActivity(
        data([hour(1)]),
        Activity.walk,
        start,
        1,
        now.add(const Duration(minutes: 31)),
      ).status,
      PlanStatus.unavailable,
    );
  });
  test(
    'alternative excludes storms and chooses a complete favorable window',
    () {
      final forecast = data([
        hour(1, rain: 80),
        hour(2, code: 95),
        hour(3),
        hour(4),
      ]);
      final alternative = findBetterWindow(
        forecast,
        Activity.walk,
        now.add(const Duration(hours: 1)),
        2,
        now,
      );
      expect(alternative?.start, now.add(const Duration(hours: 3)));
      expect(
        findBetterWindow(
          data([hour(1, code: 95)]),
          Activity.walk,
          now.add(const Duration(hours: 1)),
          1,
          now,
        ),
        isNull,
      );
    },
  );
  test(
    'past, nonhourly, excessive duration and distant starts are rejected',
    () {
      final forecast = data([hour(1)]);
      for (final start in [
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(minutes: 30)),
        now.add(const Duration(hours: 37)),
      ]) {
        expect(
          assessActivity(forecast, Activity.walk, start, 1, now).status,
          PlanStatus.unavailable,
        );
      }
      expect(
        assessActivity(
          forecast,
          Activity.walk,
          now.add(const Duration(hours: 1)),
          4,
          now,
        ).status,
        PlanStatus.unavailable,
      );
    },
  );
}
