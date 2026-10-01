import '../models/city_weather.dart';

const List<CityWeather> cities = [
  CityWeather(city: 'Muntinlupa', temp: '31', feelsLike: '34°C', condition: 'Mostly Sunny', humidity: '80%', wind: '0.9 m/s', uv: 'Very High', uvNum: '8', pressure: '1010 hPa', visibility: '10 km', max: '33°C', min: '25°C'),
  CityWeather(city: 'Manila', temp: '33', feelsLike: '36°C', condition: 'Hot & Sunny', humidity: '75%', wind: '1.2 m/s', uv: 'Extreme', uvNum: '11', pressure: '1008 hPa', visibility: '12 km', max: '35°C', min: '27°C'),
  CityWeather(city: 'Quezon City', temp: '30', feelsLike: '33°C', condition: 'Partly Cloudy', humidity: '82%', wind: '1.5 m/s', uv: 'High', uvNum: '6', pressure: '1011 hPa', visibility: '9 km', max: '32°C', min: '24°C'),
  CityWeather(city: 'Caloocan', temp: '32', feelsLike: '35°C', condition: 'Sunny', humidity: '78%', wind: '1.1 m/s', uv: 'Very High', uvNum: '9', pressure: '1009 hPa', visibility: '11 km', max: '34°C', min: '26°C'),
  CityWeather(city: 'Las Piñas', temp: '30', feelsLike: '33°C', condition: 'Partly Cloudy', humidity: '83%', wind: '1.3 m/s', uv: 'High', uvNum: '6', pressure: '1010 hPa', visibility: '8 km', max: '32°C', min: '24°C'),
  CityWeather(city: 'Makati', temp: '34', feelsLike: '37°C', condition: 'Hot & Hazy', humidity: '70%', wind: '0.8 m/s', uv: 'Extreme', uvNum: '11', pressure: '1007 hPa', visibility: '7 km', max: '36°C', min: '28°C'),
  CityWeather(city: 'Malabon', temp: '31', feelsLike: '34°C', condition: 'Cloudy', humidity: '85%', wind: '1.6 m/s', uv: 'Moderate', uvNum: '4', pressure: '1012 hPa', visibility: '10 km', max: '32°C', min: '25°C'),
  CityWeather(city: 'Mandaluyong', temp: '33', feelsLike: '36°C', condition: 'Mostly Sunny', humidity: '74%', wind: '0.9 m/s', uv: 'Very High', uvNum: '9', pressure: '1008 hPa', visibility: '12 km', max: '35°C', min: '27°C'),
  CityWeather(city: 'Marikina', temp: '29', feelsLike: '32°C', condition: 'Scattered Rain', humidity: '88%', wind: '1.8 m/s', uv: 'Low', uvNum: '2', pressure: '1013 hPa', visibility: '6 km', max: '30°C', min: '23°C'),
  CityWeather(city: 'Navotas', temp: '31', feelsLike: '34°C', condition: 'Cloudy', humidity: '86%', wind: '1.5 m/s', uv: 'Moderate', uvNum: '4', pressure: '1011 hPa', visibility: '8 km', max: '32°C', min: '25°C'),
  CityWeather(city: 'Parañaque', temp: '31', feelsLike: '34°C', condition: 'Partly Sunny', humidity: '81%', wind: '1.2 m/s', uv: 'High', uvNum: '7', pressure: '1010 hPa', visibility: '10 km', max: '33°C', min: '25°C'),
  CityWeather(city: 'Pasay', temp: '33', feelsLike: '36°C', condition: 'Hot & Sunny', humidity: '73%', wind: '1.0 m/s', uv: 'Extreme', uvNum: '11', pressure: '1007 hPa', visibility: '11 km', max: '35°C', min: '27°C'),
  CityWeather(city: 'Pasig', temp: '32', feelsLike: '35°C', condition: 'Mostly Sunny', humidity: '77%', wind: '1.0 m/s', uv: 'Very High', uvNum: '8', pressure: '1009 hPa', visibility: '10 km', max: '34°C', min: '26°C'),
  CityWeather(city: 'Pateros', temp: '30', feelsLike: '33°C', condition: 'Partly Cloudy', humidity: '82%', wind: '1.3 m/s', uv: 'High', uvNum: '6', pressure: '1010 hPa', visibility: '9 km', max: '32°C', min: '24°C'),
  CityWeather(city: 'San Juan', temp: '33', feelsLike: '36°C', condition: 'Sunny', humidity: '76%', wind: '0.9 m/s', uv: 'Very High', uvNum: '9', pressure: '1008 hPa', visibility: '12 km', max: '35°C', min: '27°C'),
  CityWeather(city: 'Taguig', temp: '34', feelsLike: '37°C', condition: 'Hot & Clear', humidity: '71%', wind: '0.8 m/s', uv: 'Extreme', uvNum: '11', pressure: '1007 hPa', visibility: '13 km', max: '36°C', min: '28°C'),
  CityWeather(city: 'Valenzuela', temp: '31', feelsLike: '34°C', condition: 'Partly Cloudy', humidity: '83%', wind: '1.4 m/s', uv: 'High', uvNum: '6', pressure: '1011 hPa', visibility: '9 km', max: '33°C', min: '25°C'),
];

const List<HourlyPoint> hourlyBase = [
  HourlyPoint(time: 'Now', condition: 'Partly Cloudy', temp: '28°C'),
  HourlyPoint(time: '10 AM', condition: 'Sunny', temp: '29°C'),
  HourlyPoint(time: '11 AM', condition: 'Sunny', temp: '30°C'),
  HourlyPoint(time: '12 PM', condition: 'Hot & Sunny', temp: '31°C'),
  HourlyPoint(time: '1 PM', condition: 'Partly Sunny', temp: '31°C'),
  HourlyPoint(time: '2 PM', condition: 'Partly Cloudy', temp: '30°C'),
  HourlyPoint(time: '3 PM', condition: 'Rain', temp: '29°C'),
  HourlyPoint(time: '4 PM', condition: 'Rain', temp: '28°C'),
];

const List<DailyPoint> weekly = [
  DailyPoint(day: 'Today', cond: 'Mostly Sunny', hi: '33°C', lo: '25°C', today: true),
  DailyPoint(day: 'Tuesday', cond: 'Light Rain', hi: '29°C', lo: '24°C'),
  DailyPoint(day: 'Wednesday', cond: 'Partly Cloudy', hi: '30°C', lo: '25°C'),
  DailyPoint(day: 'Thursday', cond: 'Scattered Rain', hi: '29°C', lo: '24°C'),
  DailyPoint(day: 'Friday', cond: 'Thunderstorm', hi: '28°C', lo: '23°C'),
  DailyPoint(day: 'Saturday', cond: 'Partly Sunny', hi: '30°C', lo: '25°C'),
  DailyPoint(day: 'Sunday', cond: 'Sunny', hi: '32°C', lo: '26°C'),
];

const List<HourlyPoint> forecastHourly = [
  HourlyPoint(time: '10 AM', condition: 'Sunny', temp: '30°C'),
  HourlyPoint(time: '12 PM', condition: 'Hot & Sunny', temp: '32°C'),
  HourlyPoint(time: '2 PM', condition: 'Partly Sunny', temp: '31°C'),
  HourlyPoint(time: '4 PM', condition: 'Cloudy', temp: '30°C'),
  HourlyPoint(time: '6 PM', condition: 'Light Rain', temp: '29°C'),
  HourlyPoint(time: '8 PM', condition: 'Rain', temp: '28°C'),
];

const List<WeatherAlert> otherAlerts = [
  WeatherAlert(
    condition: 'Rain',
    title: 'Flood Warning',
    desc: 'Possible flooding in low-lying areas.',
    severity: 'Moderate',
    severityColor: 0xFFF59E0B,
    severityBg: 0xFFFFFBEB,
  ),
  WeatherAlert(
    condition: 'Thunderstorm',
    title: 'Thunderstorm Alert',
    desc: 'Thunderstorms may occur within the next few hours.',
    severity: 'High',
    severityColor: 0xFFEF4444,
    severityBg: 0xFFFEF2F2,
  ),
  WeatherAlert(
    condition: 'Wind',
    title: 'Strong Wind Advisory',
    desc: 'Strong winds may affect exposed areas.',
    severity: 'Active',
    severityColor: 0xFF1A8FE3,
    severityBg: 0xFFEEF6FF,
  ),
];

const List<Map<String, String>> aiRecommendations = [
  {'emoji': '☂️', 'title': 'Bring an Umbrella', 'desc': 'Rain may occur later today.'},
  {'emoji': '🚗', 'title': 'Travel Advisory', 'desc': 'Allow extra travel time due to possible heavy rainfall.'},
  {'emoji': '💧', 'title': 'Stay Hydrated', 'desc': 'Temperatures may reach 32°C this afternoon.'},
  {'emoji': '🏠', 'title': 'Stay Alert', 'desc': 'Monitor weather alerts if rainfall becomes heavier.'},
];

const List<String> aiResponses = [
  'Based on current data, expect rain around 3–5 PM. Carry an umbrella and avoid low-lying areas.',
  'Temperatures will peak at 32°C midday. Stay hydrated and limit outdoor activity between 11 AM and 2 PM.',
  'Wind speeds are moderate at 0.9 m/s. Travel should be fine but allow extra time during afternoon showers.',
  'UV Index is Very High. Apply sunscreen SPF 50+ if going out before noon.',
];
