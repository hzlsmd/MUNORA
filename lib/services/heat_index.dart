import 'dart:math' as math;

/// NWS heat-index estimate in shade/light wind, calculated from unrounded inputs.
/// Returns null outside the screened Rothfusz domain rather than extrapolating.
double? heatIndexCelsius(double temperatureC, double humidity) {
  if (!temperatureC.isFinite ||
      !humidity.isFinite ||
      humidity < 0 ||
      humidity > 100) {
    return null;
  }
  final t = temperatureC * 9 / 5 + 32;
  if (t < 80 || t > 112) return null;
  final simple = 0.5 * (t + 61 + (t - 68) * 1.2 + humidity * 0.094);
  if ((simple + t) / 2 < 80) return null;
  final r = humidity;
  var h =
      -42.379 +
      2.04901523 * t +
      10.14333127 * r -
      0.22475541 * t * r -
      0.00683783 * t * t -
      0.05481717 * r * r +
      0.00122874 * t * t * r +
      0.00085282 * t * r * r -
      0.00000199 * t * t * r * r;
  if (r < 13 && t <= 112) {
    h -= (13 - r) / 4 * math.sqrt((17 - (t - 95).abs()) / 17);
  } else if (r > 85 && t <= 87) {
    h += (r - 85) / 10 * (87 - t) / 5;
  }
  // Conservative MUNORA display domain (80–140 F heat index), not a clamp.
  // Extreme empirical-polynomial outputs are unavailable, not physical claims.
  if (h < 80 || h > 140) return null;
  final c = (h - 32) * 5 / 9;
  return c.isFinite ? c : null;
}
