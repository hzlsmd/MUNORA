import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/supported_cities.dart';
import 'rain_model.dart';

class SavedRainInsight {
  static Future<void> save(String city, RainPrediction value) async {
    if (!supportedCities.contains(city)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ai.rain.saved.v1.$city',
      jsonEncode({
        'probability': value.probability,
        'at': value.estimatedAt.toIso8601String(),
        'version': value.modelVersion,
      }),
    );
  }

  static Future<RainPrediction?> load(String city, DateTime now) async {
    if (!supportedCities.contains(city)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ai.rain.saved.v1.$city');
      if (raw == null || raw.length > 1024) return null;
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final probability = j['probability'], version = j['version'];
      final at = j['at'] is String ? DateTime.tryParse(j['at']) : null;
      if (probability is! num ||
          !probability.isFinite ||
          probability < 0 ||
          probability > 1 ||
          version is! String ||
          !RegExp(r'^[a-zA-Z0-9._-]{1,80}$').hasMatch(version) ||
          at == null ||
          !at.isUtc ||
          at.isAfter(now) ||
          now.difference(at) > const Duration(days: 7)) {
        return null;
      }
      return RainPrediction(probability.toDouble(), at, version);
    } catch (_) {
      return null;
    }
  }
}
