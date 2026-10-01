import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = '1cfb535a11a590059c059d06769a443f';

  // Current weather
  Future<Map<String, dynamic>> getCurrentWeather([
    String city = 'Muntinlupa',
  ]) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?q=$city'
      '&appid=$apiKey'
      '&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load current weather: ${response.statusCode}');
    }
  }

  // 5-day / 3-hour forecast
  Future<Map<String, dynamic>> getForecast([String city = 'Muntinlupa']) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/forecast'
      '?q=$city'
      '&appid=$apiKey'
      '&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load forecast: ${response.statusCode}');
    }
  }
}
