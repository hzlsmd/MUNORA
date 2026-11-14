class CityWeather {
  final String city;
  final String temp; // e.g. "31"
  final String feelsLike; // e.g. "34°C"
  final String condition;
  final String humidity;
  final String wind;
  final String uv;
  final String uvNum;
  final String pressure;
  final double? heatIndexC;
  final String visibility;
  final String max;
  final String min;

  const CityWeather({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.condition,
    required this.humidity,
    required this.wind,
    required this.uv,
    required this.uvNum,
    required this.pressure,
    this.heatIndexC,
    required this.visibility,
    required this.max,
    required this.min,
  });
}

class HourlyPoint {
  final String time;
  final String condition;
  final String temp;
  const HourlyPoint({
    required this.time,
    required this.condition,
    required this.temp,
  });
}

class DailyPoint {
  final String day;
  final String cond;
  final String hi;
  final String lo;
  final bool today;
  const DailyPoint({
    required this.day,
    required this.cond,
    required this.hi,
    required this.lo,
    this.today = false,
  });
}
