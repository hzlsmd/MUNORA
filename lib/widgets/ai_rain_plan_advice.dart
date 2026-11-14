import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/activity_planner.dart';
import '../services/rain_model.dart';
import '../services/rain_outlook.dart';
import '../theme.dart';
import 'rain_outlook_builder.dart';

class AIRainPlanAdvice extends StatelessWidget {
  final WeatherSnapshot weather;
  final Activity activity;
  final DateTime start;
  final int durationHours;
  final RainModelLoader? loader;
  const AIRainPlanAdvice({
    super.key,
    required this.weather,
    required this.activity,
    required this.start,
    required this.durationHours,
    this.loader,
  });

  @override
  Widget build(BuildContext context) => RainOutlookBuilder(
    weather: weather,
    loader: loader,
    builder: (outlook, loading, _) {
      final advice = rainPlanAdvice(
        outlook,
        activity,
        start,
        durationHours,
        DateTime.now().toUtc(),
      );
      final prediction = outlook.prediction;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x55EBD6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI rain context · Experimental',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(height: 6),
            if (loading)
              const Text('Loading rain model…', style: TextStyle(fontSize: 12))
            else if (!advice.covered)
              Text(
                'Unavailable for this plan. ${advice.message}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              )
            else ...[
              Text(
                '${formatRainProbability(prediction!.probability)} chance of rain · full 3-hour outlook',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${weather.city} · ${weatherTime(prediction.estimatedAt)} – ${weatherTime(prediction.windowEnd)}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              const Text(
                'Your plan falls within this outlook. Probability covers the complete three-hour window.',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                advice.message,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 6),
              const Text(
                'The model estimates rain probability; preparedness rules provide this activity advice. Keep following hourly forecast warnings and official advisories.',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
            ],
          ],
        ),
      );
    },
  );
}
