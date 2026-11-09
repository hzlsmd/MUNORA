import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:munora/services/weather_insights.dart';

Map<String, dynamic> detailFixture(DateTime now) => {
  'hourly_units': {
    'time': 'unixtime',
    'temperature_2m': '°C',
    'relative_humidity_2m': '%',
    'precipitation_probability': '%',
    'uv_index': '',
  },
  'hourly': <String, dynamic>{
    'time': List.generate(
      48,
      (i) => now.add(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
    ),
    'temperature_2m': List.filled(48, 27),
    'relative_humidity_2m': List.filled(48, 70),
    'precipitation_probability': List.filled(48, 10),
    'uv_index': List.filled(48, 3),
  },
};
void main() {
  final now = DateTime.utc(2026, 11, 9, 0); // 8am Manila
  test(
    'outdoor window uses three consecutive daytime readings and real metrics',
    () {
      final data = WeatherInsights.parse(detailFixture(now), null, now);
      expect(data.rainProbability, 10);
      expect(data.uvIndex, 3);
      expect(data.outdoorStart, now);
      expect(data.outdoorEnd, now.add(const Duration(hours: 3)));
    },
  );
  test('high rain and missing UV never produce an outdoor window', () {
    final j = detailFixture(now);
    j['hourly']['precipitation_probability'] = List.filled(48, 90);
    expect(WeatherInsights.parse(j, null, now).outdoorStart, isNull);
    j['hourly']['precipitation_probability'] = List.filled(48, 10);
    j['hourly']['uv_index'] = List.filled(48, null);
    expect(WeatherInsights.parse(j, null, now).outdoorStart, isNull);
  });
  test('agreement compares aligned model rain readings and is not invented when missing', () {
    final j = <String, dynamic>{
      'hourly_units': {'time': 'unixtime'},
      'hourly': <String, dynamic>{
        'time': List.generate(
          6,
          (i) => now.add(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
        ),
      },
    };
    for (final model in insightModels) {
      j['hourly']['precipitation_$model'] = List<dynamic>.filled(
        6,
        model == 'gfs_seamless' ? 0 : 1,
      );
      j['hourly_units']['precipitation_$model'] = 'mm';
    }
    expect(WeatherInsights.parse(null, j, now).agreementPercent, 67);
    j['hourly']['precipitation_gfs_seamless'][2] = null;
    expect(WeatherInsights.parse(null, j, now).agreementPercent, isNull);
  });
  test(
    'bad units and invalid metric values cannot display as live readings',
    () {
      final j = detailFixture(now);
      j['hourly_units']['uv_index'] = 'unexpected';
      expect(WeatherInsights.parse(j, null, now).uvIndex, isNull);
      j['hourly']['precipitation_probability'][0] = 150;
      expect(WeatherInsights.parse(j, null, now).rainProbability, isNull);
    },
  );
  test(
    'old or far-future model data cannot produce a current agreement score',
    () {
      final j = <String, dynamic>{
        'hourly_units': <String, dynamic>{'time': 'unixtime'},
        'hourly': <String, dynamic>{
          'time': List.generate(
            6,
            (i) =>
                now.add(Duration(days: 10, hours: i)).millisecondsSinceEpoch ~/
                1000,
          ),
        },
      };
      for (final model in insightModels) {
        j['hourly_units']['precipitation_$model'] = 'mm';
        j['hourly']['precipitation_$model'] = List.filled(6, 1);
      }
      expect(WeatherInsights.parse(null, j, now).agreementPercent, isNull);
    },
  );
  test('hourly insight expires at the next forecast hour', () {
    final fetched = DateTime.utc(2026, 11, 9, 12, 59);
    final data = WeatherInsights(fetchedAt: fetched, uvIndex: 3);
    expect(data.isFresh(fetched), isTrue);
    expect(data.isFresh(fetched.add(const Duration(minutes: 1))), isFalse);
  });
  test('optional service deduplicates and keeps detail data if model request fails', () async {
    var calls = 0;
    final service = WeatherInsightsService(
      now: () => now,
      client: MockClient((req) async {
        calls++;
        expect(req.url.queryParameters['latitude'], '14.4081');
        if (req.url.queryParameters.containsKey('models')) {
          if (calls <= 2) return http.Response('{}', 503);
          final modelData = detailFixture(now);
          for (final model in insightModels) {
            modelData['hourly_units']['precipitation_$model'] = 'mm';
            modelData['hourly']['precipitation_$model'] = List.filled(48, 0);
          }
          return http.Response.bytes(utf8.encode(jsonEncode(modelData)), 200);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode(detailFixture(now))),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final pair = await Future.wait([
      service.fetch('Muntinlupa'),
      service.fetch('Muntinlupa'),
    ]);
    expect(pair.first.rainProbability, 10);
    expect(pair.first.agreementPercent, isNull);
    expect(calls, 2);
    final recovered = await service.fetch('Muntinlupa');
    expect(recovered.agreementPercent, 100);
    expect(calls, 4);
    await service.fetch('Muntinlupa');
    expect(calls, 4);
    await service.fetch('Unknown');
    expect(calls, 4);
  });
}
