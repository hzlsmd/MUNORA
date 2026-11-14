import 'package:material_ui/material_ui.dart';

import '../services/weather_recommendations.dart';
import '../services/weather_service.dart';
import '../services/weather_insights.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/ai_rain_outlook.dart';
import '../widgets/preparedness_recommendations.dart';
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
        final stale = !weather.isUsable(DateTime.now());
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
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    'LIVE MICROCLIMATE',
                    trailing: 'Metro Manila Basin',
                  ),
                  AIRainOutlook(
                    weather: weather,
                    onPlanActivity: _openPlanner,
                    showRecommendation: false,
                  ),
                  const SizedBox(height: 16),
                  PreparednessRecommendations(
                    weather: weather,
                    filter: filter,
                    onFilterChanged: (value) => setState(() => filter = value),
                  ),
                  const SizedBox(height: 16),
                  ModelAgreementPanel(insights: insight),
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
                  GuidanceCard(
                    key: ValueKey('${widget.city}:uv'),
                    tip: WeatherTip(
                      'uv',
                      'Check the UV Index',
                      insight?.uvIndex == null
                          ? 'UV data is unavailable. Check a current UV forecast before prolonged outdoor exposure.'
                          : 'Current-hour UV index ${insight!.uvIndex!.toStringAsFixed(1)} (${uvCategory(insight.uvIndex)}). Use sun protection when outdoors.',
                      'Use sunscreen, clothing and shade for sun protection. This is an Open-Meteo hourly forecast, not a personal exposure measurement.',
                    ),
                    badge: insight?.uvIndex == null
                        ? 'General guidance'
                        : 'Hourly forecast',
                    detailsLabel: 'View UV guidance details',
                  ),
                  const SizedBox(height: 16),
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
