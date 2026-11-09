import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_snapshot.dart';
import 'activity_planner.dart';

class ActivityRoutine {
  final Activity activity;
  final int hour, durationHours;
  const ActivityRoutine({
    required this.activity,
    required this.hour,
    required this.durationHours,
  });
  DateTime nextStart(DateTime now) {
    final local = manilaTime(now);
    var start = DateTime.utc(
      local.year,
      local.month,
      local.day,
      hour,
    ).subtract(const Duration(hours: 8));
    if (start.isBefore(now.toUtc())) start = start.add(const Duration(days: 1));
    return start;
  }

  Map<String, dynamic> toJson() => {
    'activity': activity.name,
    'hour': hour,
    'duration': durationHours,
  };
  static ActivityRoutine? fromJson(dynamic json) {
    if (json is! Map) return null;
    final activity = Activity.values
        .where((a) => a.name == json['activity'])
        .firstOrNull;
    final hour = json['hour'], duration = json['duration'];
    if (activity == null ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        duration is! int ||
        duration < 1 ||
        duration > 3) {
      return null;
    }
    return ActivityRoutine(
      activity: activity,
      hour: hour,
      durationHours: duration,
    );
  }
}

class PlannerPreferences {
  Future<ActivityRoutine?> loadRoutine(String city) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return ActivityRoutine.fromJson(
        jsonDecode(prefs.getString('planner.routine.$city') ?? 'null'),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRoutine(String city, ActivityRoutine? routine) async {
    final prefs = await SharedPreferences.getInstance();
    final success = routine == null
        ? await prefs.remove('planner.routine.$city')
        : await prefs.setString(
            'planner.routine.$city',
            jsonEncode(routine.toJson()),
          );
    if (!success) throw StateError('Routine could not be saved');
  }

  Future<Map<String, dynamic>?> lastAssessment(String city) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final value = jsonDecode(
        prefs.getString('planner.assessment.$city') ?? 'null',
      );
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAssessment(String city, String plan, String summary) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'planner.assessment.$city',
      jsonEncode({'plan': plan, 'summary': summary}),
    )) {
      throw StateError('Assessment could not be saved');
    }
  }
}
