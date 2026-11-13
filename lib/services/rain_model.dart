import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Only numeric parameters are loaded; no executable model serialization.
class RainModel {
  static const cities = [
    'muntinlupa',
    'manila',
    'quezon_city',
    'makati',
    'taguig',
    'pasig',
    'pasay',
    'mandaluyong',
    'marikina',
    'caloocan',
    'malabon',
    'navotas',
    'valenzuela',
    'las_pinas',
    'paranaque',
    'san_juan',
    'pateros',
  ];
  static const units = {
    'temperatureC': '°C',
    'humidityPercent': '%',
    'pressureHpa': 'hPa',
    'windSpeedMs': 'm/s',
  };
  static final featureNames = <String>[
    'temperatureC',
    'humidityPercent',
    'pressureHpa',
    'windSpeedMs',
    'wetFlag',
    'hourSin',
    'hourCos',
    'seasonSin',
    'seasonCos',
    ...cities.map((c) => 'city_$c'),
  ];
  static const wetCodes = {
    51,
    53,
    55,
    56,
    57,
    61,
    63,
    65,
    66,
    67,
    71,
    73,
    75,
    77,
    80,
    81,
    82,
    85,
    86,
    95,
    96,
    99,
  };
  static const dryCodes = {0, 1, 2, 3, 45, 48};
  final String version;
  final List<double> _means, _scales, _coefficients;
  final double _intercept;
  final Map<String, List<double>> _bounds;
  RainModel._(
    this.version,
    this._means,
    this._scales,
    this._coefficients,
    this._intercept,
    this._bounds,
  );

  static double _number(dynamic value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Nonfinite model parameter');
    }
    return value.toDouble();
  }

  static RainModel decode(String json) {
    if (utf8.encode(json).length > 131072) {
      throw const FormatException('Oversized rain model');
    }
    final value = jsonDecode(json);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid rain model');
    }
    return RainModel.fromJson(value);
  }

  factory RainModel.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['validationPassed'] != true) {
      throw const FormatException('Unvalidated rain model');
    }
    final target = json['target'];
    final offsets = target is Map ? target['futureOffsets'] : null;
    if (target is! Map ||
        target['hours'] != 3 ||
        target['rainThresholdMm'] != .1 ||
        offsets is! List ||
        offsets.length != 3 ||
        offsets[0] != 1 ||
        offsets[1] != 2 ||
        offsets[2] != 3) {
      throw const FormatException('Unsupported rain target');
    }
    final transform = json['featureTransform'];
    if (transform is! Map ||
        transform['timezone'] != 'Asia/Manila' ||
        transform['hour'] != 'hour+minute/60+second/3600' ||
        transform['season'] != '(dayOfYear-1+hour/24)/365.2425') {
      throw const FormatException('Unsupported feature transform');
    }
    bool sameCodes(dynamic value, Set<int> expected) =>
        value is List &&
        value.length == expected.length &&
        value.every((v) => v is int && expected.contains(v)) &&
        value.toSet().length == expected.length;
    if (!sameCodes(json['wetWeatherCodes'], wetCodes) ||
        !sameCodes(json['acceptedWeatherCodes'], {...dryCodes, ...wetCodes})) {
      throw const FormatException('Unsupported weather code transforms');
    }
    final version = json['modelVersion'];
    if (version is! String ||
        !RegExp(r'^[a-zA-Z0-9._-]{1,80}$').hasMatch(version)) {
      throw const FormatException('Invalid model version');
    }
    bool same(dynamic actual, List<String> expected) =>
        actual is List &&
        actual.length == expected.length &&
        List.generate(
          expected.length,
          (i) => actual[i] == expected[i],
        ).every((v) => v);
    if (!same(json['featureNames'], featureNames) ||
        !same(json['cities'], cities)) {
      throw const FormatException('Unsupported model features');
    }
    final rawUnits = json['units'];
    if (rawUnits is! Map ||
        units.entries.any((e) => rawUnits[e.key] != e.value)) {
      throw const FormatException('Unsupported model units');
    }
    List<double> vector(String key) {
      final v = json[key];
      if (v is! List || v.length != featureNames.length) {
        throw const FormatException('Invalid model dimensions');
      }
      return List.unmodifiable(v.map(_number));
    }

    final scales = vector('scales');
    if (scales.any((s) => s <= 0)) {
      throw const FormatException('Invalid scaling');
    }
    final rawBounds = json['bounds'];
    if (rawBounds is! Map) throw const FormatException('Missing model support');
    final bounds = <String, List<double>>{};
    for (final key in units.keys) {
      final value = rawBounds[key];
      if (value is! Map) throw const FormatException('Missing model support');
      final low = _number(value['min']), high = _number(value['max']);
      if (low >= high) throw const FormatException('Invalid model support');
      bounds[key] = [low, high];
    }
    return RainModel._(
      version,
      vector('means'),
      scales,
      vector('coefficients'),
      _number(json['intercept']),
      bounds,
    );
  }

  List<double>? features(RainInput input) {
    final city = input.city.toLowerCase().replaceAll(' ', '_');
    if (!cities.contains(city) ||
        (!wetCodes.contains(input.weatherCode) &&
            !dryCodes.contains(input.weatherCode))) {
      return null;
    }
    final values = [
      input.temperatureC,
      input.humidityPercent,
      input.pressureHpa,
      input.windSpeedMs,
    ];
    for (var i = 0; i < values.length; i++) {
      final bounds = _bounds[units.keys.elementAt(i)]!;
      if (!values[i].isFinite ||
          values[i] < bounds[0] ||
          values[i] > bounds[1]) {
        return null;
      }
    }
    final local = input.observedAt.toUtc().add(const Duration(hours: 8));
    final hour = local.hour + local.minute / 60 + local.second / 3600;
    final day = local.difference(DateTime.utc(local.year)).inDays;
    final hourPhase = 2 * math.pi * hour / 24;
    final seasonPhase = 2 * math.pi * (day + hour / 24) / 365.2425;
    return [
      ...values,
      wetCodes.contains(input.weatherCode) ? 1 : 0,
      math.sin(hourPhase),
      math.cos(hourPhase),
      math.sin(seasonPhase),
      math.cos(seasonPhase),
      ...cities.map((c) => c == city ? 1.0 : 0.0),
    ];
  }

  RainPrediction? predict(RainInput input, {required DateTime now}) {
    final age = now.toUtc().difference(input.observedAt.toUtc());
    if (age > const Duration(minutes: 30) ||
        age < const Duration(minutes: -5)) {
      return null;
    }
    final values = features(input);
    if (values == null) return null;
    var score = _intercept;
    for (var i = 0; i < values.length; i++) {
      score += ((values[i] - _means[i]) / _scales[i]) * _coefficients[i];
    }
    if (!score.isFinite) return null;
    final probability = score >= 0
        ? 1 / (1 + math.exp(-score))
        : math.exp(score) / (1 + math.exp(score));
    return RainPrediction(probability, input.observedAt.toUtc(), version);
  }
}

class RainInput {
  final double temperatureC, humidityPercent, pressureHpa, windSpeedMs;
  final int weatherCode;
  final String city;
  final DateTime observedAt;
  const RainInput({
    required this.temperatureC,
    required this.humidityPercent,
    required this.pressureHpa,
    required this.windSpeedMs,
    required this.weatherCode,
    required this.city,
    required this.observedAt,
  });
}

class RainPrediction {
  final double probability;
  final DateTime estimatedAt;
  final String modelVersion;
  const RainPrediction(this.probability, this.estimatedAt, this.modelVersion);
  DateTime get windowEnd => estimatedAt.add(const Duration(hours: 3));
}

String formatRainProbability(double probability) => probability < .01
    ? '<1%'
    : probability > .99
    ? '>99%'
    : '${(probability * 100).round()}%';

/// Shared lazy future: startup and weather requests never wait for this asset.
class RainModelLoader {
  static final RainModelLoader instance = RainModelLoader();
  final Future<String> Function() _read;
  Future<RainModel?>? _future;
  RainModelLoader({Future<String> Function()? read})
    : _read =
          read ??
          (() => rootBundle.loadString('assets/models/rain_model.json'));
  Future<RainModel?> load() => _future ??= _load();
  Future<RainModel?> _load() async {
    try {
      return RainModel.decode(await _read());
    } catch (_) {
      return null;
    }
  }
}
