import 'package:material_ui/material_ui.dart';

import '../models/city_weather.dart';
import '../theme.dart';
import 'atmosphere.dart';
import 'weather_icon.dart';

class HourlyReel extends StatelessWidget {
  final List<HourlyPoint> points;
  final int selected;
  final ValueChanged<int>? onSelect;
  const HourlyReel({
    super.key,
    required this.points,
    this.selected = 0,
    this.onSelect,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(points.length, (i) {
        final point = points[i];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Semantics(
            selected: i == selected,
            child: Material(
              color: i == selected ? Colors.white : const Color(0xA6FFFFFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: i == selected
                      ? const Color(0xFFC9C5F2)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: onSelect == null ? null : () => onSelect!(i),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        point.time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 16),
                      WeatherIcon(condition: point.condition, size: 28),
                      const SizedBox(height: 16),
                      Text(
                        point.temp,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 80,
                        child: Text(
                          point.condition,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class WeatherMetrics extends StatelessWidget {
  final CityWeather weather;
  const WeatherMetrics({super.key, required this.weather});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final single = MediaQuery.textScalerOf(context).scale(14) > 21;
      final width = single
          ? constraints.maxWidth
          : (constraints.maxWidth - 12) / 2;
      final values = [
        ('HUMIDITY', weather.humidity, 'Relative humidity', '73038'),
        ('WIND', weather.wind, 'Current wind speed', 'e1569'),
        (
          'HEAT INDEX',
          weather.heatIndexC == null
              ? '—'
              : '${weather.heatIndexC!.toStringAsFixed(1)}°C',
          weather.heatIndexC == null
              ? 'Outside calculation range'
              : 'Estimated in shade',
          'f4ad0',
        ),
        ('FEELS LIKE', weather.feelsLike, 'Apparent temperature', 'f4ad0'),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: values
            .map(
              (v) => SizedBox(
                width: width,
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DesignIcon(v.$4),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              v.$1,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        v.$2,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        v.$3,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
