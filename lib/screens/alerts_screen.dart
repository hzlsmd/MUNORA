import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

import '../services/weather_service.dart';
import '../services/weather_alerts.dart';
import '../services/weather_insights.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/guidance_card.dart';
import '../widgets/insight_panels.dart';
import '../widgets/weather_view.dart';
import '../widgets/notification_settings.dart';

class AlertsScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  final WeatherInsightsService? insightsService;
  const AlertsScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
    this.insightsService,
  });
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool? calm;
  @override
  void didUpdateWidget(covariant AlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) calm = null;
  }

  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: widget.city,
    subtitle: 'Forecast-based alerts',
    actions: const [NotificationSettingsButton()],
    active: AppScreen.alerts,
    onNavigate: widget.navigate,
    child: WeatherView(
      city: widget.city,
      service: widget.service,
      builder: (weather) {
        final alerts = weatherAlerts(weather, DateTime.now());
        final stale = alerts.any((a) => a.id == 'stale');
        final showCalm = !stale && (calm ?? alerts.isEmpty);
        return InsightView(
          key: ValueKey('${widget.city}:${weather.updatedAt}'),
          city: widget.city,
          service: widget.insightsService,
          builder: (raw) {
            final insight =
                !stale && raw != null && raw.isFresh(DateTime.now().toUtc())
                ? raw
                : null;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlassCard(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DesignIcon('2b112'),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'App-generated notices from weather estimates. These are not official warnings.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Active Hazards (${stale ? 0 : alerts.length})',
                        ),
                        selected: !showCalm,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => calm = false),
                      ),
                      ChoiceChip(
                        label: const Text('Calm Skies'),
                        selected: showCalm,
                        showCheckmark: false,
                        onSelected: stale
                            ? null
                            : (_) => setState(() => calm = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (showCalm)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: DesignIcon('cdc8f')),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            alerts.isEmpty
                                ? 'FORECAST CHECK'
                                : 'CALM VIEW PREVIEW',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                              color: AppColors.indigo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alerts.isEmpty ? 'No forecast triggers detected' : 'Preview only — current notices remain active',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            alerts.isEmpty
                                ? 'No rain, thunderstorm, heat or wind rule is triggered by the available readings. This is not an all-clear; local conditions can change.'
                                : 'There are ${alerts.length} app-generated notices for ${widget.city}. This view does not mean conditions are calm. Review the current hazards before making plans.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.textBody,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CalmMetrics(
                            wind: weather.current.wind,
                            insights: insight,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => setState(() => calm = false),
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('Return to Current Hazards'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    SectionTitle(
                      stale ? 'Update needed' : 'Current notices',
                      trailing: stale ? null : 'App priority',
                    ),
                    if (alerts.isEmpty)
                      const GlassCard(
                        child: Text(
                          'No forecast triggers detected. This is not an all-clear; check official advisories.',
                        ),
                      ),
                    ...alerts.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GuidanceCard(
                          tip: tip,
                          badge: tip.id == 'stale'
                              ? 'Update needed'
                              : tip.id == 'storm'
                              ? 'High priority'
                              : tip.id == 'rain'
                              ? 'Low priority'
                              : 'Moderate priority',
                          window: tip.id == 'stale'
                              ? null
                              : tip.id == 'storm' || tip.id == 'rain'
                              ? 'Current / next 6 hours'
                              : 'Current estimate',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Link(
                    uri: Uri.parse('https://www.pagasa.dost.gov.ph/'),
                    target: LinkTarget.blank,
                    builder: (context, follow) => OutlinedButton.icon(
                      onPressed: follow,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Check official PAGASA advisories'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'App priority is a preparedness cue, not an official warning level. Rain and storm notices use available next-six-hour samples.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textBody,
                    ),
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
