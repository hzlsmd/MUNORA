import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

import '../services/weather_service.dart';
import '../services/weather_alerts.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/guidance_card.dart';
import '../widgets/weather_view.dart';
import '../widgets/notification_settings.dart';

class AlertsScreen extends StatelessWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  const AlertsScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
  });

  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: city,
    actions: const [NotificationSettingsButton()],
    subtitle: 'Forecast-based alerts',
    active: AppScreen.alerts,
    onNavigate: navigate,
    child: WeatherView(
      city: city,
      service: service,
      builder: (weather) {
        final alerts = weatherAlerts(weather, DateTime.now());
        final stale = alerts.any((a) => a.id == 'stale');
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
            const SizedBox(height: 20),
            SectionTitle(
              stale ? 'Update needed' : 'Current notices',
              trailing: stale ? null : '${alerts.length} forecast triggers',
            ),
            if (alerts.isEmpty)
              GlassCard(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
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
                    const Text(
                      'FORECAST CHECK',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w600,
                        color: AppColors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No forecast triggers detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No rain, thunderstorm, heat or wind rule is triggered by the available readings. This is not an all-clear; local conditions can change.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => navigate(AppScreen.forecast),
                      child: const Text('View forecast'),
                    ),
                  ],
                ),
              ),
            ...alerts.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GuidanceCard(tip: tip),
              ),
            ),
            const SizedBox(height: 16),
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
              'Rain and storm notices cover available next-six-hour samples. Heat and wind notices use current estimates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
          ],
        );
      },
    ),
  );
}
