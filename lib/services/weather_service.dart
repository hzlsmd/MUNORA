import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';

class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);
}

class WeatherService {
  static const maxResponseBytes = 131072;
  final http.Client _client;
  final String endpoint;
  final Duration requestTimeout;
  final DateTime Function() _now;
  final _pending = <String, Future<WeatherSnapshot>>{};
  final _memory = <String, WeatherSnapshot>{};
  final _aborts = <Completer<void>>{};
  bool _disposed = false;

  WeatherService(
      {http.Client? client,
      this.endpoint = const String.fromEnvironment('WEATHER_API_URL'),
      this.requestTimeout = const Duration(seconds: 25),
      DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  Future<WeatherSnapshot> fetch(String city, {bool force = false}) {
    final uri = Uri.tryParse(endpoint);
    if (_disposed ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !supportedCities.contains(city)) {
      return Future.error(const WeatherException(
          'Weather is unavailable. Please try again later.'));
    }
    final pending = _pending[city];
    if (pending != null) return pending;
    final saved = _memory[city];
    final age =
        saved == null ? null : _now().toUtc().difference(saved.updatedAt);
    if (!force &&
        saved != null &&
        saved.isUsable(_now()) &&
        age != null &&
        !age.isNegative &&
        age < const Duration(minutes: 10)) {
      return Future.value(saved);
    }
    final work = _load(city, uri);
    _pending[city] = work;
    return work.whenComplete(() => _pending.remove(city));
  }

  Future<String> _read(Uri uri, Completer<void> abort) async {
    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false;
    final response = await _client.send(request);
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxResponseBytes) {
      await response.stream.listen(null).cancel();
      throw WeatherException(response.statusCode == 429
          ? 'Too many updates. Please wait a minute and try again.'
          : 'Weather is unavailable. Please try again later.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const WeatherException(
            'Weather data is temporarily unavailable.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<WeatherSnapshot> _load(String city, Uri uri) async {
    final abort = Completer<void>();
    _aborts.add(abort);
    try {
      final raw =
          await _read(uri.replace(queryParameters: {'city': city}), abort)
              .timeout(requestTimeout, onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        throw const WeatherException(
            'Weather update timed out. Please try again.');
      });
      if (_disposed) throw const WeatherException('Weather is unavailable.');
      final snapshot =
          WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (snapshot.city != city || !snapshot.isUsable(_now())) {
        throw const FormatException('Stale or mismatched weather');
      }
      _memory[city] = snapshot;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('weather.v1.$city', raw);
      } catch (_) {/* A successful update remains usable if storage fails. */}
      return snapshot;
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(
          'Unable to update weather. Check your connection and try again.');
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  Future<WeatherSnapshot?> cached(String city) async {
    if (!supportedCities.contains(city)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('weather.v1.$city');
      if (raw == null ||
          raw.length > maxResponseBytes ||
          utf8.encode(raw).length > maxResponseBytes) {
        return null;
      }
      final snapshot =
          WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (snapshot.city != city ||
          !snapshot.isUsable(_now(), offline: true) ||
          snapshot.updatedAt.isAfter(_now().toUtc())) {
        return null;
      }
      _memory[city] = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
  }
}
