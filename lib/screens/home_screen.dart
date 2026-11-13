import 'package:material_ui/material_ui.dart';

import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';
import '../services/weather_service.dart';
import '../services/weather_alerts.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/ai_rain_outlook.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_cards.dart';
import '../widgets/weather_view.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final ValueChanged<String> onCityChange;
  final String city;
  final WeatherService service;
  const HomeScreen({
    super.key,
    required this.navigate,
    required this.onCityChange,
    required this.city,
    required this.service,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int activeHour = 0;
  Future<void> pickCity() async {
    final city = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF2EEFC),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select location',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView(
                  children: supportedCities
                      .map(
                        (city) => ListTile(
                          title: Text(city),
                          selected: city == widget.city,
                          trailing: city == widget.city
                              ? const Icon(Icons.check_circle_outline)
                              : null,
                          onTap: () => Navigator.pop(context, city),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (city != null && mounted) {
      setState(() => activeHour = 0);
      widget.onCityChange(city);
    }
  }

  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: 'Home',
    actions: [
      IconButton(
        onPressed: pickCity,
        tooltip: 'Change location',
        icon: const Icon(Icons.location_on_outlined),
      ),
    ],
    active: AppScreen.home,
    onNavigate: widget.navigate,
    child: WeatherView(
      city: widget.city,
      service: widget.service,
      builder: (weather) {
        final notices = weatherAlerts(weather, DateTime.now());
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SkyHero(weather: weather, onPickCity: pickCity),
              const SizedBox(height: 16),
              Material(
                color: const Color(0x99FFFFFF),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => widget.navigate(AppScreen.alerts),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE3C6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: DesignIcon('880bc')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notices.isEmpty
                                    ? 'Check forecast notices'
                                    : notices.first.id == 'stale'
                                    ? 'Refresh before planning'
                                    : '${notices.length} weather notice${notices.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'App-generated • View details',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.indigo,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle(
                      'Forecast outlook',
                      trailing: '1-hour intervals',
                    ),
                    HourlyReel(
                      points: weather.hourly.take(8).toList(),
                      selected: activeHour,
                      onSelect: (i) => setState(() => activeHour = i),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (weather.daily.length > 1) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      WeatherIcon(condition: weather.daily[1].cond, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weather.daily[1].day,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              weather.daily[1].cond,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Text('↑ ${weather.daily[1].hi}'),
                          Text('↓ ${weather.daily[1].lo}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AIRainOutlook(weather: weather),
              const SizedBox(height: 16),
              WeatherMetrics(weather: weather.current),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => widget.navigate(AppScreen.forecast),
                child: const Text('View 5-Day Forecast'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SkyHero extends StatelessWidget {
  final WeatherSnapshot weather;
  final VoidCallback onPickCity;
  const _SkyHero({required this.weather, required this.onPickCity});
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      image: const DecorationImage(
        image: AssetImage('assets/design/e0f7e.png'),
        fit: BoxFit.cover,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x226E64A0),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFFFFF), Color(0x00FFFFFF), Color(0x99FFFFFF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            onPressed: onPickCity,
            icon: const DesignIcon('50a38'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xB3FFFFFF),
              foregroundColor: AppColors.textDark,
            ),
            label: Text(weather.city),
          ),
          const SizedBox(height: 44),
          Text(
            '${weather.current.temp}°C',
            style: const TextStyle(
              fontFamily: 'Abyssinica',
              fontSize: 64,
              height: 1.2,
              color: AppColors.skyBlueTop,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xB3FFFFFF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              weather.current.condition,
              style: const TextStyle(fontSize: 12, color: AppColors.textBody),
            ),
          ),
          const SizedBox(height: 44),
          GlassCard(
            padding: const EdgeInsets.all(12),
            color: const Color(0xCCFFFFFF),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (weather.daily.isNotEmpty)
                  Text(
                    'Range  ↑ ${weather.daily.first.hi}  ↓ ${weather.daily.first.lo}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  'Feels ${weather.current.feelsLike}',
                  style: const TextStyle(fontSize: 12, color: AppColors.indigo),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
