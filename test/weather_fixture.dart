Map<String, dynamic> weatherFixture(
        {String city = 'Muntinlupa', DateTime? updatedAt}) =>
    {
      'city': city,
      'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'observedAt': '2026-11-06T15:00:00Z',
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
          'at': '2026-11-06T15:00:00Z',
          'temperature': 30,
          'low': 29,
          'high': 31,
          'condition': 'light rain'
        },
        {
          'at': '2026-11-06T18:00:00Z',
          'temperature': 28,
          'low': 27,
          'high': 29,
          'condition': 'clear sky'
        },
        {
          'at': '2026-11-06T21:00:00Z',
          'temperature': 27,
          'low': 26,
          'high': 28,
          'condition': 'clear sky'
        },
      ],
    };
