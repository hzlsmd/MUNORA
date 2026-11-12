import '../models/weather_snapshot.dart';
import 'weather_recommendations.dart';

String notificationKey(String city, String trigger) => '$city:$trigger';

List<WeatherTip> notificationTips(
  WeatherSnapshot weather,
  DateTime now,
  Map<String, DateTime> lastShown,
) => weatherRecommendations(weather, now).where((tip) {
  if (!const {'storm', 'rain', 'heat', 'wind'}.contains(tip.id)) return false;
  final previous = lastShown[notificationKey(weather.city, tip.id)];
  return previous == null ||
      now.difference(previous) >= const Duration(hours: 1);
}).toList();
