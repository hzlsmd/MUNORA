import 'package:shared_preferences/shared_preferences.dart';

import '../data/supported_cities.dart';

String cityTopic(String city) {
  if (!supportedCities.contains(city)) throw ArgumentError('Unsupported city');
  return 'munora_weather_${city.toLowerCase().replaceAll(' ', '_')}';
}

class PushAlert {
  final String city;
  final String eventId;
  final DateTime issuedAt;
  const PushAlert(this.city, this.eventId, this.issuedAt);

  static PushAlert? parse(Map<String, dynamic> data, DateTime now) {
    final city = data['city'];
    final id = data['eventId'];
    final raw = data['issuedAt'];
    if (data['route'] != 'alerts' ||
        city is! String ||
        !supportedCities.contains(city) ||
        id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        raw is! String ||
        !raw.endsWith('Z')) {
      return null;
    }
    final time = DateTime.tryParse(raw);
    if (time == null) return null;
    final age = now.toUtc().difference(time.toUtc());
    if (age < const Duration(minutes: -5) || age > const Duration(hours: 1)) {
      return null;
    }
    return PushAlert(city, id, time);
  }
}

/// Persist attempted subscriptions before contacting FCM, so uncertain operations
/// can be removed after restart. The caller serializes all reconcile calls.
class PushSubscriptions {
  static const knownKey = 'push.knownTopics';
  static const confirmedKey = 'push.confirmedTopic';
  final SharedPreferences prefs;
  final Future<void> Function(String) subscribe;
  final Future<void> Function(String) unsubscribe;
  PushSubscriptions(
    this.prefs, {
    required this.subscribe,
    required this.unsubscribe,
  });

  Future<void> reconcile({required bool enabled, required String city}) async {
    final target = enabled ? cityTopic(city) : null;
    final known = {...?prefs.getStringList(knownKey)};
    for (final topic in known.toList()) {
      if (topic == target && prefs.getString(confirmedKey) == target) continue;
      await unsubscribe(topic);
      known.remove(topic);
      if (!await prefs.setStringList(knownKey, known.toList())) {
        throw StateError('Unable to save subscription cleanup');
      }
      if (prefs.getString(confirmedKey) == topic) {
        await prefs.remove(confirmedKey);
      }
    }
    if (target != null && prefs.getString(confirmedKey) != target) {
      known.add(target);
      if (!await prefs.setStringList(knownKey, known.toList())) {
        throw StateError('Unable to save subscription intent');
      }
      await subscribe(target);
      if (!await prefs.setString(confirmedKey, target)) {
        throw StateError('Unable to confirm subscription');
      }
    }
  }
}
