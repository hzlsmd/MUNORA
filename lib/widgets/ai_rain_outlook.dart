import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/rain_model.dart';
import '../theme.dart';
import 'weather_view.dart';
import 'atmosphere.dart';
import 'rain_outlook_builder.dart';

class AIRainOutlook extends StatelessWidget {
  final WeatherSnapshot weather;
  final RainModelLoader? loader;
  final VoidCallback? onPlanActivity;
  const AIRainOutlook({
    super.key,
    required this.weather,
    this.loader,
    this.onPlanActivity,
  });
  @override
  Widget build(BuildContext context) {
    final refresh = WeatherLiveStatus.refreshOf(context);
    return RainOutlookBuilder(
      weather: weather,
      loader: loader,
      builder: (outlook, loading, modelVersion) {
        final prediction = outlook.prediction;
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI rain outlook',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI prediction · Experimental',
                style: TextStyle(fontSize: 12, color: AppColors.indigo),
              ),
              const SizedBox(height: 6),
              Text(
                '${weather.city} · 3-hour rain outlook',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Weather estimate ${weatherTime(weather.observedAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textBody),
              ),
              const SizedBox(height: 10),
              if (prediction == null)
                Text(
                  loading
                      ? 'Loading rain model…'
                      : 'Unavailable. ${outlook.unavailableReason}',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                )
              else ...[
                Text(
                  '${formatRainProbability(prediction.probability)} probability of rain',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'From ${weatherTime(prediction.estimatedAt)}\nThrough ${weatherTime(prediction.windowEnd)} (3 hours)',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Rain preparedness recommendation',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  prediction.probability >= .6
                      ? 'Carry rain protection and consider a sheltered backup plan.'
                      : 'Keep checking the hourly forecast and current conditions before heading out.',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                const Text(
                  'Preparedness rules applied to this AI prediction.',
                  style: TextStyle(fontSize: 11, color: AppColors.textBody),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chance of at least 0.1 mm total rain. Probability is not accuracy. Keep checking current conditions and official advisories.',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
              ],
              if (!loading &&
                  prediction == null &&
                  modelVersion != null &&
                  refresh != null)
                TextButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh weather'),
                ),
              if (onPlanActivity != null)
                TextButton.icon(
                  onPressed: onPlanActivity,
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Plan an activity'),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Model details',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  Text(
                    'Model: ${modelVersion ?? 'unavailable'}. Trained on 2021–2023 Open-Meteo ERA5 gridded reanalysis; evaluated on 2024–2025. Nearby cities may share a grid. Live predictive performance still needs prospective validation. Data: Open-Meteo (CC BY 4.0), ERA5 / Copernicus Climate Change Service.',
                    style: const TextStyle(fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
