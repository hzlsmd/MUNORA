import '../models/weather_snapshot.dart';
import 'weather_recommendations.dart';
import 'notification_preferences.dart';

String notificationKey(String city, String trigger) => '$city:$trigger';

List<WeatherTip> notificationTips(
  WeatherSnapshot weather,
  DateTime now,
  Map<String, DateTime> lastShown,
) => selectNotificationTips(weather, now, {
  for (final entry in lastShown.entries)
    if (entry.key.startsWith('${weather.city}:'))
      entry.key.substring(weather.city.length + 1): NotificationRecord(
        entry.value,
        '',
      ),
});

class NotificationRecord {
  final DateTime sentAt;
  final String fingerprint;
  const NotificationRecord(this.sentAt, this.fingerprint);
}

/// Coarse measured changes matter; small rounding jitter and a new fetch time do not.
String notificationFingerprint(
  WeatherSnapshot weather,
  WeatherTip tip,
  DateTime now,
) {
  final local = manilaTime(now);
  final upcoming = weather.readings
      .where(
        (r) =>
            !r.at.isBefore(now) &&
            !r.at.isAfter(now.add(const Duration(hours: 6))),
      )
      .toList();
  double peak(double current, double? Function(ForecastReading) value) =>
      upcoming.fold(
        current,
        (max, r) => (value(r) ?? max) > max ? value(r)! : max,
      );
  final conditions =
      upcoming.map((r) => r.condition.toLowerCase()).toSet().toList()..sort();
  final detail = switch (tip.id) {
    'heat' =>
      '${peak(weather.temperature, (r) => r.temperature) ~/ 3}:${peak(weather.feelsLike, (r) => r.feelsLike) ~/ 3}',
    'wind' => '${peak(weather.windSpeed, (r) => r.windSpeed) ~/ 3}',
    'uv' => '${peak(0, (r) => r.uvIndex) ~/ 3}',
    'rain' =>
      '${weather.current.condition.toLowerCase()}:${conditions.join(',')}:${peak(0, (r) => r.rainProbability) ~/ 20}',
    _ => '${weather.current.condition.toLowerCase()}:${conditions.join(',')}',
  };
  return '${weather.city}:${tip.id}:${local.year}-${local.month}-${local.day}:$detail';
}

List<WeatherTip> selectNotificationTips(
  WeatherSnapshot weather,
  DateTime now,
  Map<String, NotificationRecord> history, {
  NotificationPreferences preferences = const NotificationPreferences(),
}) {
  if (!weather.isUsable(now) || preferences.isQuiet(now)) return [];
  var tips = weatherRecommendations(weather, now);
  if (tips.length == 1 &&
      tips.first.id == 'routine' &&
      const {
        'clear sky',
        'mainly clear',
      }.contains(weather.current.condition.toLowerCase()) &&
      weather.readings
          .where(
            (r) =>
                !r.at.isBefore(now) &&
                r.at.isBefore(now.add(const Duration(hours: 6))),
          )
          .isNotEmpty &&
      manilaTime(now).hour >= 6 &&
      manilaTime(now).hour < 18) {
    tips = const [
      WeatherTip(
        'clear',
        'Plan time outdoors',
        'The current estimate looks clear. Check the hourly forecast before outdoor activities.',
        'Clear current conditions with no rain, storm, heat or wind rule triggered in available data. This is not an all-clear.',
      ),
    ];
  }
  return tips.where((tip) {
    if (!preferences.categories.contains(tip.id)) return false;
    final previous = history[tip.id];
    if (previous == null) return true;
    final age = now.difference(previous.sentAt);
    if (age < const Duration(hours: 1)) return false;
    return previous.fingerprint != notificationFingerprint(weather, tip, now) ||
        age >= const Duration(hours: 12);
  }).toList();
}
