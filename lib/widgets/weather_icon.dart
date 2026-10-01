import 'package:flutter/material.dart';

enum WeatherKind {
  sunny,
  partlyCloudy,
  cloudy,
  rain,
  drizzle,
  thunderstorm,
  snow,
  moon,
  haze,
  wind,
  nightRain,
}

/// Ported 1:1 from the original app's `getKind()` string-matching logic
/// (src/components/WeatherIcon.tsx), so condition labels map to the same icon.
WeatherKind weatherKindFor(String condition) {
  final c = condition.toLowerCase();
  if (c.contains('thunder') || c.contains('storm')) return WeatherKind.thunderstorm;
  if (c.contains('snow')) return WeatherKind.snow;
  if (c.contains('haze') || c.contains('fog') || c.contains('mist')) return WeatherKind.haze;
  if (c.contains('wind') || c.contains('breezy')) return WeatherKind.wind;
  if (c.contains('night') && c.contains('rain')) return WeatherKind.nightRain;
  if (c.contains('moon') || c.contains('night') || c.contains('clear night')) return WeatherKind.moon;
  if (c.contains('heavy rain') || c.contains('rain') || c.contains('shower') || c.contains('rainfall')) {
    return WeatherKind.rain;
  }
  if (c.contains('drizzle') || c.contains('light rain') || c.contains('scattered rain')) {
    return WeatherKind.drizzle;
  }
  if (c.contains('partly') || c.contains('partial') || c.contains('mostly sunny') || c.contains('partly sunny')) {
    return WeatherKind.partlyCloudy;
  }
  if (c.contains('cloud') || c.contains('overcast') || c.contains('scattered cloud') || c.contains('humid')) {
    return WeatherKind.cloudy;
  }
  return WeatherKind.sunny; // sun / clear / hot / warm, and the default
}

class _IconSpec {
  final IconData icon;
  final Color color;
  const _IconSpec(this.icon, this.color);
}

const Map<WeatherKind, _IconSpec> _specs = {
  WeatherKind.sunny: _IconSpec(Icons.wb_sunny_rounded, Color(0xFFFFB800)),
  WeatherKind.partlyCloudy: _IconSpec(Icons.wb_cloudy_rounded, Color(0xFFFFB800)),
  WeatherKind.cloudy: _IconSpec(Icons.cloud_rounded, Color(0xFF9CA3AF)),
  WeatherKind.rain: _IconSpec(Icons.grain_rounded, Color(0xFF1A8FE3)),
  WeatherKind.drizzle: _IconSpec(Icons.grain_rounded, Color(0xFF6EC6F5)),
  WeatherKind.thunderstorm: _IconSpec(Icons.flash_on_rounded, Color(0xFF6366F1)),
  WeatherKind.snow: _IconSpec(Icons.ac_unit_rounded, Color(0xFF6EC6F5)),
  WeatherKind.moon: _IconSpec(Icons.nights_stay_rounded, Color(0xFF818CF8)),
  WeatherKind.haze: _IconSpec(Icons.blur_on_rounded, Color(0xFFD1D5DB)),
  WeatherKind.wind: _IconSpec(Icons.air_rounded, Color(0xFF9CA3AF)),
  WeatherKind.nightRain: _IconSpec(Icons.nightlight_round, Color(0xFF6366F1)),
};

/// A single icon that visually represents a weather condition string.
/// Swap the `_specs` map above for custom animated icons later if you want
/// to more closely match the original app's hand-drawn SVG animations.
class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  const WeatherIcon({super.key, required this.condition, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final spec = _specs[weatherKindFor(condition)]!;
    return Icon(spec.icon, size: size, color: spec.color);
  }
}
