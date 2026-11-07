import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
}

class WeatherService {
  final http.Client _client;
  final String endpoint;
  WeatherService(
      {http.Client? client,
      this.endpoint = const String.fromEnvironment('WEATHER_API_URL')})
      : _client = client ?? http.Client();

  Future<WeatherSnapshot> fetch(String city) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !supportedCities.contains(city)) {
      throw const WeatherException(
          'Weather is unavailable. Please try again later.');
    }
    try {
      final response = await _client
          .get(uri.replace(queryParameters: {'city': city}))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw WeatherException(response.statusCode == 429
            ? 'Too many updates. Please wait a minute and try again.'
            : 'Weather is unavailable. Please try again later.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final snapshot = WeatherSnapshot.fromJson(data);
      if (snapshot.city != city) throw const FormatException('City mismatch');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('weather.v1.$city', response.body);
      } catch (_) {/* Storage failure must not discard a successful update. */}
      return snapshot;
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(
          'Unable to update weather. Check your connection and try again.');
    }
  }

  Future<WeatherSnapshot?> cached(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('weather.v1.$city');
      if (raw == null) return null;
      final snapshot =
          WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final age = DateTime.now().toUtc().difference(snapshot.updatedAt.toUtc());
      if (snapshot.city != city ||
          age.isNegative ||
          age > const Duration(hours: 24)) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
