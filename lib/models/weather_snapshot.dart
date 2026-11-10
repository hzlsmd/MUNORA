import 'city_weather.dart';

double _number(dynamic value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw const FormatException('Invalid weather measurement');
  }
  return value.toDouble();
}

String _condition(dynamic value) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > 120 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid weather condition');
  }
  return value;
}

DateTime _time(dynamic value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('Invalid weather timestamp');
  }
  return DateTime.parse(value).toUtc();
}

DateTime manilaTime(DateTime time) =>
    time.toUtc().add(const Duration(hours: 8));
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String weatherTime(DateTime time) {
  final t = manilaTime(time);
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${t.day}/${t.month} $hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'} PHT';
}

class ForecastReading {
  final DateTime at;
  final String condition;
  const ForecastReading(this.at, this.condition);
}

class WeatherSnapshot {
  final double temperature;
  final double feelsLike;
  final double windSpeed;
  final List<ForecastReading> readings;
  final String city;
  final String source;
  final DateTime updatedAt;
  final DateTime observedAt;
  final DateTime forecastUntil;
  final CityWeather current;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;

  const WeatherSnapshot({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.windSpeed,
    required this.readings,
    this.source = 'OpenWeatherMap',
    required this.updatedAt,
    required this.observedAt,
    required this.forecastUntil,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  bool isUsable(DateTime now, {bool offline = false}) {
    final maxAge = offline
        ? const Duration(hours: 24)
        : const Duration(hours: 3);
    final updateAge = now.toUtc().difference(updatedAt);
    final observationAge = now.toUtc().difference(observedAt);
    return updateAge >= const Duration(minutes: -5) &&
        observationAge >= const Duration(minutes: -5) &&
        updateAge <= (offline ? maxAge : const Duration(minutes: 30)) &&
        observationAge <= maxAge &&
        (offline || forecastUntil.isAfter(now.toUtc()));
  }

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final source = json['source'] ?? 'OpenWeatherMap';
    if (source != 'Open-Meteo' && source != 'OpenWeatherMap') {
      throw const FormatException('Invalid weather source');
    }
    final city = json['city'];
    if (city is! String || city.isEmpty || city.length > 60) {
      throw const FormatException('Invalid city');
    }
    final current = json['current'] as Map<String, dynamic>;
    final raw = json['hourly'];
    if (raw is! List || raw.isEmpty || raw.length > 40) {
      throw const FormatException('Invalid forecast size');
    }
    final updatedAt = _time(json['updatedAt']);
    final observedAt = _time(json['observedAt']);
    final entries =
        raw.map((item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid forecast entry');
            }
            final time = _time(item['at']);
            final age = time.difference(updatedAt);
            if (age < const Duration(hours: -12) ||
                age > const Duration(days: 6)) {
              throw const FormatException('Invalid forecast horizon');
            }
            final low = _number(item['low'], -100, 70);
            final high = _number(item['high'], -100, 70);
            final temperature = _number(item['temperature'], -100, 70);
            if (low > temperature || temperature > high) {
              throw const FormatException('Invalid temperature range');
            }
            _condition(item['condition']);
            return {...item, 'at': time.toIso8601String()};
          }).toList()
          ..sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
    if (entries.map((item) => item['at']).toSet().length != entries.length) {
      throw const FormatException('Duplicate forecast timestamps');
    }
    final conditionReadings = json['conditionReadings'];
    final readings = <ForecastReading>[];
    if (conditionReadings != null) {
      if (conditionReadings is! List ||
          conditionReadings.isEmpty ||
          conditionReadings.length > 168) {
        throw const FormatException('Invalid hazard readings');
      }
      DateTime? previous;
      for (final item in conditionReadings) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid hazard reading');
        }
        final at = _time(item['at']);
        final age = at.difference(updatedAt);
        if (age < const Duration(hours: -1) ||
            age > const Duration(days: 7) ||
            (previous != null &&
                at.difference(previous) != const Duration(hours: 1))) {
          throw const FormatException('Invalid hazard reading time');
        }
        readings.add(ForecastReading(at, _condition(item['condition'])));
        previous = at;
      }
    } else {
      readings.addAll(
        entries.map(
          (item) =>
              ForecastReading(_time(item['at']), item['condition'] as String),
        ),
      );
    }
    _number(current['temperature'], -100, 70);
    _number(current['feelsLike'], -120, 100);
    _number(current['humidity'], 0, 100);
    _number(current['pressure'], 500, 1200);
    _number(current['wind'], 0, 150);
    _condition(current['condition']);
    String degrees(dynamic value) => '${(value as num).round()}\u00b0C';
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in entries) {
      final at = manilaTime(DateTime.parse(item['at'] as String));
      final key = '${at.year}-${at.month}-${at.day}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return WeatherSnapshot(
      temperature: (current['temperature'] as num).toDouble(),
      feelsLike: (current['feelsLike'] as num).toDouble(),
      windSpeed: (current['wind'] as num).toDouble(),
      readings: List.unmodifiable(readings),
      source: source as String,
      city: city,
      updatedAt: updatedAt,
      observedAt: observedAt,
      forecastUntil: _time(entries.last['at']),
      current: CityWeather(
        city: city,
        temp: (current['temperature'] as num).round().toString(),
        feelsLike: degrees(current['feelsLike']),
        condition: current['condition'] as String,
        humidity: '${current['humidity']}%',
        wind: '${current['wind']} m/s',
        pressure: '${current['pressure']} hPa',
        uv: 'Unavailable',
        uvNum: '--',
        visibility: '--',
        max: '--',
        min: '--',
      ),
      hourly: entries.map((item) {
        final at = manilaTime(DateTime.parse(item['at'] as String));
        final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
        return HourlyPoint(
          time:
              '${_weekdays[at.weekday - 1]} ${at.day}/${at.month}\n$hour ${at.hour < 12 ? 'AM' : 'PM'}',
          condition: item['condition'] as String,
          temp: degrees(item['temperature']),
        );
      }).toList(),
      daily: groups.values.take(5).map((items) {
        final at = manilaTime(DateTime.parse(items.first['at'] as String));
        final high = items
            .map((v) => (v['high'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
        final low = items
            .map((v) => (v['low'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
        return DailyPoint(
          day: '${_weekdays[at.weekday - 1]} ${at.day}/${at.month}',
          cond: items[items.length ~/ 2]['condition'] as String,
          hi: degrees(high),
          lo: degrees(low),
        );
      }).toList(),
    );
  }
}
