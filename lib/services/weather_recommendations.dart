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
  final utc = now.toUtc();
  final currentHour = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
  final upcoming = weather.readings.where(
    (r) => !r.at.isBefore(currentHour) && !r.at.isAfter(end),
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
  if (currentRain || futureRain != null) {
    tips.add(
      WeatherTip(
        'rain',
        'Bring rain protection',
        'Carry an umbrella or raincoat and allow extra travel time if roads are wet.',
        currentRain
            ? '${weather.current.condition} in the current estimate.'
            : '${futureRain!.condition} forecast for ${weatherTime(futureRain.at)}.',
      ),
    );
  }
  if (weather.temperature >= 32 || weather.feelsLike >= 35) {
    tips.add(
      WeatherTip(
        'heat',
        'Take breaks from the heat',
        'Carry drinking water, seek shade and take breaks during outdoor activities.',
        'Temperature ${weather.temperature.toStringAsFixed(1)} C; feels like ${weather.feelsLike.toStringAsFixed(1)} C.',
      ),
    );
  }
  if (weather.windSpeed >= 10) {
    tips.add(
      WeatherTip(
        'wind',
        'Prepare for windy conditions',
        'Secure loose outdoor belongings and take care with umbrellas.',
        'Current estimated wind speed is ${weather.windSpeed.toStringAsFixed(1)} m/s.',
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
