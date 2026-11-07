import 'city_weather.dart';

DateTime manilaTime(DateTime time) =>
    time.toUtc().add(const Duration(hours: 8));
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String weatherTime(DateTime time) {
  final t = manilaTime(time);
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${t.day}/${t.month} $hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'} PHT';
}

class WeatherSnapshot {
  final String city;
  final DateTime updatedAt;
  final DateTime observedAt;
  final CityWeather current;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;

  const WeatherSnapshot(
      {required this.city,
      required this.updatedAt,
      required this.observedAt,
      required this.current,
      required this.hourly,
      required this.daily});

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as String;
    final current = json['current'] as Map<String, dynamic>;
    final entries = (json['hourly'] as List).cast<Map<String, dynamic>>();
    if (entries.isEmpty) throw const FormatException('Forecast is empty');
    String degrees(dynamic value) => '${(value as num).round()}\u00b0C';
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in entries) {
      final at = manilaTime(DateTime.parse(item['at'] as String));
      final key = '${at.year}-${at.month}-${at.day}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return WeatherSnapshot(
      city: city,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      observedAt: DateTime.parse(json['observedAt'] as String),
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
            temp: degrees(item['temperature']));
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
            lo: degrees(low));
      }).toList(),
    );
  }
}
