import '../models/planning_hour.dart';
import '../models/weather_snapshot.dart';
import 'weather_insights.dart';

enum Activity {
  commute('Commuting'),
  walk('Walking'),
  exercise('Exercise'),
  work('Outdoor work');

  final String label;
  const Activity(this.label);
}

enum PlanStatus {
  favorable('Fewer forecast concerns'),
  caution('Plan with precautions'),
  postpone('Consider postponing'),
  unavailable('Insufficient forecast data');

  final String label;
  const PlanStatus(this.label);
}

class ActivityAssessment {
  final DateTime start;
  final int durationHours;
  final PlanStatus status;
  final List<String> reasons, precautions;
  final double score;
  const ActivityAssessment({
    required this.start,
    required this.durationHours,
    required this.status,
    required this.reasons,
    required this.precautions,
    this.score = double.infinity,
  });
  String get summary => '${status.label}. ${reasons.join(' ')}';
}

ActivityAssessment assessActivity(
  WeatherInsights? forecast,
  Activity activity,
  DateTime start,
  int durationHours,
  DateTime now,
) {
  ActivityAssessment unavailable(String reason) => ActivityAssessment(
    start: start,
    durationHours: durationHours,
    status: PlanStatus.unavailable,
    reasons: [reason],
    precautions: const ['Refresh the forecast before planning.'],
  );
  final utc = start.toUtc();
  if (durationHours < 1 ||
      durationHours > 3 ||
      utc.minute != 0 ||
      utc.second != 0 ||
      utc.millisecond != 0 ||
      utc.microsecond != 0 ||
      utc.isBefore(now.toUtc()) ||
      utc.isAfter(now.toUtc().add(const Duration(hours: 36)))) {
    return unavailable(
      'Choose a future hourly start within 36 hours and a duration of 1–3 hours.',
    );
  }
  if (forecast == null || !forecast.isFresh(now.toUtc())) {
    return unavailable('Current planning data is unavailable or outdated.');
  }
  final selected = <PlanningHour>[];
  bool missingHours = false;
  for (var i = 0; i < durationHours; i++) {
    final matches = forecast.hours
        .where((h) => h.at == utc.add(Duration(hours: i)))
        .toList();
    if (matches.length != 1) {
      missingHours = true;
    } else {
      selected.add(matches.single);
    }
  }
  final severe = <String>[];
  for (final h in selected) {
    if (h.storm) severe.add('Thunderstorm forecast at ${weatherTime(h.at)}.');
    if (h.wind != null && h.wind! >= 15) {
      severe.add(
        'Wind ${h.wind!.toStringAsFixed(1)} m/s at ${weatherTime(h.at)}.',
      );
    }
    if (h.feelsLike != null && h.feelsLike! >= 41) {
      severe.add(
        'Feels like ${h.feelsLike!.round()}°C at ${weatherTime(h.at)}.',
      );
    }
  }
  if (severe.isNotEmpty) {
    return ActivityAssessment(
      start: utc,
      durationHours: durationHours,
      status: PlanStatus.postpone,
      reasons: severe,
      precautions: const [
        'Postpone exposed activity or use an indoor alternative. Check official advisories.',
      ],
    );
  }
  if (missingHours || selected.any((h) => !h.complete)) {
    return unavailable(
      'Rain, heat, UV, wind or weather-condition data is missing for this window.',
    );
  }
  double maxOf(double Function(PlanningHour) value) =>
      selected.map(value).reduce((a, b) => a > b ? a : b);
  final rain = maxOf((h) => h.rain!),
      temp = maxOf((h) => h.temperature!),
      feels = maxOf((h) => h.feelsLike!),
      uv = maxOf((h) => h.uv!),
      wind = maxOf((h) => h.wind!);
  final limits = switch (activity) {
    Activity.commute => (60.0, 35.0, 38.0, 8.0, 10.0),
    Activity.exercise => (30.0, 30.0, 32.0, 6.0, 8.0),
    _ => (40.0, 32.0, 35.0, 6.0, 10.0),
  };
  final precautions = <String>[];
  if (rain >= limits.$1 ||
      selected.any((h) => h.code! >= 51 && h.code! <= 86)) {
    precautions.add(
      activity == Activity.commute
          ? 'Carry rain protection, allow extra travel time and check local road advisories.'
          : 'Carry rain protection and consider an indoor alternative if rain develops.',
    );
  }
  if (temp >= limits.$2 || feels >= limits.$3) {
    precautions.add(
      activity == Activity.exercise
          ? 'Reduce exercise intensity, take cooling breaks and carry water.'
          : 'Carry water, seek shade and take regular cooling breaks.',
    );
  }
  if (uv >= limits.$4) {
    precautions.add(
      'Use sunscreen, protective clothing and shade; reduce sun exposure.',
    );
  }
  if (wind >= limits.$5) {
    precautions.add(
      'Avoid exposed areas and secure loose items; take care with umbrellas.',
    );
  }
  final status = precautions.isEmpty
      ? PlanStatus.favorable
      : PlanStatus.caution;
  if (precautions.isEmpty) {
    precautions.add(switch (activity) {
      Activity.commute => 'Recheck your route and local advisories before leaving; live traffic is not monitored.',
      Activity.exercise => 'Carry water, pace your activity and recheck conditions before starting.',
      Activity.work => 'Keep drinking water and shade available, and plan breaks during outdoor work.',
      Activity.walk => 'Carry water and sun protection, and recheck conditions before leaving.',
    });
  }
  return ActivityAssessment(
    start: utc,
    durationHours: durationHours,
    status: status,
    reasons: [
      'Across this window: rain chance up to ${rain.round()}%; temperature up to ${temp.round()}°C; feels like up to ${feels.round()}°C.',
      'UV up to ${uv.toStringAsFixed(1)}; wind up to ${wind.toStringAsFixed(1)} m/s. No thunderstorm code in these forecast hours.',
    ],
    precautions: precautions,
    score:
        rain / limits.$1 +
        temp / limits.$2 +
        feels / limits.$3 +
        uv / limits.$4 +
        wind / limits.$5,
  );
}

ActivityAssessment? findBetterWindow(
  WeatherInsights? forecast,
  Activity activity,
  DateTime start,
  int durationHours,
  DateTime now,
) {
  if (forecast == null ||
      !forecast.isFresh(now.toUtc()) ||
      durationHours < 1 ||
      durationHours > 3) {
    return null;
  }
  final original = assessActivity(
    forecast,
    activity,
    start,
    durationHours,
    now,
  );
  ActivityAssessment? best;
  for (final hour in forecast.hours) {
    final local = manilaTime(hour.at);
    if (local.hour < 6 || local.hour + durationHours > 18 || hour.at == start) {
      continue;
    }
    final candidate = assessActivity(
      forecast,
      activity,
      hour.at,
      durationHours,
      now,
    );
    if (candidate.status != PlanStatus.favorable ||
        candidate.score >= original.score) {
      continue;
    }
    if (best == null ||
        candidate.score < best.score ||
        (candidate.score == best.score &&
            candidate.start.isBefore(best.start))) {
      best = candidate;
    }
  }
  return best;
}
