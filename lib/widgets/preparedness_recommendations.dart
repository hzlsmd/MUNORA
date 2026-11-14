import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/preparedness_recommendations.dart';
import '../services/rain_model.dart';
import '../theme.dart';
import 'atmosphere.dart';
import 'rain_outlook_builder.dart';
import 'weather_view.dart';

class PreparednessRecommendations extends StatelessWidget {
  final WeatherSnapshot weather;
  final RainModelLoader? loader;
  final DateTime Function()? now;
  const PreparednessRecommendations({
    super.key,
    required this.weather,
    this.loader,
    this.now,
  });

  @override
  Widget build(BuildContext context) => RainOutlookBuilder(
    weather: weather,
    loader: loader,
    builder: (outlook, loading, _) {
      final guidance = preparednessRecommendations(
        weather,
        outlook: outlook,
        live: WeatherLiveStatus.of(context),
        now: (now?.call() ?? DateTime.now()).toUtc(),
      );
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'For ${weather.city}',
              style: const TextStyle(fontSize: 12, color: AppColors.indigo),
            ),
            const SizedBox(height: 8),
            const Text(
              'Practical steps based on available AI rain predictions and weather estimates. Each suggestion identifies its source.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            if (guidance.unavailableReason != null) ...[
              const SizedBox(height: 12),
              Text(
                guidance.unavailableReason!,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ] else ...[
              if (loading || outlook.prediction == null) ...[
                const SizedBox(height: 8),
                Text(
                  loading
                      ? 'AI rain advice is loading; forecast guidance remains available.'
                      : 'AI rain advice is unavailable; available forecast guidance is shown.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
              ],
              if (guidance.contextual.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Keep checking current conditions and official advisories before heading out. No recommendation is an all-clear.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ],
            for (final recommendation in guidance.contextual)
              _Recommendation(recommendation: recommendation),
            const SizedBox(height: 8),
            ExpansionTile(
              key: ValueKey('preparedness:${weather.city}'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Flood and emergency preparedness',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'General guidance',
                style: TextStyle(fontSize: 11),
              ),
              children: [
                const Text(
                  'No live flood or typhoon warning feed is connected. These precautions do not indicate an active local warning; check PAGASA and local authorities.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
                for (final recommendation in guidance.general)
                  _Recommendation(recommendation: recommendation),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _Recommendation extends StatelessWidget {
  final PreparednessRecommendation recommendation;
  const _Recommendation({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final item = recommendation;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final source in item.sources)
            Text(
              switch (source) {
                PreparednessSource.aiRain =>
                  'AI rain prediction · Experimental',
                PreparednessSource.forecast => 'Weather forecast',
                PreparednessSource.heatIndex => 'Calculated heat index',
                PreparednessSource.general => 'General preparedness',
              },
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.indigo,
              ),
            ),
          const SizedBox(height: 6),
          Text(item.advice, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 6),
          Text(
            item.reason,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          if (item.from != null) ...[
            const SizedBox(height: 4),
            Text(
              item.until == null
                  ? 'Current estimate ${weatherTime(item.from!)}'
                  : '${item.sources.contains(PreparednessSource.aiRain) ? 'AI window' : 'Forecast window'}: From ${weatherTime(item.from!)}\nThrough ${weatherTime(item.until!)}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
          ],
          if (item.forecastFrom != null && item.forecastUntil != null) ...[
            const SizedBox(height: 4),
            Text(
              'Forecast window: From ${weatherTime(item.forecastFrom!)}\nThrough ${weatherTime(item.forecastUntil!)}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
