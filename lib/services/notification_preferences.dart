import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_snapshot.dart';

const notificationCategories = {'storm', 'rain', 'heat', 'wind', 'uv', 'clear'};

/// Shared preferences applied before local or data-only push delivery.
class NotificationPreferences {
  final Set<String> categories;
  final int? quietStart, quietEnd;
  const NotificationPreferences({
    this.categories = const {'storm', 'rain', 'heat', 'wind', 'uv'},
    this.quietStart,
    this.quietEnd,
  });
  bool isQuiet(DateTime now) {
    final start = quietStart, end = quietEnd;
    if (start == null || end == null || start == end) return false;
    final hour = manilaTime(now).hour;
    return start < end
        ? hour >= start && hour < end
        : hour >= start || hour < end;
  }

  static Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    try {
      final value = jsonDecode(
        prefs.getString('notifications.preferences.v1') ?? 'null',
      );
      if (value is! Map) return const NotificationPreferences();
      final categories = value['categories'];
      int? hour(dynamic n) => n is int && n >= 0 && n < 24 ? n : null;
      return NotificationPreferences(
        categories: categories is List
            ? categories
                  .whereType<String>()
                  .where(notificationCategories.contains)
                  .toSet()
            : const {'storm', 'rain', 'heat', 'wind', 'uv'},
        quietStart: hour(value['quietStart']),
        quietEnd: hour(value['quietEnd']),
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'notifications.preferences.v1',
      jsonEncode({
        'categories': categories
            .where(notificationCategories.contains)
            .toList(),
        'quietStart': quietStart,
        'quietEnd': quietEnd,
      }),
    )) {
      throw StateError('Unable to save notification preferences');
    }
  }
}
