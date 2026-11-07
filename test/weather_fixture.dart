Map<String, dynamic> weatherFixture(
    {String city = 'Muntinlupa', DateTime? updatedAt}) {
  final time = (updatedAt ?? DateTime.now()).toUtc();
  return {
    'city': city,
    'updatedAt': time.toIso8601String(),
    'observedAt': time.toIso8601String(),
    'current': {
      'temperature': 30.4,
      'feelsLike': 33,
      'humidity': 80,
      'pressure': 1010,
      'wind': 2.5,
      'condition': 'light rain'
    },
    'hourly': [
      {
        'at': time.toIso8601String(),
        'temperature': 30,
        'low': 29,
        'high': 31,
        'condition': 'light rain'
      },
      {
        'at': time.add(const Duration(hours: 3)).toIso8601String(),
        'temperature': 28,
        'low': 27,
        'high': 29,
        'condition': 'clear sky'
      },
      {
        'at': time.add(const Duration(hours: 6)).toIso8601String(),
        'temperature': 27,
        'low': 26,
        'high': 28,
        'condition': 'clear sky'
      },
    ],
  };
}
