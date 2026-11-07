import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/weather_recommendations.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_view.dart';

class AIScreen extends StatelessWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  const AIScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
  });

  IconData _icon(String id) => switch (id) {
    'storm' => Icons.thunderstorm_outlined,
    'rain' => Icons.umbrella_outlined,
    'heat' => Icons.water_drop_outlined,
    'wind' => Icons.air,
    'stale' => Icons.update,
    _ => Icons.wb_cloudy_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to Home',
                    onPressed: () => navigate(AppScreen.home),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weather Tips',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          city,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: WeatherView(
              city: city,
              service: service,
              builder: (weather) {
                final tips = weatherRecommendations(weather, DateTime.now());
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Rule-based weather guidance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'General preparedness advice, not an official warning. Check PAGASA and local advisories before making safety decisions.',
                      style: TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    ...tips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _icon(tip.id),
                                color: AppColors.skyBlueTop,
                                size: 26,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tip.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tip.advice,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      tip.reason,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (weather.isUsable(DateTime.now()))
                      Text(
                        'Based on current conditions and available forecast samples through ${weatherTime(DateTime.now().add(const Duration(hours: 6)))}.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          BottomNav(active: AppScreen.ai, onNavigate: navigate),
        ],
      ),
    );
  }
}
