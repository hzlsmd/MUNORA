import '../models/weather_snapshot.dart';

class WeatherTip {
  final String id;
  final String title;
  final String advice;
  final String reason;
  const WeatherTip(this.id, this.title, this.advice, this.reason);
}

List<WeatherTip> weatherRecommendations(WeatherSnapshot weather, DateTime now) {
  if (!weather.isUsable(now)) {
    return const [
      WeatherTip(
        'stale',
        'Refresh before planning',
        'Refresh the weather to get current recommendations.',
        'Saved or outdated weather may no longer describe current conditions.',
      ),
    ];
  }
  final tips = <WeatherTip>[];
  final end = now.toUtc().add(const Duration(hours: 6));
  final upcoming = weather.readings.where(
    (r) => !r.at.isBefore(now.toUtc()) && !r.at.isAfter(end),
  );
  bool storm(String value) => value.toLowerCase().contains('thunder');
  bool rain(String value) =>
      RegExp(r'rain|drizzle|shower').hasMatch(value.toLowerCase());
  final currentStorm = storm(weather.current.condition);
  final futureStorm = upcoming.where((r) => storm(r.condition)).firstOrNull;
  if (currentStorm || futureStorm != null) {
    tips.add(
      WeatherTip(
        'storm',
        'Plan indoor activities',
        'Consider postponing exposed outdoor activities and check official weather advisories.',
        currentStorm
            ? '${weather.current.condition} in the current estimate.'
            : '${futureStorm!.condition} forecast for ${weatherTime(futureStorm.at)}.',
      ),
    );
  }
  final currentRain = rain(weather.current.condition);
  final futureRain = upcoming.where((r) => rain(r.condition)).firstOrNull;
  final probableRain = upcoming
      .where((r) => (r.rainProbability ?? 0) >= 60)
      .firstOrNull;
  if (currentRain || futureRain != null || probableRain != null) {
    tips.add(
      WeatherTip(
        'rain',
        'Bring rain protection',
        'Carry an umbrella or raincoat and allow extra travel time if roads are wet.',
        currentRain
            ? '${weather.current.condition} in the current estimate.'
            : futureRain != null
            ? '${futureRain.condition} forecast for ${weatherTime(futureRain.at)}.'
            : '${probableRain!.rainProbability!.round()}% rain probability forecast for ${weatherTime(probableRain.at)}.',
      ),
    );
  }
  final futureHeat = upcoming
      .where(
        (r) => (r.temperature ?? -100) >= 32 || (r.feelsLike ?? -120) >= 35,
      )
      .firstOrNull;
  if (weather.temperature >= 32 ||
      weather.feelsLike >= 35 ||
      futureHeat != null) {
    tips.add(
      WeatherTip(
        'heat',
        'Take breaks from the heat',
        'Carry drinking water, seek shade and take breaks during outdoor activities.',
        weather.temperature >= 32 || weather.feelsLike >= 35
            ? 'Temperature ${weather.temperature.toStringAsFixed(1)} C; feels like ${weather.feelsLike.toStringAsFixed(1)} C.'
            : 'Heat forecast for ${weatherTime(futureHeat!.at)}: ${futureHeat.temperature?.toStringAsFixed(1) ?? 'unavailable'} C; feels like ${futureHeat.feelsLike?.toStringAsFixed(1) ?? 'unavailable'} C.',
      ),
    );
  }
  final futureWind = upcoming
      .where((r) => (r.windSpeed ?? 0) >= 10)
      .firstOrNull;
  if (weather.windSpeed >= 10 || futureWind != null) {
    tips.add(
      WeatherTip(
        'wind',
        'Prepare for windy conditions',
        'Secure loose outdoor belongings and take care with umbrellas.',
        weather.windSpeed >= 10
            ? 'Current estimated wind speed is ${weather.windSpeed.toStringAsFixed(1)} m/s.'
            : 'Wind ${futureWind!.windSpeed!.toStringAsFixed(1)} m/s forecast for ${weatherTime(futureWind.at)}.',
      ),
    );
  }
  final highUv = upcoming.where((r) => (r.uvIndex ?? 0) >= 8).firstOrNull;
  if (highUv != null) {
    tips.add(
      WeatherTip(
        'uv',
        'Protect yourself from strong UV',
        'Seek shade, wear sun protection and limit prolonged midday sun exposure.',
        'UV index ${highUv.uvIndex!.toStringAsFixed(1)} forecast for ${weatherTime(highUv.at)}.',
      ),
    );
  }
  if (tips.isEmpty) {
    tips.add(
      const WeatherTip(
        'routine',
        'Keep an eye on the forecast',
        'Review the forecast before heading out and adjust plans if conditions change.',
        'No rain or thunderstorm trigger in the available next-six-hour samples; current heat and wind thresholds were not reached.',
      ),
    );
  }
  return List.unmodifiable(tips);
}
