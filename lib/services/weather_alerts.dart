import '../models/weather_snapshot.dart';
import 'weather_recommendations.dart';

/// App-generated notices from the same rules used by Tips. These are not
/// official warnings; no triggers does not mean an absence of weather hazards.
List<WeatherTip> weatherAlerts(WeatherSnapshot weather, DateTime now) =>
    List.unmodifiable(
      weatherRecommendations(weather, now).where(
        (tip) =>
            const {'storm', 'rain', 'heat', 'wind', 'stale'}.contains(tip.id),
      ),
    );
