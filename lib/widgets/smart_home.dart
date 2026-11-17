import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/weather_recommendations.dart';
import 'weather_view.dart';
import 'atmosphere.dart';

/// Forecast interpretation is deterministic; the AI rain outlook stays on Tips.
class SmartHome extends StatelessWidget {
  final WeatherSnapshot weather;
  const SmartHome({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final live = WeatherLiveStatus.of(context);
    final tips = weatherRecommendations(
      weather,
      DateTime.now().toUtc(),
      saved: !live,
    );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Recommendations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            '${weather.city} · Rule-based forecast interpretation',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Weather estimate ${weatherTime(weather.observedAt)}',
            style: const TextStyle(fontSize: 11),
          ),
          if (!live)
            const Text(
              'Saved information — reconnect and refresh before making plans.',
            ),
          for (final tip in tips.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(tip.advice),
                  Text(
                    'Why: ${tip.reason}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const Text(
            'These recommendations do not predict road flooding or replace official advisories.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
