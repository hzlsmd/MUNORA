import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/services/weather_service.dart';
import 'weather_fixture.dart';

Map<String, dynamic> openMeteoFixture(DateTime now) {
  final start = DateTime.utc(now.year, now.month, now.day, now.hour);
  return {
    'current_units': {
      'time': 'unixtime',
      'temperature_2m': '\u00b0C',
      'apparent_temperature': '\u00b0C',
      'relative_humidity_2m': '%',
      'pressure_msl': 'hPa',
      'wind_speed_10m': 'm/s',
      'weather_code': 'wmo code'
    },
    'hourly_units': {
      'time': 'unixtime',
      'temperature_2m': '\u00b0C',
      'weather_code': 'wmo code'
    },
    'current': {
      'time': now.millisecondsSinceEpoch ~/ 1000,
      'temperature_2m': 30.0,
      'apparent_temperature': 33.0,
      'relative_humidity_2m': 80,
      'pressure_msl': 1010.0,
      'wind_speed_10m': 2.5,
      'weather_code': 61
    },
    'hourly': {
      'time': List.generate(144,
          (i) => start.add(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000),
      'temperature_2m': List<dynamic>.generate(144, (i) => 28.0 + i % 4),
      'weather_code': List.filled(144, 3),
    },
  };
}

void main() {
  final now = DateTime.utc(2026, 11, 7, 4);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('provider cache stays isolated and survives a failed manual update',
      () async {
    SharedPreferences.setMockInitialValues(
        {'weather.v1.Muntinlupa': jsonEncode(weatherFixture(updatedAt: now))});
    var fail = false;
    final service = WeatherService(
        now: () => now,
        client: MockClient((_) async => fail
            ? http.Response('{}', 429)
            : http.Response.bytes(
                utf8.encode(jsonEncode(openMeteoFixture(now))), 200)));
    addTearDown(service.dispose);
    expect(await service.cached('Muntinlupa'), isNull);
    await service.fetch('Muntinlupa');
    fail = true;
    await expectLater(service.fetch('Muntinlupa', force: true),
        throwsA(isA<WeatherException>()));
    final cached = await service.cached('Muntinlupa');
    expect(cached!.source, 'Open-Meteo');
    expect(cached.current.temp, '30');
    final expired =
        WeatherService(now: () => now.add(const Duration(hours: 25)));
    addTearDown(expired.dispose);
    expect(await expired.cached('Muntinlupa'), isNull);
  });

  test(
      'default client gets model weather without keys and caches normalized data',
      () async {
    var calls = 0;
    final service = WeatherService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'api.open-meteo.com');
          expect(request.url.path, '/v1/forecast');
          expect(request.url.queryParameters['latitude'], '14.4081');
          expect(request.url.queryParameters['longitude'], '121.0415');
          expect(request.url.queryParameters['wind_speed_unit'], 'ms');
          expect(request.url.queryParameters['timeformat'], 'unixtime');
          expect(request.url.queryParameters.containsKey('apikey'), isFalse);
          return http.Response.bytes(
              utf8.encode(jsonEncode(openMeteoFixture(now))), 200);
        }));
    addTearDown(service.dispose);
    final snapshot = await service.fetch('Muntinlupa');
    expect(snapshot.current.temp, '30');
    expect(snapshot.current.wind, '2.5 m/s');
    expect(snapshot.current.condition, 'Light rain');
    expect(snapshot.observedAt, now);
    expect(snapshot.hourly.length, 120);
    for (var i = 1; i < snapshot.readings.length; i++) {
      expect(snapshot.readings[i].at.difference(snapshot.readings[i - 1].at),
          const Duration(hours: 1));
    }
    expect(snapshot.hourly[1].time, 'Sat 7/11\n1 PM');
    expect(snapshot.readings.last.at.difference(snapshot.readings.first.at),
        const Duration(hours: 119));
    expect(snapshot.daily.length, 5);
    expect(snapshot.hourly.first.time, 'Sat 7/11\n12 PM');
    expect((await service.cached('Muntinlupa'))!.current.temp, '30');
    await service.fetch('Muntinlupa');
    expect(calls, 1);
  });

  test('old three-hour provider cache is not shown as hourly weather', () async {
    final old = weatherFixture(updatedAt: now)..['source'] = 'Open-Meteo';
    SharedPreferences.setMockInitialValues({
      'weather.openmeteo.v1.Muntinlupa': jsonEncode(old),
    });
    final service = WeatherService(now: () => now);
    addTearDown(service.dispose);
    expect(await service.cached('Muntinlupa'), isNull);
  });

  test('hourly forecast retains five Philippine dates across midnight', () async {
    final late = DateTime.utc(2026, 11, 7, 15, 30);
    final service = WeatherService(now: () => late, client: MockClient((_) async =>
      http.Response.bytes(utf8.encode(jsonEncode(openMeteoFixture(late))), 200)));
    addTearDown(service.dispose);
    final data = await service.fetch('Muntinlupa');
    expect(data.hourly.length, 120);
    expect(data.hourly[0].time, 'Sat 7/11\n11 PM');
    expect(data.hourly[1].time, 'Sun 8/11\n12 AM');
    expect(data.daily, hasLength(5));
    expect(data.daily.first.hi, '28°C');
    expect(data.daily.first.lo, '28°C');
    expect(data.daily[1].hi, '31°C');
    expect(data.daily[1].lo, '28°C');
  });

  test(
      'different cities use their fixed coordinates and invalid cities never fetch',
      () async {
    var calls = 0;
    final service = WeatherService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['latitude'], '14.5995');
          return http.Response.bytes(
              utf8.encode(jsonEncode(openMeteoFixture(now))), 200);
        }));
    addTearDown(service.dispose);
    expect((await service.fetch('Manila')).city, 'Manila');
    await expectLater(
        service.fetch('Unknown'), throwsA(isA<WeatherException>()));
    expect(calls, 1);
  });

  test(
      'malformed arrays, units, unknown codes and stale model data cannot enter cache',
      () async {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['hourly']['temperature_2m'].removeLast(),
      (j) {
        for (final key in ['time', 'temperature_2m', 'weather_code']) {
          j['hourly'][key] = (j['hourly'][key] as List).take(6).toList();
        }
      },
      (j) => j['hourly']['time'][1] = j['hourly']['time'][0],
      (j) => j['current_units']['wind_speed_10m'] = 'km/h',
      (j) => j['current']['weather_code'] = 999,
      (j) => j['hourly']['temperature_2m'][2] = null,
      (j) => j['current']['relative_humidity_2m'] = 500,
      (j) => j['current']['time'] -= 86400,
    ]) {
      final json = openMeteoFixture(now);
      change(json);
      SharedPreferences.setMockInitialValues({});
      final service = WeatherService(
          now: () => now,
          client: MockClient((_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(json)), 200)));
      await expectLater(
          service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
      expect(await service.cached('Muntinlupa'), isNull);
      service.dispose();
    }
  });
}
