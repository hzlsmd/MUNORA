/// Validated optional forecast inputs. Missing values stay null.
class PlanningHour {
  final DateTime at;
  final double? temperature, feelsLike, rain, uv, wind;
  final int? code;
  const PlanningHour({
    required this.at,
    this.temperature,
    this.feelsLike,
    this.rain,
    this.uv,
    this.wind,
    this.code,
  });
  bool get storm => code != null && code! >= 95;
  bool get complete =>
      temperature != null &&
      feelsLike != null &&
      rain != null &&
      uv != null &&
      wind != null &&
      code != null;
}
