const openMeteoEndpoint = 'https://api.open-meteo.com/v1/forecast';

const _coordinates = <String, (double, double)>{
  'Muntinlupa': (14.4081, 121.0415),
  'Manila': (14.5995, 120.9842),
  'Quezon City': (14.6760, 121.0437),
  'Makati': (14.5547, 121.0244),
  'Taguig': (14.5176, 121.0509),
  'Pasig': (14.5764, 121.0851),
  'Pasay': (14.5378, 121.0014),
  'Mandaluyong': (14.5794, 121.0359),
  'Marikina': (14.6507, 121.1029),
  'Caloocan': (14.6488, 120.9841),
  'Malabon': (14.6681, 120.9658),
  'Navotas': (14.6667, 120.9417),
  'Valenzuela': (14.7011, 120.9830),
  'Las Pinas': (14.4445, 120.9939),
  'Paranaque': (14.4793, 121.0198),
  'San Juan': (14.6019, 121.0355),
  'Pateros': (14.5445, 121.0680),
};

Uri openMeteoRequest(String city) {
  final coordinates = _coordinates[city]!;
  return Uri.parse(openMeteoEndpoint).replace(queryParameters: {
    'latitude': '${coordinates.$1}',
    'longitude': '${coordinates.$2}',
    'current':
        'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,pressure_msl,wind_speed_10m',
    'hourly': 'temperature_2m,weather_code',
    'wind_speed_unit': 'ms',
    'temperature_unit': 'celsius',
    'timeformat': 'unixtime',
    'timezone': 'Asia/Manila',
    'forecast_days': '6',
  });
}

const _conditions = <int, String>{
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Depositing rime fog',
  51: 'Light drizzle',
  53: 'Moderate drizzle',
  55: 'Dense drizzle',
  56: 'Light freezing drizzle',
  57: 'Dense freezing drizzle',
  61: 'Light rain',
  63: 'Moderate rain',
  65: 'Heavy rain',
  66: 'Light freezing rain',
  67: 'Heavy freezing rain',
  71: 'Light snow',
  73: 'Moderate snow',
  75: 'Heavy snow',
  77: 'Snow grains',
  80: 'Light rain showers',
  81: 'Moderate rain showers',
  82: 'Violent rain showers',
  85: 'Light snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunderstorm with light hail',
  99: 'Thunderstorm with heavy hail',
};

String _condition(dynamic code) {
  if (code is! int || !_conditions.containsKey(code)) {
    throw const FormatException('Unknown WMO weather code');
  }
  return _conditions[code]!;
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
    Map<String, dynamic> json, String city, DateTime now) {
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
    'weather_code': 'wmo code'
  });
  final current = json['current'] as Map<String, dynamic>;
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
        'condition': condition
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
      'condition': _condition(current['weather_code'])
    },
    'hourly': points,
  };
}
