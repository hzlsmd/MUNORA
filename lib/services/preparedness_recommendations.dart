import '../models/weather_snapshot.dart';
import 'heat_index.dart';
import 'rain_model.dart';
import 'rain_outlook.dart';
import 'weather_recommendations.dart';

enum PreparednessSource { aiRain, forecast, heatIndex, general }

class PreparednessRecommendation {
  final String id, title, advice, reason;
  final List<PreparednessSource> sources;
  final DateTime? from, until, forecastFrom, forecastUntil;
  const PreparednessRecommendation({
    required this.id,
    required this.title,
    required this.advice,
    required this.reason,
    required this.sources,
    this.from,
    this.until,
    this.forecastFrom,
    this.forecastUntil,
  });
}

class PreparednessGuidance {
  final List<PreparednessRecommendation> contextual;
  final List<PreparednessRecommendation> general;
  final String? unavailableReason;
  const PreparednessGuidance(
    this.contextual,
    this.general,
    this.unavailableReason,
  );
}

const _general = [
  PreparednessRecommendation(
    id: 'flood_preparedness',
    title: 'Avoid floodwater on your route',
    advice: 'Avoid flood-prone roads when flooding is reported. Never walk or drive through floodwater; check official local road advisories before travelling.',
    reason: 'General flood preparedness. MUNORA does not receive live road-flooding reports or predict which roads are safe.',
    sources: [PreparednessSource.general],
  ),
  PreparednessRecommendation(
    id: 'emergency_kit',
    title: 'Prepare an emergency kit',
    advice: 'Keep drinking water, ready-to-eat food, a flashlight, a charged power bank, first-aid supplies and copies of important documents ready. Follow local authorities during severe weather.',
    reason: 'General severe-weather preparedness, not an active flood or typhoon warning.',
    sources: [PreparednessSource.general],
  ),
];

/// Supplementary preparation only. Never changes alert triggers or planner risk.
PreparednessGuidance preparednessRecommendations(
  WeatherSnapshot weather, {
  required RainOutlook outlook,
  required bool live,
  required DateTime now,
}) {
  now = now.toUtc();
  if (!live || !weather.isUsable(now)) {
    return const PreparednessGuidance(
      [],
      _general,
      'Refresh weather for current recommendations. Saved or expired weather is for reference only.',
    );
  }
  final tips = weatherRecommendations(weather, now);
  WeatherTip? tip(String id) => tips.where((t) => t.id == id).firstOrNull;
  final result = <PreparednessRecommendation>[];
  final windowEnd = now.add(const Duration(hours: 6));
  final forecastEnd = weather.forecastUntil.isBefore(windowEnd)
      ? weather.forecastUntil
      : windowEnd;
  final storm = tip('storm');
  if (storm != null) {
    result.add(
      PreparednessRecommendation(
        id: 'storm',
        title: 'Plan indoor shelter',
        advice: 'Stay indoors during thunderstorms and postpone exposed outdoor activities. Avoid open fields, water and isolated trees; check official advisories.',
        reason: storm.reason,
        sources: const [PreparednessSource.forecast],
        from: now,
        until: forecastEnd,
      ),
    );
  }
  final prediction = outlook.prediction;
  final age = prediction == null
      ? null
      : now.difference(prediction.estimatedAt);
  final aiRain =
      prediction != null &&
      weather.source == 'Open-Meteo' &&
      prediction.estimatedAt.isAtSameMomentAs(weather.observedAt) &&
      age! >= const Duration(minutes: -5) &&
      age <= const Duration(minutes: 30) &&
      prediction.probability.isFinite &&
      prediction.probability >= .6 &&
      prediction.probability <= 1;
  final rain = tip('rain');
  if (aiRain || rain != null) {
    result.add(
      PreparednessRecommendation(
        id: 'rain',
        title: 'Bring an umbrella or raincoat',
        advice: 'Carry an umbrella or raincoat, allow extra travel time and keep a sheltered backup plan. During thunderstorms, seek indoor shelter rather than relying on an umbrella.',
        reason: [
          if (aiRain)
            'The experimental AI estimates ${formatRainProbability(prediction.probability)} probability of at least 0.1 mm total rain in its three-hour window.',
          if (rain != null) rain.reason,
        ].join(' '),
        sources: List.unmodifiable([
          if (aiRain) PreparednessSource.aiRain,
          if (rain != null) PreparednessSource.forecast,
        ]),
        from: aiRain ? prediction.estimatedAt : now,
        until: aiRain ? prediction.windowEnd : forecastEnd,
        forecastFrom: aiRain && rain != null ? now : null,
        forecastUntil: aiRain && rain != null ? forecastEnd : null,
      ),
    );
  }
  final heat = tip('heat');
  final index = weather.humidity == null
      ? null
      : heatIndexCelsius(weather.temperature, weather.humidity!);
  final hotIndex = index != null && index >= 33;
  if (heat != null || hotIndex) {
    result.add(
      PreparednessRecommendation(
        id: 'heat',
        title: 'Wear light clothing and drink water',
        advice: 'Wear light clothing, carry drinking water, seek shade and take breaks from outdoor activity. Follow any medical advice about fluid intake.',
        reason: hotIndex
            ? 'Calculated heat index ${index.toStringAsFixed(1)}°C from the current temperature and humidity estimate. This shade/light-wind estimate is not an official heat warning.'
            : heat!.reason,
        sources: hotIndex
            ? const [PreparednessSource.heatIndex]
            : const [PreparednessSource.forecast],
        from: weather.observedAt,
      ),
    );
  }
  final wind = tip('wind');
  if (wind != null) {
    result.add(
      PreparednessRecommendation(
        id: 'wind',
        title: 'Secure loose outdoor belongings',
        advice: 'Secure loose items and take care around trees, signs and umbrellas in strong winds. Recheck conditions before outdoor travel.',
        reason: wind.reason,
        sources: const [PreparednessSource.forecast],
        from: weather.observedAt,
      ),
    );
  }
  return PreparednessGuidance(List.unmodifiable(result), _general, null);
}
