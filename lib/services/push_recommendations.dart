import 'dart:convert';

import '../models/weather_snapshot.dart';
import 'notification_preferences.dart';
import 'notification_policy.dart';
import 'push_state.dart';

/// Bounded versioned server contract; no provider calls or invented conditions.
class PushRecommendations {
  final PushAlert alert;
  final DateTime estimateAt;
  final Map<String, String> advice, fingerprints;
  const PushRecommendations(
    this.alert,
    this.estimateAt,
    this.advice,
    this.fingerprints,
  );
  static PushRecommendations? parse(Map<String, dynamic> data, DateTime now) {
    final alert = PushAlert.parse(data, now);
    if (alert == null || data['schema'] != '2') return null;
    try {
      final rawTime = data['estimateAt'];
      if (rawTime is! String || !rawTime.endsWith('Z')) return null;
      final estimate = DateTime.parse(rawTime);
      final age = now.toUtc().difference(estimate);
      if (age < const Duration(minutes: -5) || age > const Duration(hours: 3)) {
        return null;
      }
      dynamic boundedJson(String key) {
        final raw = data[key];
        if (raw is! String || raw.length > 3000) throw const FormatException();
        return jsonDecode(raw);
      }

      final triggers = boundedJson('triggers');
      final texts = boundedJson('recommendations');
      final signatures = boundedJson('fingerprints');
      if (triggers is! List ||
          triggers.length > 6 ||
          texts is! Map ||
          signatures is! Map) {
        return null;
      }
      final advice = <String, String>{}, fingerprints = <String, String>{};
      for (final id in triggers) {
        if (id is! String || !notificationCategories.contains(id)) return null;
        final text = texts[id], signature = signatures[id];
        if (text is! String ||
            text.trim().isEmpty ||
            text.length > 600 ||
            signature is! String ||
            signature.isEmpty ||
            signature.length > 300) {
          return null;
        }
        advice[id] = text;
        fingerprints[id] = signature;
      }
      return PushRecommendations(alert, estimate, advice, fingerprints);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> due(
    DateTime now,
    NotificationPreferences preferences,
    Map<String, NotificationRecord> history,
  ) {
    if (preferences.isQuiet(now)) return {};
    return Map.fromEntries(
      advice.entries.where((e) {
        if (!preferences.categories.contains(e.key)) return false;
        if (e.key == 'clear' &&
            (manilaTime(now).hour < 6 || manilaTime(now).hour >= 18)) {
          return false;
        }
        final record = history[e.key];
        if (record == null) return true;
        final age = now.difference(record.sentAt);
        return age >= const Duration(hours: 1) &&
            (record.fingerprint != fingerprints[e.key] ||
                age >= const Duration(hours: 12));
      }),
    );
  }
}
