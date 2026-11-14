const supportedCityCoordinates = <String, (double, double)>{
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

final supportedCities = List<String>.unmodifiable(
  supportedCityCoordinates.keys,
);
