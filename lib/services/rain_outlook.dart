import '../models/weather_snapshot.dart';
import 'activity_planner.dart';
import 'rain_model.dart';

class RainOutlook {
  final RainPrediction? prediction;
  final String? unavailableReason;
  const RainOutlook.available(RainPrediction value)
    : prediction = value,
      unavailableReason = null;
  const RainOutlook.unavailable(String reason)
    : prediction = null,
      unavailableReason = reason;
}

RainOutlook evaluateRainOutlook(
  WeatherSnapshot weather, {
  required RainModel? model,
  required bool live,
  required DateTime now,
}) {
  if (!live) {
    return const RainOutlook.unavailable(
      'Saved weather cannot generate a live AI outlook. Refresh the weather to try again.',
    );
  }
  if (weather.source != 'Open-Meteo') {
    return const RainOutlook.unavailable(
      'This weather source is not supported by the rain model.',
    );
  }
  final age = now.toUtc().difference(weather.observedAt.toUtc());
  if (age < const Duration(minutes: -5)) {
    return const RainOutlook.unavailable(
      'The weather estimate is ahead of the current time. Refresh and check your device clock.',
    );
  }
  if (age > const Duration(minutes: 30)) {
    return const RainOutlook.unavailable(
      'The weather estimate is older than 30 minutes. Refresh for a new AI outlook.',
    );
  }
  if (!weather.isUsable(now)) {
    return const RainOutlook.unavailable(
      'Weather data has expired. Refresh the weather to try again.',
    );
  }
  if (weather.humidity == null ||
      weather.pressure == null ||
      weather.weatherCode == null) {
    return const RainOutlook.unavailable(
      'A required weather input is missing. Refresh the weather to try again.',
    );
  }
  if (model == null) {
    return const RainOutlook.unavailable(
      'The rain model could not be loaded or validated.',
    );
  }
  final prediction = model.predict(
    RainInput(
      temperatureC: weather.temperature,
      humidityPercent: weather.humidity!,
      pressureHpa: weather.pressure!,
      windSpeedMs: weather.windSpeed,
      weatherCode: weather.weatherCode!,
      city: weather.city,
      observedAt: weather.observedAt,
    ),
    now: now,
  );
  if (prediction == null) {
    return const RainOutlook.unavailable(
      'Current conditions or this location fall outside the model\'s supported range.',
    );
  }
  return RainOutlook.available(prediction);
}

class RainPlanAdvice {
  final bool covered;
  final String message;
  const RainPlanAdvice(this.covered, this.message);
}

/// This is context from the full three-hour model, never a sub-hour probability.
RainPlanAdvice rainPlanAdvice(
  RainOutlook outlook,
  Activity activity,
  DateTime start,
  int durationHours,
  DateTime now,
) {
  final prediction = outlook.prediction;
  if (prediction == null) {
    return RainPlanAdvice(false, outlook.unavailableReason!);
  }
  final age = now.toUtc().difference(prediction.estimatedAt);
  if (age > const Duration(minutes: 30) || age < const Duration(minutes: -5)) {
    return const RainPlanAdvice(
      false,
      'The AI outlook has expired. Refresh the weather before checking this plan.',
    );
  }
  if (durationHours < 1 || durationHours > 3 || start.isBefore(now)) {
    return const RainPlanAdvice(
      false,
      'Choose a future plan lasting 1–3 hours.',
    );
  }
  final end = start.add(Duration(hours: durationHours));
  if (start.isBefore(prediction.estimatedAt) ||
      start.isAfter(prediction.windowEnd) ||
      end.isAfter(prediction.windowEnd)) {
    return const RainPlanAdvice(
      false,
      'The AI outlook does not cover your entire plan. Use the hourly forecast and recheck closer to your start time.',
    );
  }
  if (prediction.probability < .6) {
    return const RainPlanAdvice(
      true,
      'Keep checking hourly forecasts and current conditions before leaving. Existing rain, storm, heat and wind precautions still apply.',
    );
  }
  final advice = switch (activity) {
    Activity.commute => 'Carry rain protection, allow extra travel time, and check local road advisories.',
    Activity.walk => 'Carry rain protection and choose a route with shelter.',
    Activity.exercise =>
      'Plan an indoor alternative or a sheltered route for your exercise.',
    Activity.work => 'Keep rain protection nearby and plan access to shelter during outdoor work.',
  };
  return RainPlanAdvice(true, advice);
}
