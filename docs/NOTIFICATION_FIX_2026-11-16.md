# Weather recommendation notification repair — 16 November 2026

This change addresses the user's first reported issue: real Android weather
notifications. Offline caching, Home imagery and broader AI changes remain
separate follow-ups. Notifications are deterministic weather rules, not AI text.

## Findings and changes

The source already contained notification permission handling, a white small icon,
local WorkManager scheduling, persistent opt-in and optional Firebase push. Their
existence did not establish successful delivery on the tested phone. That phone's
installed build, OS/channel settings, scheduler state and backend credentials have
not been inspected here.

Code-level defects and gaps addressed:

- Reusing a notification ID with `onlyAlertOnce: true` could prevent later alerts
  from attracting attention while the previous notification stayed visible.
  Deduplication now happens before posting; a qualifying new event can alert.
- Local channel creation was deferred to posting. Initialization now explicitly
  creates the existing stable channel, including in the worker.
- Local bodies contained tip titles rather than the advice. Expanded notifications
  now include actionable advice, evidence, city and estimate time. Local tap
  payloads use the existing Alerts routing contract.
- Upcoming heat/wind were absent from the core forecast records. Provider requests
  now include hourly apparent temperature, wind, rain probability and UV. Optional
  fields are unit/range validated; missing readings stay unknown. Existing cache
  records still parse. Rules examine the next six hours as well as current data.
- Unchanged conditions previously reminded hourly. Persistent fingerprints now
  distinguish coarse weather changes, with a one-hour per-category minimum and a
  12-hour unchanged-condition reminder interval. Cities have separate histories;
  clock rollback remains quiet. Clear-weather suggestions are optional/daytime.
- Preferences now persist category toggles and configurable quiet hours in PHT.
  Quiet hours include hazardous-weather advice; equal endpoints disable the quiet
  period. These are weather tips, not an official emergency alert service.
- A city change during native posting now cancels the previous-city notification.
  Opt-out is checked before and after posting. Tests cover both race paths.
- The worker initializes Flutter/plugin bindings and asks WorkManager to retry
  failures with exponential backoff, initially 15 minutes for newly registered
  jobs. Existing unique work keeps its enqueue schedule. There is no competing
  foreground fetch when enabling: WorkManager's first run has no initial delay,
  although Android decides when it actually executes.

## Optional Firebase delivery

Previously, the server sent notification payloads for Android to display directly.
That bypasses Dart category/quiet-hour checks when the app is closed. Updated
clients subscribe to `munora_weather_<city>_v2`. Version 2 messages contain bounded,
validated data; both foreground and background entry points initialize the local
plugin/channel and apply preferences, city checks and persistent deduplication.
High priority is reserved for weather precautions; clear suggestions use normal
priority. FCM and Android can still delay or drop messages.

Foreground and Firebase background engines have different Dart isolates. A small
SQLite database uses a transaction to arbitrate a shared delivery lease before
reading/writing notification history, preventing overlapping senders from both
passing the preference/history checks. Leases expire after two minutes following
an interrupted process; owner-checked release cannot erase a newer lease. SQLite
BUSY/LOCKED means retry acquisition, not bypass it. Same-isolate calls are also
queued. Only one lease row is retained; weather data stays in the existing store.

The backend continues sending the legacy OS-rendered format to the original
city topic for old installed clients, limited to their original four categories.
Updated clients unsubscribe the old topic before joining v2, so they receive only
one format. Failed unsubscribe remains pending and is retried before subscribing.
Existing server claims/backoff bound retries and uncertain FCM sends.

Deploy the updated backend **before** distributing a push-enabled APK. Until that
rollout happens, use the default local build:

```sh
flutter pub get
flutter build apk --debug
```

For the coordinated push rollout, use the existing deployment runbook, verify
server credentials/cron/FCM delivery, then build with
`--dart-define=ENABLE_WEATHER_PUSH=true`. CI now publishes `munora-android-debug` in default local mode and separately
compiles/publishes `munora-android-push-debug`. Only the latter requires the
corresponding backend update. This removes the old mismatch in which the primary
CI APK silently enabled push despite the documented default being local delivery. No
production deployment or live topic broadcast was performed by this change.

## Files and dependencies

- Delivery: `notification_service.dart`, `notification_config.dart`,
  `notification_policy.dart`, `notification_preferences.dart`.
- Push: `push_notifications.dart`, `push_state.dart`,
  `push_recommendations.dart`, `notification_delivery_gate.dart`.
- Weather inputs/rules: `open_meteo.dart`, `weather_snapshot.dart`,
  `weather_recommendations.dart`, `weather_alerts.dart` (including the UV notice opened after a notification tap).
- Settings: `notification_settings.dart`. CI: `.github/workflows/checks.yml`.
- Backend: `worker.mjs`, `weather.mjs`, `fcm.mjs`.
- Regression tests cover policies, native display arguments, scheduler restoration,
  preferences, concurrent display, SQLite claims, old-topic migration and payloads.
- Add direct dependency `sqflite` for the shared delivery lease and development
  dependency `sqflite_common_ffi` to exercise actual SQLite transactions in tests.
  Platform registration/lockfile are updated. No new Android permissions, exact
  alarms, foreground services, location access or SDK target changes are required.

## Device acceptance

Automated plugin-channel tests verify calls and contents; they cannot prove Android
notification display, sound, background execution, or real FCM delivery.

1. Install the matching signed APK (a debug APK may not replace a differently
   signed installation). Confirm whether it is local or push mode in settings.
2. Deny Android 13+ permission, enable notifications, and verify no alerts and a
   useful permission message. Grant permission in Android settings; reopen/retry.
3. Enable weather notifications and use **Send test notification**. This tests
   local permission/channel/display only, not weather fetching or remote FCM.
4. Inspect the Weather recommendations channel, small icon, expanded advice,
   sound/vibration settings and Alerts tap behavior. Test a blocked channel too.
5. With network available, allow a real scheduled check. Verify weather advice
   against the displayed city/provider estimate. For local diagnostic forcing,
   inspect `adb shell dumpsys jobscheduler` for this package and run the identified
   job with `adb shell cmd jobscheduler run -f com.example.munora <job-id>`.
   This is a diagnostic trigger, not a production exact-time guarantee.
6. Repeat unchanged data, restart the app and force another check: history should
   suppress a repeat. Test a different category and a significant change after
   cooldown. Enable clear suggestions separately; test quiet-hour boundaries.
7. Switch city and disable notifications during updates; confirm old-city/opt-out
   notifications are cancelled. Re-enable to restore work. Check app background,
   swipe-away, Doze, reboot and OEM battery restrictions. Force-stop prevents
   ordinary background delivery until Android permits the app to run again.
8. Disconnect network: no new local weather alerts should be generated from cached
   data. Reconnect and allow scheduled work. Push payloads also reject expired
   issue/estimate timestamps. Do not expect alerts during every short outage.
9. For v2 push, verify cron/OAuth/FCM acceptance and actual background delivery on
   the phone, plus v1-to-v2 subscription cleanup. Server health alone is insufficient.

Verification results are recorded in the implementation report/PR once the final
checks finish. No physical Android device is connected to this environment.
