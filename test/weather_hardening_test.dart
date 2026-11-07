import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munora/models/weather_snapshot.dart';
import 'package:munora/services/weather_service.dart';
import 'weather_fixture.dart';

class PendingClient extends http.BaseClient {
  http.AbortableRequest? request;
  final response = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) {
    request = value as http.AbortableRequest;
    return response.future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recent metadata cannot disguise a forecast containing only past hours',
      () async {
    final json = weatherFixture();
    for (var i = 0; i < (json['hourly'] as List).length; i++) {
      json['hourly'][i]['at'] = DateTime.now()
          .toUtc()
          .subtract(Duration(hours: 11 - i))
          .toIso8601String();
    }
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async => http.Response(jsonEncode(json), 200)));
    addTearDown(service.dispose);
    await expectLater(
        service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
  });

  test('timeout aborts outstanding network work and does not publish late data',
      () async {
    final client = PendingClient();
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: client,
        requestTimeout: const Duration(milliseconds: 10));
    addTearDown(service.dispose);
    await expectLater(
        service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
    await client.request!.abortTrigger!;
    client.response.complete(http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(weatherFixture()))), 200));
    await Future<void>.delayed(Duration.zero);
    expect(await service.cached('Muntinlupa'), isNull);
  });

  test('manual refresh bypasses fresh reuse and service disposal signals abort',
      () async {
    var calls = 0;
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(weatherFixture()), 200);
        }));
    await service.fetch('Muntinlupa');
    await service.fetch('Muntinlupa', force: true);
    expect(calls, 2);
    service.dispose();
    final client = PendingClient();
    final pendingService =
        WeatherService(endpoint: 'https://weather.example', client: client);
    final pending = pendingService.fetch('Muntinlupa');
    pendingService.dispose();
    await client.request!.abortTrigger!;
    client.response.complete(http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(weatherFixture()))), 200));
    await expectLater(pending, throwsA(isA<WeatherException>()));
  });

  test('concurrent same-city loads share one request and reuse fresh data',
      () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) {
          calls++;
          return response.future;
        }));
    addTearDown(service.dispose);
    final a = service.fetch('Muntinlupa');
    final b = service.fetch('Muntinlupa');
    response.complete(http.Response(jsonEncode(weatherFixture()), 200));
    await Future.wait([a, b]);
    await service.fetch('Muntinlupa');
    expect(calls, 1);
  });

  test(
      'untrusted measurement fields and excessively large forecasts are rejected',
      () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['current']['humidity'] = 500,
      (j) => j['current']['wind'] = {'bad': 'value'},
      (j) => j['current'].remove('pressure'),
      (j) => j['current']['condition'] = 'x' * 121,
      (j) => j['hourly'][0]['low'] = 80,
      (j) => j['hourly'] =
          List.generate(41, (_) => Map<String, dynamic>.from(j['hourly'][0])),
    ]) {
      final json = weatherFixture();
      change(json);
      expect(() => WeatherSnapshot.fromJson(json), throwsFormatException);
    }
  });

  test(
      'shuffled forecasts render in time order and duplicate times are rejected',
      () {
    final json = weatherFixture(updatedAt: DateTime.utc(2026, 11, 6, 15));
    json['hourly'] = (json['hourly'] as List).reversed.toList();
    expect(WeatherSnapshot.fromJson(json).hourly.first.time, 'Fri 6/11\n11 PM');
    json['hourly'].add(json['hourly'][0]);
    expect(() => WeatherSnapshot.fromJson(json), throwsFormatException);
  });

  test(
      'stale observations and future metadata cannot become a successful update',
      () async {
    for (final field in ['observedAt', 'updatedAt']) {
      final json = weatherFixture();
      json[field] = (field == 'observedAt'
              ? DateTime.now().subtract(const Duration(days: 2))
              : DateTime.now().add(const Duration(hours: 1)))
          .toUtc()
          .toIso8601String();
      final service = WeatherService(
          endpoint: 'https://weather.example',
          client:
              MockClient((_) async => http.Response(jsonEncode(json), 200)));
      await expectLater(
          service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
      expect(await service.cached('Muntinlupa'), isNull);
      service.dispose();
    }
  });

  test('oversized response does not replace a previously saved snapshot',
      () async {
    final good = jsonEncode(weatherFixture());
    SharedPreferences.setMockInitialValues({'weather.v1.Muntinlupa': good});
    final json = weatherFixture()..['padding'] = 'x' * 131073;
    final service = WeatherService(
        endpoint: 'https://weather.example',
        client: MockClient((_) async => http.Response(jsonEncode(json), 200)));
    addTearDown(service.dispose);
    await expectLater(
        service.fetch('Muntinlupa'), throwsA(isA<WeatherException>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('weather.v1.Muntinlupa'), good);
  });
}
