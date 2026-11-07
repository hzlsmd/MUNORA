import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/weather_service.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'weather_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses only the backend URL and caches a successful response', () async {
    final service = WeatherService(
        endpoint: 'https://weather.example/weather',
        client: MockClient((request) async {
          expect(request.url.queryParameters, {'city': 'Muntinlupa'});
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(jsonEncode(weatherFixture()), 200);
        }));
    addTearDown(service.dispose);
    expect((await service.fetch('Muntinlupa')).current.temp, '30');
    expect((await service.cached('Muntinlupa'))!.city, 'Muntinlupa');
  });

  test('rejects wrong-city data and unsafe/missing endpoints', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(weatherFixture(city: 'Manila')), 200);
    });
    for (final url in [
      '',
      'http://weather.example/weather',
      'https://weather.example/weather'
    ]) {
      final service = WeatherService(endpoint: url, client: client);
      await expectLater(
          service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
    }
    expect(requests, 1);
    client.close();
  });

  test('ignores corrupted, future, old and wrong-city offline snapshots',
      () async {
    final service = WeatherService();
    addTearDown(service.dispose);
    for (final raw in [
      'not json',
      jsonEncode(weatherFixture(city: 'Manila')),
      jsonEncode(weatherFixture(
          updatedAt: DateTime.now().subtract(const Duration(hours: 25)))),
      jsonEncode(weatherFixture(
          updatedAt: DateTime.now().add(const Duration(hours: 1))))
    ]) {
      SharedPreferences.setMockInitialValues({'weather.v1.Muntinlupa': raw});
      expect(await service.cached('Muntinlupa'), isNull);
    }
  });

  test('handles rate limiting, invalid JSON and provider failures', () async {
    for (final response in [
      http.Response('{}', 429),
      http.Response('{}', 503),
      http.Response('broken', 200)
    ]) {
      final service = WeatherService(
          endpoint: 'https://weather.example',
          client: MockClient((_) async => response));
      await expectLater(
          service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
      service.dispose();
    }
  });

  test('groups forecast by Philippine date, including UTC day rollover', () {
    final snapshot = WeatherSnapshot.fromJson(
        weatherFixture(updatedAt: DateTime.utc(2026, 11, 6, 15)));
    expect(snapshot.daily.length, 2);
    expect(snapshot.daily[0].day, 'Fri 6/11');
    expect(snapshot.daily[1].day, 'Sat 7/11');
    expect(snapshot.daily[1].hi, '29\u00b0C');
    expect(snapshot.daily[1].lo, '26\u00b0C');
    expect(snapshot.hourly[1].time, 'Sat 7/11\n2 AM');
    expect(weatherTime(DateTime.parse('2026-11-06T18:00:00Z')),
        '7/11 2:00 AM PHT');
  });
}
