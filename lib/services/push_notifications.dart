import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'push_state.dart';

/// Enable only in a build whose matching Firebase configuration is installed.
/// Deployment and phone acceptance must precede distributing that build.
class PushNotifications {
  static final instance = PushNotifications._();
  PushNotifications._();
  static bool get configured =>
      const bool.fromEnvironment('ENABLE_WEATHER_PUSH') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  static const enabledKey = 'notifications.weather.enabled';
  final status = ValueNotifier<String?>(null);
  final _local = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _queue = Future.value();
  Future<void> _displayQueue = Future.value();
  bool _ready = false;
  void Function(PushAlert)? onOpen;
  PushAlert? _pending;

  Future<void> _serialize(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'weather_tips',
      'Weather recommendations',
      channelDescription: 'Forecast-based guidance for the selected NCR city',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!configured) {
      await cleanupLegacyPush();
      return;
    }
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      final ready = await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_weather_notification'),
        ),
        onDidReceiveNotificationResponse: localTap,
      );
      if (ready != true) throw StateError('Notification initialization failed');
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'weather_tips',
              'Weather recommendations',
              description: 'Forecast-based guidance for the selected NCR city',
              importance: Importance.defaultImportance,
            ),
          );
      // Push mode replaces hourly local checks, including an older installed build.
      await Workmanager().cancelByUniqueName('munora.weather.tips.v1');
      _ready = true;
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          _displayQueue = _displayQueue
              .then((_) => _foreground(message))
              .catchError((Object _) {
                status.value =
                    'Unable to display the latest weather notification.';
              });
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((_) => retry()),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        localTap(launch!.notificationResponse!);
      }
      await synchronize();
    } catch (_) {
      status.value = 'Push setup could not be completed. Open notification settings to retry.';
    }
  }

  Future<bool> enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? false;
  }

  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      if (!_ready) throw StateError('Push configuration is not ready');
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        return false;
      }
    }
    // Persist opt-out even if an earlier network reconciliation is still pending.
    if (!await prefs.setBool(enabledKey, value)) {
      throw StateError('Preference save failed');
    }
    if (!value) {
      status.value = 'Notification cleanup is pending.';
      if (_ready) await _local.cancelAll();
    }
    if (!_ready) {
      status.value = 'Notification cleanup is pending. Retry when online.';
      throw StateError('Push cleanup is pending');
    }
    await synchronize().timeout(const Duration(seconds: 15));
    return enabled();
  }

  Future<void> cleanupLegacyPush() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getStringList(PushSubscriptions.knownKey) ?? []).isEmpty) return;
    try {
      await _serialize(() async {
        if (Firebase.apps.isEmpty) await Firebase.initializeApp();
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await PushSubscriptions(
          prefs,
          subscribe: FirebaseMessaging.instance.subscribeToTopic,
          unsubscribe: FirebaseMessaging.instance.unsubscribeFromTopic,
        ).reconcile(
          enabled: false,
          city: prefs.getString('selectedCity') ?? 'Muntinlupa',
        );
        await FirebaseMessaging.instance.deleteToken();
        status.value = 'Previous push subscriptions removed; this build uses local notifications.';
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      status.value =
          'Previous push subscription cleanup is pending. Retry when online.';
    }
  }

  Future<void> synchronize() => _serialize(() async {
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await _sync(prefs);
  });

  void retry() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(
      refresh().catchError((Object _) {
        status.value = 'Notification subscription is pending. Check your connection and retry.';
      }),
    );
  }

  Future<void> refresh() => _ready ? synchronize() : initialize();

  Future<void> _sync(SharedPreferences prefs) async {
    try {
      final desired = prefs.getBool(enabledKey) ?? false;
      final permission = await FirebaseMessaging.instance
          .getNotificationSettings();
      final allowed =
          permission.authorizationStatus == AuthorizationStatus.authorized;
      final active = desired && allowed;
      if (active) await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await PushSubscriptions(
        prefs,
        subscribe: FirebaseMessaging.instance.subscribeToTopic,
        unsubscribe: FirebaseMessaging.instance.unsubscribeFromTopic,
      ).reconcile(
        enabled: active,
        city: prefs.getString('selectedCity') ?? 'Muntinlupa',
      );
      if (!active) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      }
      status.value = desired
          ? (allowed
                ? 'Push notifications enabled for ${prefs.getString('selectedCity') ?? 'Muntinlupa'}. Reminders at most once an hour per condition.'
                : 'Notifications are blocked in Android settings.')
          : 'Push notifications are off.';
    } catch (_) {
      status.value = 'Subscription change is pending. Previously subscribed city alerts may continue until cleanup succeeds. Retry when online.';
      rethrow;
    }
  }

  Future<void> _foreground(RemoteMessage message) async {
    final alert = PushAlert.parse(message.data, DateTime.now());
    if (alert == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool(enabledKey) ?? false) ||
        (prefs.getString('selectedCity') ?? 'Muntinlupa') != alert.city ||
        prefs.getString('push.lastEvent') == alert.eventId) {
      return;
    }
    await _local.show(
      2401,
      '${alert.city} weather update',
      message.notification?.body ??
          'Review forecast-based weather guidance in Alerts.',
      details,
      payload: jsonEncode(message.data),
    );
    await prefs.setString('push.lastEvent', alert.eventId);
  }

  void localTap(NotificationResponse response) {
    try {
      final data = jsonDecode(response.payload ?? '');
      if (data is Map<String, dynamic>) _open(data);
    } catch (_) {
      /* Local test and old notifications have no weather payload. */
    }
  }

  void _open(Map<String, dynamic> data) {
    final alert = PushAlert.parse(data, DateTime.now());
    if (alert == null) return;
    if (onOpen != null) {
      onOpen!(alert);
    } else {
      _pending = alert;
    }
  }

  void attach(void Function(PushAlert) callback) {
    onOpen = callback;
    final pending = _pending;
    _pending = null;
    if (pending != null) callback(pending);
  }
}
