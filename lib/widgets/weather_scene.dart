import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import 'weather_view.dart';

enum SkyState { clear, partlyCloudy, cloudy, rain, storm, fog, snow, unknown }

SkyState skyState(int? code) => switch (code) {
  0 || 1 => SkyState.clear,
  2 => SkyState.partlyCloudy,
  3 => SkyState.cloudy,
  45 || 48 => SkyState.fog,
  51 ||
  53 ||
  55 ||
  56 ||
  57 ||
  61 ||
  63 ||
  65 ||
  66 ||
  67 ||
  80 ||
  81 ||
  82 => SkyState.rain,
  71 || 73 || 75 || 77 || 85 || 86 => SkyState.snow,
  95 || 96 || 99 => SkyState.storm,
  _ => SkyState.unknown,
};

class WeatherScene extends StatelessWidget {
  final WeatherSnapshot weather;
  final Widget child;
  const WeatherScene({super.key, required this.weather, required this.child});
  @override
  Widget build(BuildContext context) {
    final state = skyState(weather.weatherCode);
    final hour = manilaTime(weather.observedAt).hour;
    final night = weather.isDay == null
        ? hour < 6 || hour >= 18
        : !weather.isDay!;
    final color = night
        ? const Color(0xFF525D86)
        : switch (state) {
            SkyState.rain || SkyState.storm => const Color(0xFF9CAFC8),
            SkyState.cloudy || SkyState.fog => const Color(0xFFC3CAD6),
            SkyState.snow => const Color(0xFFE4F1FA),
            _ => const Color(0xFFB5DDF7),
          };
    final icon = switch (state) {
      SkyState.clear => night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
      SkyState.partlyCloudy => Icons.wb_cloudy_outlined,
      SkyState.cloudy => Icons.cloud,
      SkyState.rain => Icons.water_drop,
      SkyState.storm => Icons.thunderstorm,
      SkyState.fog => Icons.foggy,
      SkyState.snow => Icons.ac_unit,
      _ => Icons.cloud_outlined,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, const Color(0xFFEDE9FB)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 48,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey('$state:$night'),
                size: 110,
                color: const Color(0x99FFFFFF),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 12),
                child: Text(
                  '${WeatherLiveStatus.of(context) ? 'Current' : 'Saved'} estimate · ${night ? 'Night' : 'Day'} scene',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              child,
            ],
          ),
        ],
      ),
    );
  }
}
