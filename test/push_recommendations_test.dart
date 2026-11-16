import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:munora/services/notification_preferences.dart';
import 'package:munora/services/notification_policy.dart';
import 'package:munora/services/push_recommendations.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 5);
  Map<String, dynamic> payload() => {
    'schema': '2',
    'city': 'Manila',
    'eventId': 'manila:123',
    'issuedAt': now.toIso8601String(),
    'estimateAt': now.toIso8601String(),
    'route': 'alerts',
    'triggers': jsonEncode(['rain', 'storm']),
    'recommendations': jsonEncode({
      'rain': 'Bring an umbrella',
      'storm': 'Seek indoor shelter',
    }),
    'fingerprints': jsonEncode({'rain': 'rain:61', 'storm': 'storm:95'}),
  };
  test(
    'push preferences filter real server advice and deduplicate per condition',
    () {
      final result = PushRecommendations.parse(payload(), now)!;
      expect(
        result
            .due(now, const NotificationPreferences(categories: {'storm'}), {})
            .keys,
        ['storm'],
      );
      expect(
        result.due(
          now,
          const NotificationPreferences(quietStart: 12, quietEnd: 15),
          {},
        ),
        isEmpty,
      );
      expect(
        result.due(now, const NotificationPreferences(), {
          'rain': NotificationRecord(now, 'rain:61'),
          'storm': NotificationRecord(now, 'storm:95'),
        }),
        isEmpty,
      );
    },
  );
  test(
    'expired, oversized, unsupported and malformed payloads are ignored',
    () {
      expect(
        PushRecommendations.parse(payload(), now.add(const Duration(hours: 2))),
        isNull,
      );
      expect(
        PushRecommendations.parse({...payload(), 'triggers': 'x' * 4000}, now),
        isNull,
      );
      expect(
        PushRecommendations.parse({...payload(), 'schema': 'other'}, now),
        isNull,
      );
      expect(
        PushRecommendations.parse({
          ...payload(),
          'estimateAt': now
              .subtract(const Duration(hours: 4))
              .toIso8601String(),
        }, now),
        isNull,
      );
    },
  );
}
