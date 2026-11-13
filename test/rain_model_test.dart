import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munora/services/rain_model.dart';

Map<String, dynamic> artifact() => {
  'schemaVersion': 1,
  'target': {
    'hours': 3,
    'rainThresholdMm': .1,
    'futureOffsets': [1, 2, 3],
  },
  'featureTransform': {
    'timezone': 'Asia/Manila',
    'hour': 'hour+minute/60+second/3600',
    'season': '(dayOfYear-1+hour/24)/365.2425',
  },
  'wetWeatherCodes': RainModel.wetCodes.toList(),
  'acceptedWeatherCodes': [...RainModel.dryCodes, ...RainModel.wetCodes],
  'modelVersion': 'test-v1',
  'validationPassed': true,
  'featureNames': RainModel.featureNames,
  'cities': RainModel.cities,
  'units': RainModel.units,
  'means': List.filled(26, 0),
  'scales': List.filled(26, 1),
  'coefficients': List.filled(26, 0),
  'intercept': 0,
  'bounds': {
    'temperatureC': {'min': 20, 'max': 40},
    'humidityPercent': {'min': 20, 'max': 100},
    'pressureHpa': {'min': 980, 'max': 1030},
    'windSpeedMs': {'min': 0, 'max': 30},
  },
};
RainInput input({
  DateTime? time,
  String city = 'Manila',
  double humidity = 80,
  int code = 3,
}) => RainInput(
  temperatureC: 30,
  humidityPercent: humidity,
  pressureHpa: 1005,
  windSpeedMs: 2,
  weatherCode: code,
  city: city,
  observedAt: time ?? DateTime.utc(2026, 11, 13, 0, 15),
);
void main() {
  final now = DateTime.utc(2026, 11, 13, 0, 15);
  test('valid artifact and stable sigmoid extremes', () {
    expect(
      RainModel.fromJson(artifact()).predict(input(), now: now)!.probability,
      .5,
    );
    for (final value in [-1000, 1000]) {
      final a = artifact()..['intercept'] = value;
      expect(
        RainModel.fromJson(a).predict(input(), now: now)!.probability,
        value < 0 ? 0 : 1,
      );
    }
    expect(formatRainProbability(0), '<1%');
    expect(formatRainProbability(1), '>99%');
    expect(formatRainProbability(.994), '>99%');
  });
  test('reject malformed numeric schema, units, lengths and failed gate', () {
    for (final modify in <void Function(Map<String, dynamic>)>[
      (a) => a['schemaVersion'] = 2,
      (a) => a.remove('target'),
      (a) => a.remove('featureTransform'),
      (a) => a.remove('acceptedWeatherCodes'),
      (a) => a['target']['hours'] = 6,
      (a) => a['target']['rainThresholdMm'] = 1,
      (a) => a['target']['futureOffsets'] = [0, 1, 2],
      (a) => a['featureTransform']['timezone'] = 'UTC',
      (a) => a['featureTransform']['season'] = 'unknown',
      (a) => a['wetWeatherCodes'] = [61],
      (a) => a['acceptedWeatherCodes'] = [0, 61],
      (a) => a['validationPassed'] = false,
      (a) => a['scales'] = List.filled(26, 0),
      (a) => a['coefficients'] = [1],
      (a) => a['intercept'] = double.nan,
      (a) => a['units'] = {},
      (a) => a['featureNames'] = List.filled(26, 'unknown'),
      (a) => a['bounds']['temperatureC'] = {'min': 40, 'max': 20},
    ]) {
      final a = artifact();
      modify(a);
      expect(() => RainModel.fromJson(a), throwsFormatException);
    }
    expect(() => RainModel.decode('x' * 131073), throwsFormatException);
    expect(() => RainModel.decode(jsonEncode([])), throwsFormatException);
  });
  test('reject stale, future, unsupported and out of domain inputs', () {
    final m = RainModel.fromJson(artifact());
    for (final i in [
      input(time: now.subtract(const Duration(minutes: 31))),
      input(time: now.add(const Duration(minutes: 6))),
      input(city: 'Cebu'),
      input(humidity: 101),
      input(code: 4),
    ]) {
      expect(m.predict(i, now: now), isNull);
    }
    expect(
      m.predict(
        input(time: now.subtract(const Duration(minutes: 30))),
        now: now,
      ),
      isNotNull,
    );
    expect(
      m.predict(input(time: now.add(const Duration(minutes: 5))), now: now),
      isNotNull,
    );
  });
  test('Manila time feature transforms and fixed estimate window', () {
    final m = RainModel.fromJson(artifact());
    final i = input();
    final f = m.features(i)!;
    expect(f.length, 26);
    expect(f[4], 0);
    expect(f[5], closeTo(.8314696123025452, 1e-12));
    expect(f[10], 1); // Manila after Muntinlupa.
    final p = m.predict(i, now: now)!;
    expect(p.windowEnd, i.observedAt.add(const Duration(hours: 3)));
  });
  test('Python frozen artifact golden vectors match Dart features and probabilities', () {
    final a = jsonDecode(
      File('assets/models/rain_model.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final model = RainModel.fromJson(a);
    for (final v in a['goldenVectors'] as List) {
      final raw = v['input'];
      final time = DateTime.parse(raw['observedAt']);
      final i = RainInput(
        temperatureC: (raw['temperatureC'] as num).toDouble(),
        humidityPercent: (raw['humidityPercent'] as num).toDouble(),
        pressureHpa: (raw['pressureHpa'] as num).toDouble(),
        windSpeedMs: (raw['windSpeedMs'] as num).toDouble(),
        weatherCode: raw['weatherCode'],
        city: raw['city'],
        observedAt: time,
      );
      final f = model.features(i)!;
      for (var j = 0; j < f.length; j++) {
        expect(f[j], closeTo(v['features'][j], 1e-12));
      }
      expect(
        model.predict(i, now: time)!.probability,
        closeTo(v['probability'], 1e-12),
      );
    }
  });
  test(
    'loader reads once and missing or failed-gate model stays unavailable',
    () async {
      var reads = 0;
      final loader = RainModelLoader(
        read: () async {
          reads++;
          return jsonEncode(artifact());
        },
      );
      final values = await Future.wait([loader.load(), loader.load()]);
      expect(reads, 1);
      expect(identical(values[0], values[1]), isTrue);
      expect(
        await RainModelLoader(read: () async => throw StateError('missing'))
            .load(),
        isNull,
      );
      expect(
        await RainModelLoader(
          read: () async =>
              jsonEncode(artifact()..['validationPassed'] = false),
        ).load(),
        isNull,
      );
    },
  );
}
