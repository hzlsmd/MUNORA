import 'package:material_ui/material_ui.dart';

import '../services/weather_recommendations.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/guidance_card.dart';
import '../widgets/weather_view.dart';
import '../widgets/notification_settings.dart';

class AIScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  const AIScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
  });
  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  String filter = 'All';
  @override
  void didUpdateWidget(covariant AIScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) filter = 'All';
  }

  bool matches(WeatherTip tip) =>
      tip.id == 'stale' ||
      switch (filter) {
        'Rain' => tip.id == 'rain' || tip.id == 'storm',
        'Heat' => tip.id == 'heat',
        'Outdoor' => const {
          'heat',
          'wind',
          'storm',
          'routine',
        }.contains(tip.id),
        'Travel' => const {'rain', 'wind', 'storm'}.contains(tip.id),
        _ => true,
      };
  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: widget.city,
    actions: const [NotificationSettingsButton()],
    subtitle: 'Daily lifestyle tips',
    active: AppScreen.ai,
    onNavigate: widget.navigate,
    child: WeatherView(
      city: widget.city,
      service: widget.service,
      builder: (weather) {
        final tips = weatherRecommendations(
          weather,
          DateTime.now(),
        ).where(matches).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rule-based weather guidance',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: .3,
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practical suggestions for your day, based on the available weather. Check official advisories before making safety decisions.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['All', 'Rain', 'Heat', 'Outdoor', 'Travel']
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category),
                        selected: filter == category,
                        showCheckmark: false,
                        selectedColor: AppColors.indigo,
                        backgroundColor: const Color(0x99FFFFFF),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: filter == category
                              ? Colors.white
                              : AppColors.textBody,
                        ),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        onSelected: (_) => setState(() => filter = category),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              if (tips.isEmpty)
                const GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No tips in this category right now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try All to see the other suggestions for your city.',
                        style: TextStyle(color: AppColors.textBody),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < tips.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GuidanceCard(
                    key: ValueKey('${widget.city}:${tips[i].id}'),
                    tip: tips[i],
                    featured: i == 0 && tips[i].id != 'stale',
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
