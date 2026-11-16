import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/weather_recommendations.dart';
import '../services/planner_preferences.dart';
import 'weather_view.dart';
import 'atmosphere.dart';

/// Forecast interpretation is deterministic; the separate AI rain card runs ML.
class SmartHome extends StatefulWidget {
  final WeatherSnapshot weather;
  final VoidCallback onPlan;
  const SmartHome({super.key, required this.weather, required this.onPlan});
  @override
  State<SmartHome> createState() => _SmartHomeState();
}

class _SmartHomeState extends State<SmartHome> {
  late Future<ActivityRoutine?> routine;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    routine = PlannerPreferences()
        .loadRoutine(widget.weather.city)
        .catchError((Object _) => null);
  }

  @override
  void didUpdateWidget(covariant SmartHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather.city != widget.weather.city) load();
  }

  @override
  Widget build(BuildContext context) {
    final live = WeatherLiveStatus.of(context);
    final weather = widget.weather;
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
          FutureBuilder<ActivityRoutine?>(
            key: ValueKey('routine:${weather.city}'),
            future: routine,
            builder: (context, snapshot) {
              final saved = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (saved != null)
                    Text(
                      'Your ${saved.activity.name} routine: ${saved.hour.toString().padLeft(2, '0')}:00 PHT · ${saved.durationHours} hour(s). Check the complete plan in the activity planner.',
                    ),
                  if (saved != null &&
                      tips.any((t) => t.id == 'rain' || t.id == 'storm'))
                    Text(
                      saved.activity.name == 'commute'
                          ? 'For your commute: carry rain protection, allow extra travel time and check official road advisories.'
                          : 'For your ${saved.activity.name} plan: choose shelter and keep an indoor backup. Use the planner to check the exact time window.',
                    ),
                  TextButton.icon(
                    onPressed: widget.onPlan,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      saved == null
                          ? 'Personalize your activity plan'
                          : 'Check your saved activity plan',
                    ),
                  ),
                ],
              );
            },
          ),
          const Text(
            'The experimental AI rain model is shown separately below. These recommendations do not predict road flooding or replace official advisories.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
