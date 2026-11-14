import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:munora/main.dart' as app;
import 'package:munora/services/notification_service.dart';
import 'package:munora/services/push_notifications.dart';
import 'package:munora/services/push_state.dart';
import 'package:munora/widgets/notification_settings.dart';

// Only the native scheduler is replaced. App startup, preferences, mode selection
// and notification plugin calls run through their production implementations.
class RecordingScheduler extends WorkmanagerPlatform {
  final jobs = <String, Duration?>{};
  final policies = <ExistingPeriodicWorkPolicy?>[];
  final cancelled = <String>[];
  bool initialized = false;
  bool failRegistration = false;
  Completer<void>? registrationGate;
  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    initialized = true;
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    if (!initialized) throw StateError('Scheduler must be initialized');
    if (failRegistration) throw StateError('Native scheduler unavailable');
    await registrationGate?.future;
    if (taskName != 'munora.weather.tips.v1' ||
        constraints?.networkType != NetworkType.connected) {
      throw StateError('Unexpected weather task contract');
    }
    jobs[uniqueName] = frequency;
    policies.add(existingWorkPolicy);
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    jobs.remove(uniqueName);
    cancelled.add(uniqueName);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const firebaseChannel =
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore';
  late RecordingScheduler scheduler;
  late WorkmanagerPlatform original;
  late List<String> platformCalls;
  bool permission = true;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'notifications.weather.enabled': true,
    });
    PushNotifications.instance.status.value = null;
    Workmanager(); // Let the plugin choose its host before replacing that host.
    original = WorkmanagerPlatform.instance;
    scheduler = RecordingScheduler();
    WorkmanagerPlatform.instance = scheduler;
    platformCalls = [];
    permission = true;
    binding.defaultBinaryMessenger.setMockMessageHandler(
      firebaseChannel,
      (_) async => const StandardMessageCodec().encodeMessage([
        'offline',
        'Unavailable',
        null,
      ]),
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      platformCalls.add(call.method);
      if (call.method == 'initialize') return true;
      if (call.method == 'areNotificationsEnabled') return permission;
      if (call.method == 'requestNotificationsPermission') {
        throw StateError('Startup must never prompt for permission');
      }
      return null;
    });
  });

  tearDown(() {
    WorkmanagerPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    binding.defaultBinaryMessenger.setMockMessageHandler(firebaseChannel, null);
    PushNotifications.instance.status.value = null;
  });

  Future<void> start(WidgetTester tester) async {
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  void androidTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  androidTest(
    'local startup restores a persisted opt-in after push cancelled its job',
    (tester) async {
      await start(tester);
      expect(scheduler.jobs, {
        'munora.weather.tips.v1': const Duration(hours: 1),
      });
      expect(scheduler.policies, [ExistingPeriodicWorkPolicy.keep]);
      expect(platformCalls, isNot(contains('requestNotificationsPermission')));
      expect(await NotificationService().enabled(), isTrue);

      // Resume repairs a missing job too, using keep rather than resetting its timer.
      scheduler.jobs.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(scheduler.jobs, {
        'munora.weather.tips.v1': const Duration(hours: 1),
      });
      expect(scheduler.policies.last, ExistingPeriodicWorkPolicy.keep);
    },
  );

  androidTest('local startup cancels leftover work when opted out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'notifications.weather.enabled': false,
    });
    scheduler.jobs['munora.weather.tips.v1'] = const Duration(hours: 1);
    await start(tester);
    expect(scheduler.jobs, isEmpty);
    expect(scheduler.cancelled, contains('munora.weather.tips.v1'));
    expect(platformCalls, isNot(contains('requestNotificationsPermission')));
  });

  androidTest(
    'denied OS permission stays silent and restored permission resumes local checks',
    (tester) async {
      permission = false;
      await start(tester);
      expect(scheduler.jobs, isEmpty);
      expect(scheduler.cancelled, contains('munora.weather.tips.v1'));
      expect(await NotificationService().enabled(), isTrue);
      permission = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(scheduler.jobs, contains('munora.weather.tips.v1'));
      expect(platformCalls, isNot(contains('requestNotificationsPermission')));
    },
  );

  androidTest(
    'offline legacy cleanup does not prevent restoring local delivery',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'notifications.weather.enabled': true,
        PushSubscriptions.knownKey: ['munora_weather_manila'],
      });
      // No Firebase native host: real cleanup reports a pending platform failure.
      await start(tester);
      expect(scheduler.jobs, contains('munora.weather.tips.v1'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(
        PushNotifications.instance.status.value,
        contains('cleanup is pending'),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PushSubscriptions.knownKey), [
        'munora_weather_manila',
      ]);
    },
  );

  androidTest(
    'opt-out during native startup registration cancels the late job',
    (tester) async {
      final gate = scheduler.registrationGate = Completer<void>();
      await start(tester);
      await NotificationService().setEnabled(false);
      gate.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(scheduler.jobs, isEmpty);
      expect(await NotificationService().enabled(), isFalse);
    },
  );

  androidTest(
    'local setup failure can be repaired from notification settings',
    (tester) async {
      scheduler.failRegistration = true;
      await start(tester);
      expect(
        PushNotifications.instance.status.value,
        contains('Local weather notification setup is pending'),
      );
      scheduler.failRegistration = false;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationSettings())),
      );
      await tester.pumpAndSettle();
      // A pending local setup must retry the local job, rather than only Firebase.
      await tester.tap(find.text('Retry notification setup'));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(scheduler.jobs, contains('munora.weather.tips.v1'));
    },
  );
}
