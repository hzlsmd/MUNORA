import 'package:material_ui/material_ui.dart';

import '../services/weather_recommendations.dart';
import '../services/weather_service.dart';
import '../services/weather_insights.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/ai_rain_outlook.dart';
import '../widgets/activity_planner_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/guidance_card.dart';
import '../widgets/insight_panels.dart';
import '../widgets/weather_view.dart';
import '../widgets/notification_settings.dart';

class AIScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  final WeatherInsightsService? insightsService;
  final bool openPlannerOnLoad;
  const AIScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
    this.insightsService,
    this.openPlannerOnLoad = false,
  });
  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  String filter = 'All';
  var _plannerKey = GlobalKey<ActivityPlannerCardState>();
  late bool _pendingPlanner;

  @override
  void initState() {
    super.initState();
    _pendingPlanner = widget.openPlannerOnLoad;
  }

  void _openPlanner() => _plannerKey.currentState?.open();

  @override
  void didUpdateWidget(covariant AIScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) {
      filter = 'All';
      _plannerKey = GlobalKey<ActivityPlannerCardState>();
      _pendingPlanner = widget.openPlannerOnLoad;
    } else if (widget.openPlannerOnLoad && !oldWidget.openPlannerOnLoad) {
      _pendingPlanner = true;
    }
  }

  bool matches(String id) => switch (filter) {
    'Rain' => {'rain', 'storm', 'storm_safety'}.contains(id),
    'Heat' => {'heat', 'hydration', 'uv'}.contains(id),
    'Outdoor' => {
      'heat',
      'wind',
      'storm',
      'routine',
      'outdoor',
      'uv',
    }.contains(id),
    'Travel' => {'rain', 'wind', 'storm', 'travel'}.contains(id),
    _ => true,
  };
  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: widget.city,
    subtitle: 'Daily lifestyle tips',
    actions: const [NotificationSettingsButton()],
    active: AppScreen.ai,
    onNavigate: widget.navigate,
    child: WeatherView(
      city: widget.city,
      service: widget.service,
      builder: (weather) {
        final recommendations = weatherRecommendations(weather, DateTime.now());
        final stale = recommendations.first.id == 'stale';
        return InsightView(
          key: ValueKey('${widget.city}:${weather.updatedAt}'),
          city: widget.city,
          service: widget.insightsService,
          builder: (raw) {
            if (_pendingPlanner) {
              _pendingPlanner = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openPlanner();
              });
            }
            final insight =
                !stale && raw != null && raw.isFresh(DateTime.now().toUtc())
                ? raw
                : null;
            final catalog = [
              const WeatherTip(
                'hydration',
                'Stay Hydrated',
                'Carry drinking water and take breaks in the shade during warm periods.',
                'General heat preparedness. Drink regularly and follow any medical advice about fluid intake.',
              ),
              WeatherTip(
                'uv',
                'Check the UV Index',
                insight?.uvIndex == null
                    ? 'UV data is unavailable. Check a current UV forecast before prolonged outdoor exposure.'
                    : 'Current-hour UV index ${insight!.uvIndex!.toStringAsFixed(1)} (${uvCategory(insight.uvIndex)}). Use sun protection when outdoors.',
                'Use sunscreen, clothing and shade for sun protection. The displayed UV value, when available, is an Open-Meteo hourly forecast, not a personal exposure measurement.',
              ),
              const WeatherTip(
                'outdoor',
                'Plan Outdoor Activities',
                'Review the suggested outdoor window and recheck the forecast before leaving.',
                'General planning guidance. Avoid exposed activities during thunderstorms and adjust plans as conditions change.',
              ),
              const WeatherTip(
                'travel',
                'Travel Prepared',
                'Check your route and local road advisories. Carry rain protection and allow extra travel time when needed.',
                'General travel preparedness. This app does not receive live traffic or road-flooding reports; check official local sources.',
              ),
              const WeatherTip(
                'storm_safety',
                'Thunderstorm Safety',
                'When thunder roars, head indoors. Avoid open fields, water and isolated tall trees.',
                'General storm safety. Use a substantial building or enclosed vehicle for shelter. Wait at least 30 minutes after the last thunder before resuming exposed outdoor activity.',
              ),
            ].where((tip) => matches(tip.id));
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    'LIVE MICROCLIMATE',
                    trailing: 'Metro Manila Basin',
                  ),
                  AIRainOutlook(weather: weather, onPlanActivity: _openPlanner),
                  const SizedBox(height: 16),
                  ModelAgreementPanel(insights: insight),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  const Text(
                    'Forecast-based recommendation',
                    style: TextStyle(fontSize: 12, color: AppColors.indigo),
                  ),
                  const SizedBox(height: 8),
                  GuidanceCard(
                    key: ValueKey(
                      '${widget.city}:featured:${recommendations.first.id}',
                    ),
                    tip: recommendations.first,
                    featured: !stale,
                    window: stale ? null : 'Current / next 6 hours',
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('Forecast-based activity planner'),
                  const Text(
                    'Plan for rain, heat, UV, wind and thunderstorms using hourly forecasts. Add experimental AI rain advice for plans within the current three-hour outlook.',
                    style: TextStyle(fontSize: 12, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 12),
                  ActivityPlannerCard(
                    key: _plannerKey,
                    city: widget.city,
                    insights: insight,
                    weather: weather,
                  ),
                  const SizedBox(height: 16),
                  OutdoorPanel(insights: insight),
                  const SizedBox(height: 16),
                  const Text(
                    'Forecast-based weather guidance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Forecast-based suggestions and general preparedness tips. Check official advisories before making safety decisions.',
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
                          (c) => ChoiceChip(
                            label: Text(c),
                            selected: filter == c,
                            showCheckmark: false,
                            selectedColor: AppColors.indigo,
                            backgroundColor: const Color(0x99FFFFFF),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: filter == c
                                  ? Colors.white
                                  : AppColors.textBody,
                            ),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            onSelected: (_) => setState(() => filter = c),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  for (final tip
                      in recommendations
                          .skip(1)
                          .where((tip) => matches(tip.id)))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GuidanceCard(
                        key: ValueKey('${widget.city}:${tip.id}'),
                        tip: tip,
                        badge: 'Weather-triggered',
                      ),
                    ),
                  for (final tip in catalog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GuidanceCard(
                        key: ValueKey('guide:${tip.id}'),
                        tip: tip,
                        badge: tip.id == 'uv' && insight?.uvIndex != null
                            ? uvCategory(insight!.uvIndex)
                            : 'General guidance',
                        detailsLabel: 'View guidance details',
                      ),
                    ),
                  GuidanceFeedback(
                    key: ValueKey('feedback:${widget.city}'),
                    city: widget.city,
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
