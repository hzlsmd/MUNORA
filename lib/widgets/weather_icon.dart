import 'package:material_ui/material_ui.dart';

import 'atmosphere.dart';

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
  if (c.contains('thunder') || c.contains('storm')) {
    return WeatherKind.thunderstorm;
  }
  if (c.contains('snow')) return WeatherKind.snow;
  if (c.contains('haze') || c.contains('fog') || c.contains('mist')) {
    return WeatherKind.haze;
  }
  if (c.contains('wind') || c.contains('breezy')) return WeatherKind.wind;
  if (c.contains('night') && c.contains('rain')) return WeatherKind.nightRain;
  if (c.contains('moon') || c.contains('night') || c.contains('clear night')) {
    return WeatherKind.moon;
  }
  if (c.contains('drizzle') ||
      c.contains('light rain') ||
      c.contains('scattered rain')) {
    return WeatherKind.drizzle;
  }
  if (c.contains('heavy rain') ||
      c.contains('rain') ||
      c.contains('shower') ||
      c.contains('rainfall')) {
    return WeatherKind.rain;
  }

  if (c.contains('partly') ||
      c.contains('partial') ||
      c.contains('mostly sunny') ||
      c.contains('partly sunny')) {
    return WeatherKind.partlyCloudy;
  }
  if (c.contains('cloud') ||
      c.contains('overcast') ||
      c.contains('scattered cloud') ||
      c.contains('humid')) {
    return WeatherKind.cloudy;
  }
  return WeatherKind.sunny; // sun / clear / hot / warm, and the default
}

class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  const WeatherIcon({super.key, required this.condition, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final kind = weatherKindFor(condition);
    final asset = switch (kind) {
      WeatherKind.sunny => 'c7269',
      WeatherKind.partlyCloudy => '1acef',
      WeatherKind.cloudy => '96cf4',
      WeatherKind.rain || WeatherKind.nightRain => '7d6bd',
      WeatherKind.drizzle => '7d6bd',
      WeatherKind.thunderstorm => '5f9df',
      WeatherKind.wind => '53672',
      _ => null,
    };
    return Semantics(
      label: condition,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: asset != null
              ? DesignIcon(asset)
              : Icon(
                  kind == WeatherKind.snow
                      ? Icons.ac_unit_rounded
                      : kind == WeatherKind.moon
                      ? Icons.nights_stay_outlined
                      : Icons.blur_on_rounded,
                  size: size,
                  color: const Color(0xFF5B5FC7),
                ),
        ),
      ),
    );
  }
}
