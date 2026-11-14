import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';
import 'notification_policy.dart';
import 'weather_service.dart';
import 'push_notifications.dart';

const _job = 'munora.weather.tips.v1';
const _enabledKey = 'notifications.weather.enabled';
const _notificationId = 2401;

@pragma('vm:entry-point')
void weatherNotificationDispatcher() {
  Workmanager().executeTask((task, _) async {
    DartPluginRegistrant.ensureInitialized();
    if (task != _job) return true;
    try {
      await NotificationService().checkWeather();
    } catch (_) {
      // Leave transient network failures for the next periodic check.
    }
    return true;
  });
}

class NotificationService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final _plugin = FlutterLocalNotificationsPlugin();
  late SharedPreferences _prefs;

  /// Repair delivery after an app update or a change between push/local builds.
  /// Permission is only requested by the explicit setEnabled(true) action.
  Future<void> initialize() async {
    if (!supported) return;
    if (PushNotifications.configured) {
      try {
        await PushNotifications.instance.refresh();
      } catch (_) {
        // Subscription reconciliation already records its pending status.
      }
      return;
    }
    var localFailed = false;
    try {
      await _reload();
      if (_prefs.getBool(_enabledKey) ?? false) {
        await _initialize();
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (await android?.areNotificationsEnabled() == true) {
          await _registerLocal();
        } else {
          await Workmanager().cancelByUniqueName(_job);
        }
      } else {
        await Workmanager().cancelByUniqueName(_job);
      }
      PushNotifications.instance.status.value = null;
    } catch (_) {
      localFailed = true;
      PushNotifications.instance.status.value =
          'Local weather notification setup is pending. Retry when online.';
    }
    // Local scheduling does not wait for Firebase or legacy topic cleanup.
    try {
      await PushNotifications.instance.initialize();
    } catch (_) {
      PushNotifications.instance.status.value =
          'Previous push subscription cleanup is pending. Retry when online.';
    }
    if (localFailed) {
      PushNotifications.instance.status.value =
          'Local weather notification setup is pending. Retry when online.';
    }
  }

  Future<void> _registerLocal() async {
    await Workmanager().initialize(weatherNotificationDispatcher);
    await Workmanager().registerPeriodicTask(
      _job,
      _job,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    // An opt-out can race a startup/resume registration in the native scheduler.
    await _reload();
    if (!(_prefs.getBool(_enabledKey) ?? false)) {
      await Workmanager().cancelByUniqueName(_job);
    }
  }

  Future<void> _reload() async {
    // Share the existing city-picker store, refreshing its per-isolate cache.
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
  }

  Future<bool> enabled() async {
    if (!supported) return false;
    if (PushNotifications.configured) {
      return PushNotifications.instance.enabled();
    }
    await _reload();
    return _prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> _initialize() async {
    final ready = await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_weather_notification'),
      ),
      onDidReceiveNotificationResponse: PushNotifications.instance.localTap,
    );
    if (ready != true) throw StateError('Notifications unavailable');
  }

  Future<bool> setEnabled(bool value) async {
    if (!supported) return false;
    if (PushNotifications.configured) {
      return PushNotifications.instance.setEnabled(value);
    }
    await _reload();
    if (!value) {
      // Persist first so an already-running worker cannot publish after opt-out.
      await _prefs.setBool(_enabledKey, false);
      await Workmanager().cancelByUniqueName(_job);
      await _initialize();
      await _plugin.cancel(_notificationId);
      await _plugin.cancel(_notificationId + 1);
      await PushNotifications.instance.cleanupLegacyPush();
      return false;
    }
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = await android?.requestNotificationsPermission() ?? false;
    if (!allowed) {
      await _prefs.setBool(_enabledKey, false);
      await Workmanager().cancelByUniqueName(_job);
      return false;
    }
    try {
      await _prefs.setBool(_enabledKey, true);
      await _registerLocal();
    } catch (_) {
      await _prefs.setBool(_enabledKey, false);
      rethrow;
    }
    return true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'weather_tips',
      'Weather recommendations',
      channelDescription: 'Rule-based advice for the selected NCR city',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      onlyAlertOnce: true,
    ),
  );

  Future<void> sendTest() async {
    if (!await enabled()) throw StateError('Enable notifications first');
    await _initialize();
    await _plugin.show(
      _notificationId + 1,
      'MUNORA notification test',
      'Weather recommendations are enabled on this phone.',
      _details,
    );
  }

  Future<void> checkWeather() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (PushNotifications.configured || !await enabled()) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() != true) return;
    final city = _prefs.getString('selectedCity') ?? 'Muntinlupa';
    if (!supportedCities.contains(city)) return;
    final weatherService = WeatherService();
    try {
      final snapshot = await weatherService.fetch(city);
      final now = DateTime.now().toUtc();
      final previous = <String, DateTime>{};
      for (final trigger in ['rain', 'storm', 'heat', 'wind']) {
        final key = notificationKey(city, trigger);
        final time = _prefs.getString('notifications.last.$key');
        final parsed = time == null ? null : DateTime.tryParse(time);
        if (parsed != null) previous[key] = parsed;
      }
      final tips = notificationTips(snapshot, now, previous);
      if (tips.isEmpty || !await enabled()) return;
      // City may have changed while the network request was running.
      if ((_prefs.getString('selectedCity') ?? 'Muntinlupa') != city) return;
      await _initialize();
      await _plugin.show(
        _notificationId,
        '$city weather tips',
        '${tips.map((t) => t.title).join('. ')}. '
            'Estimate ${weatherTime(snapshot.observedAt)}. Check official advisories.',
        _details,
      );
      // Recheck after platform delivery to honour a concurrent opt-out.
      if (!await enabled()) {
        await _plugin.cancel(_notificationId);
        return;
      }
      for (final tip in tips) {
        await _prefs.setString(
          'notifications.last.${notificationKey(city, tip.id)}',
          now.toIso8601String(),
        );
      }
    } finally {
      weatherService.dispose();
    }
  }
}
