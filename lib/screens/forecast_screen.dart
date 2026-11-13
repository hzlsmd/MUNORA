import 'package:material_ui/material_ui.dart';

import '../models/city_weather.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/atmosphere.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_cards.dart';
import '../widgets/weather_view.dart';

class ForecastScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  const ForecastScreen({
    super.key,
    required this.navigate,
    required this.city,
    required this.service,
  });
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool dailyTab = true;
  @override
  Widget build(BuildContext context) => AtmosphereScreen(
    title: 'Forecast',
    active: AppScreen.forecast,
    onNavigate: widget.navigate,
    child: WeatherView(
      city: widget.city,
      service: widget.service,
      builder: (weather) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DesignIcon('1aa0f'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.city}, PH',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        weather.current.condition,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Hourly'),
                  icon: Icon(Icons.schedule),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Daily'),
                  icon: Icon(Icons.calendar_today_outlined),
                ),
              ],
              selected: {dailyTab},
              onSelectionChanged: (value) =>
                  setState(() => dailyTab = value.single),
            ),
            const SizedBox(height: 20),
            if (dailyTab)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('5-Day Forecast'),
                    ...weather.daily.map((day) => _DayTile(day: day)),
                  ],
                ),
              )
            else ...[
              const SectionTitle(
                'Forecast outlook',
                trailing: '1-hour intervals',
              ),
              HourlyReel(points: weather.hourly),
            ],
            const SizedBox(height: 12),
            const Text(
              'Philippine time (PHT). Daily ranges cover available hourly forecasts; the first day may be partial.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Current conditions'),
            WeatherMetrics(weather: weather.current),
          ],
        ),
      ),
    ),
  );
}

class _DayTile extends StatelessWidget {
  final DailyPoint day;
  const _DayTile({required this.day});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        WeatherIcon(condition: day.cond, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.day,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                day.cond,
                style: const TextStyle(fontSize: 11, color: AppColors.textBody),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '↑ ${day.hi}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '↓ ${day.lo}',
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
          ],
        ),
      ],
    ),
  );
}
