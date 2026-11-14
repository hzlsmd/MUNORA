# Android weather notifications

## New optional server push mode

See [free push deployment](setup/DEPLOY_WEATHER_PUSH.md). The optional Android
`ENABLE_WEATHER_PUSH=true` build uses Cloudflare/D1 and Firebase Messaging city
topics. Each city is checked every five minutes; the same active condition can
remind after one hour. The public Worker health route responds, but end-to-end
processing and real-device delivery remain unverified; see
[current deployment status](DEPLOYMENT_STATUS.md).
The button labelled "Send test notification" tests local display, not remote push.

The historical implementation notes below describe the default local mode.
Current local and push policies use one-hour suppression; historical verification
counts are not evidence for the new implementation.

## Design and implementation plan

Use flutter_local_notifications for Android permission/channel/display and workmanager for network-constrained hourly checks. This follows the existing no-login/no-paid-backend decision. Remote push would require server operations; foreground-only notices would not cover a backgrounded app.

- [x] Add a tested notification policy: fresh weather only, rain/storm/heat/wind only, per-city one-hour repeat suppression, no routine/stale notifications.
- [x] Add Android local notification delivery and persistent opt-in, permission denial/error handling, opt-out cancellation and selected-city background checks.
- [x] Add a Tips toggle and test notification command. Request OS permission only after opt-in.
- [x] Verify unit/widget tests, analysis and release web build; document native test limitations.

One notification groups qualifying tips and replaces the previous weather-tip notification. Its text identifies the city and estimate time. It is general advice, not an official warning. Notification taps open the app normally; no user account or push token is created. Preferences hold only opt-in and last-shown times. Use the selected city stored by the existing picker, defaulting to Muntinlupa.

Background jobs fetch fresh weather rather than alerting from saved/offline data. Check frequency is approximate: Doze, battery restrictions, OEM limits and force-stop can prevent/delay delivery. No exact alarms or foreground-service permission is needed. Android 13+ asks POST_NOTIFICATIONS; older versions still respect system channel settings. Other platforms retain the weather app with notifications unavailable.

Settings remain available even when weather loading fails. If Android permission or channel access is disabled later, background work stays silent; use Android notification settings to restore permission or turn off the app toggle. A persisted opt-in is not a guarantee that Android will deliver a notification.

Startup and resume restore the local periodic job from the saved opt-in, using
keep semantics to preserve an existing job's cadence. This repairs updates from
a push build, which previously cancelled local checks. Startup never requests OS
permission. When OS notification permission is denied, local work is cancelled;
restoring permission and resuming the app repairs it. Legacy push cleanup runs
after local scheduling, so offline Firebase does not prevent restoring the job.
The settings retry control retries the build's active notification mode.

The plugin is constrained to the 19.x release line, whose documented Android compileSdk floor is 35, compatible with this project's Flutter/SDK setup. The current 23.x plugin requires compileSdk 37. Reassess that constraint when upgrading the Android toolchain. Java 17 is retained and core-library desugaring is enabled as required by the plugin. A white drawable icon is explicitly retained for release shrinking. No exact scheduled-notification receivers are added because WorkManager performs the weather checks and notifications are displayed immediately.

## Phone verification required

Build a new APK, allow notifications from Tips, send a test, inspect city/content/channel icon, deny permission and retry, disable and confirm notifications/jobs are cancelled, change city and verify the next check uses it, and test app background/resume and restricted battery settings. Verify duplicate suppression across restarts and no notifications from offline/expired data. Native compilation and actual background scheduling must be checked on Android before claiming phone delivery is validated.

## Verification record

- 41 Flutter tests pass (36 existing plus 5 policy/preference tests). New policy tests cover stale/routine silence, rain advice, per-city repeat windows and clock rollback. Service tests cover default opt-out, persisted disablement and unsupported platforms.
- Flutter analysis reports no issues. Release web build succeeds. git diff --check passes.
- The first policy test run failed because the implementation was absent. The first full suite exposed the switch's missing Material ancestor; fixing it restored the existing Tips and 320px/2x-text regressions without weakening assertions.
- A separate self-review checked preference consistency across isolates, selected-city races, opt-out rechecks, plugin SDK requirements, release icon retention and background entry-point retention. There was no independent subagent reviewer.
- Native adapter permission/channel calls, WorkManager execution, release APK compilation, and real notification delivery are NOT verified by these Dart/widget tests. No production deployment, Firebase setup, signing-key access or actual phone notification was performed.
