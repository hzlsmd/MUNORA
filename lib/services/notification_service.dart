import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/supported_cities.dart';
import '../models/weather_snapshot.dart';
import 'notification_policy.dart';
import 'notification_preferences.dart';
import 'notification_config.dart';
import 'weather_service.dart';
import 'push_notifications.dart';

@pragma('vm:entry-point')
void weatherNotificationDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if (task != weatherNotificationJob) return true;
    try {
      await NotificationService().checkWeather();
    } catch (_) {
      // WorkManager retries transient failures with its bounded backoff.
      return false;
    }
    return true;
  });
}

class NotificationService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final _plugin = FlutterLocalNotificationsPlugin();
  final WeatherService Function() _weather;
  final DateTime Function() _now;
  NotificationService({
    WeatherService Function()? weatherService,
    DateTime Function()? now,
  }) : _weather = weatherService ?? WeatherService.new,
       _now = now ?? DateTime.now;
  late SharedPreferences _prefs;

  /// Repair delivery after an app update or a change between push/local builds.
  /// Permission is only requested by the explicit setEnabled(true) action.
  Future<void> initialize({bool handleLaunch = false}) async {
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
      final optedIn = _prefs.getBool(weatherNotificationsEnabledKey) ?? false;
      if (handleLaunch || optedIn) await _initialize();
      if (handleLaunch) {
        // A closed-app tap is not sent to onDidReceiveNotificationResponse.
        // Read it only on startup; resume/settings retries must not reopen it.
        // Old notifications can still be tapped after the user opted out.
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if (launch?.didNotificationLaunchApp == true && response != null) {
          PushNotifications.instance.localTap(response);
        }
      }
      if (optedIn) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (await android?.areNotificationsEnabled() == true) {
          await _registerLocal();
        } else {
          await Workmanager().cancelByUniqueName(weatherNotificationJob);
        }
      } else {
        await Workmanager().cancelByUniqueName(weatherNotificationJob);
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
      weatherNotificationJob,
      weatherNotificationJob,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    // An opt-out can race a startup/resume registration in the native scheduler.
    await _reload();
    if (!(_prefs.getBool(weatherNotificationsEnabledKey) ?? false)) {
      await Workmanager().cancelByUniqueName(weatherNotificationJob);
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
    return _prefs.getBool(weatherNotificationsEnabledKey) ?? false;
  }

  Future<void> _initialize() async {
    final ready = await _plugin.initialize(
      settings: weatherNotificationInitialization,
      onDidReceiveNotificationResponse: PushNotifications.instance.localTap,
    );
    if (ready != true) throw StateError('Notifications unavailable');
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(weatherNotificationChannel);
  }

  Future<bool> setEnabled(bool value) async {
    if (!supported) return false;
    if (PushNotifications.configured) {
      return PushNotifications.instance.setEnabled(value);
    }
    await _reload();
    if (!value) {
      // Persist first so an already-running worker cannot publish after opt-out.
      await _prefs.setBool(weatherNotificationsEnabledKey, false);
      await Workmanager().cancelByUniqueName(weatherNotificationJob);
      await _initialize();
      await _plugin.cancel(id: weatherNotificationId);
      await _plugin.cancel(id: weatherNotificationId + 1);
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
      await _prefs.setBool(weatherNotificationsEnabledKey, false);
      await Workmanager().cancelByUniqueName(weatherNotificationJob);
      return false;
    }
    try {
      await _prefs.setBool(weatherNotificationsEnabledKey, true);
      await _registerLocal();
    } catch (_) {
      await _prefs.setBool(weatherNotificationsEnabledKey, false);
      rethrow;
    }
    // WorkManager's first run has no initial delay. Do not start an additional
    // foreground check: it could race the worker and publish duplicate alerts.
    return true;
  }

  Future<void> sendTest() async {
    if (!await enabled()) throw StateError('Enable notifications first');
    await _initialize();
    await _plugin.show(
      id: weatherNotificationId + 1,
      title: 'MUNORA notification test',
      body: 'Weather recommendations are enabled on this phone.',
      notificationDetails: weatherNotificationDetails(onlyAlertOnce: true),
    );
  }

  Future<void> checkWeather() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (PushNotifications.configured || !await enabled()) return;
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() != true) return;
    final city = _prefs.getString('selectedCity') ?? 'Muntinlupa';
    if (!supportedCities.contains(city)) return;
    final weatherService = _weather();
    try {
      final snapshot = await weatherService.fetch(city);
      final now = _now().toUtc();
      final previous = <String, NotificationRecord>{};
      for (final trigger in notificationCategories) {
        final key = notificationKey(city, trigger);
        final time = _prefs.getString('notifications.last.$key');
        final parsed = time == null ? null : DateTime.tryParse(time);
        if (parsed != null) {
          previous[trigger] = NotificationRecord(
            parsed,
            _prefs.getString('notifications.fingerprint.$key') ?? '',
          );
        }
      }
      final preferences = await NotificationPreferences.load();
      final tips = selectNotificationTips(
        snapshot,
        now,
        previous,
        preferences: preferences,
      );
      if (tips.isEmpty || !await enabled()) return;
      // City may have changed while the network request was running.
      if ((_prefs.getString('selectedCity') ?? 'Muntinlupa') != city) return;
      await _initialize();
      final body =
          '${tips.map((t) => '${t.advice} ${t.reason}').join('\n')}\n'
          'Estimate ${weatherTime(snapshot.observedAt)}. Check official advisories.';
      await _plugin.show(
        id: weatherNotificationId,
        title: '$city weather tips',
        body: body,
        notificationDetails: weatherNotificationDetails(body: body),
        payload: jsonEncode({
          'city': city,
          'eventId': 'local-${now.millisecondsSinceEpoch}',
          'issuedAt': now.toIso8601String(),
          'route': 'alerts',
        }),
      );
      // Recheck after platform delivery to honour a concurrent opt-out.
      if (!await enabled() ||
          (_prefs.getString('selectedCity') ?? 'Muntinlupa') != city) {
        await _plugin.cancel(id: weatherNotificationId);
        return;
      }
      for (final tip in tips) {
        await _prefs.setString(
          'notifications.fingerprint.${notificationKey(city, tip.id)}',
          notificationFingerprint(snapshot, tip, now),
        );
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
