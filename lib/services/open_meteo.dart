import '../data/supported_cities.dart';
import '../data/weather_codes.dart';

const openMeteoEndpoint = 'https://api.open-meteo.com/v1/forecast';

Uri openMeteoRequest(String city) {
  final coordinates = supportedCityCoordinates[city]!;
  return Uri.parse(openMeteoEndpoint).replace(
    queryParameters: {
      'latitude': '${coordinates.$1}',
      'longitude': '${coordinates.$2}',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,pressure_msl,wind_speed_10m,is_day',
      'hourly': 'temperature_2m,weather_code,apparent_temperature,wind_speed_10m,precipitation_probability,uv_index',
      'wind_speed_unit': 'ms',
      'temperature_unit': 'celsius',
      'timeformat': 'unixtime',
      'timezone': 'Asia/Manila',
      'forecast_days': '6',
    },
  );
}

String _condition(dynamic code) {
  if (code is! int || !weatherConditions.containsKey(code)) {
    throw const FormatException('Unknown WMO weather code');
  }
  return weatherConditions[code]!;
}

DateTime _time(dynamic seconds) {
  if (seconds is! int || seconds < 0 || seconds > 4102444800) {
    throw const FormatException('Invalid epoch timestamp');
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

void _units(dynamic units, Map<String, String> expected) {
  if (units is! Map || expected.entries.any((e) => units[e.key] != e.value)) {
    throw const FormatException('Unexpected weather units');
  }
}

Map<String, dynamic> normalizeOpenMeteo(
  Map<String, dynamic> json,
  String city,
  DateTime now,
) {
  _units(json['current_units'], {
    'time': 'unixtime',
    'temperature_2m': '\u00b0C',
    'apparent_temperature': '\u00b0C',
    'relative_humidity_2m': '%',
    'pressure_msl': 'hPa',
    'wind_speed_10m': 'm/s',
    'weather_code': 'wmo code',
  });
  _units(json['hourly_units'], {
    'time': 'unixtime',
    'temperature_2m': '\u00b0C',
    'weather_code': 'wmo code',
  });
  final current = json['current'] as Map<String, dynamic>;
  final day = current['is_day'];
  if (day != null &&
      (day != 0 && day != 1 ||
          (json['current_units'] as Map)['is_day'] != '')) {
    throw const FormatException('Invalid provider day flag');
  }
  final hourly = json['hourly'] as Map<String, dynamic>;
  final times = hourly['time'] as List;
  final temperatures = hourly['temperature_2m'] as List;
  final codes = hourly['weather_code'] as List;
  if (times.isEmpty ||
      times.length > 168 ||
      temperatures.length != times.length ||
      codes.length != times.length) {
    throw const FormatException('Invalid hourly arrays');
  }
  final optionalFields = {
    'apparent_temperature': ('feelsLike', '°C', -120.0, 100.0),
    'wind_speed_10m': ('windSpeed', 'm/s', 0.0, 150.0),
    'precipitation_probability': ('rainProbability', '%', 0.0, 100.0),
    'uv_index': ('uvIndex', '', 0.0, 30.0),
  };
  // Older caches/providers may omit these fields. Present fields must carry
  // valid units and aligned arrays; null measurements remain unknown.
  for (final field in optionalFields.entries) {
    final values = hourly[field.key];
    if (values == null) continue;
    if (values is! List ||
        values.length != times.length ||
        (json['hourly_units'] as Map)[field.key] != field.value.$2) {
      throw const FormatException('Invalid optional forecast field');
    }
  }
  final points = <Map<String, dynamic>>[];
  DateTime? previous;
  final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
  for (var i = 0; i < times.length; i++) {
    final at = _time(times[i]);
    if (previous != null &&
        at.difference(previous) != const Duration(hours: 1)) {
      throw const FormatException('Unordered or incomplete hourly data');
    }
    previous = at;
    final temperature = temperatures[i];
    if (temperature is! num ||
        !temperature.isFinite ||
        temperature < -100 ||
        temperature > 70) {
      throw const FormatException('Invalid hourly temperature');
    }
    final condition = _condition(codes[i]);
    if (at.isBefore(hour)) continue;
    // Keep consecutive hourly estimates across a five-day (120-hour) window.
    if (points.length < 120) {
      points.add({
        'at': at.toIso8601String(),
        'temperature': temperature,
        'low': temperature,
        'high': temperature,
        'condition': condition,
        for (final field in optionalFields.entries)
          if (hourly[field.key] is List && hourly[field.key][i] != null)
            field.value.$1: _optionalMeasurement(
              hourly[field.key][i],
              field.value.$3,
              field.value.$4,
            ),
      });
    }
  }
  if (points.length != 120) {
    throw const FormatException('Incomplete five-day forecast');
  }
  return {
    'source': 'Open-Meteo',
    'city': city,
    'updatedAt': now.toIso8601String(),
    'observedAt': _time(current['time']).toIso8601String(),
    'current': {
      'temperature': current['temperature_2m'],
      'feelsLike': current['apparent_temperature'],
      'humidity': current['relative_humidity_2m'],
      'pressure': current['pressure_msl'],
      'wind': current['wind_speed_10m'],
      'weatherCode': current['weather_code'],
      if (day != null) 'isDay': day == 1,
      'condition': _condition(current['weather_code']),
    },
    'hourly': points,
  };
}

double _optionalMeasurement(dynamic value, double low, double high) {
  if (value is! num || !value.isFinite || value < low || value > high) {
    throw const FormatException('Invalid forecast measurement');
  }
  return value.toDouble();
}
