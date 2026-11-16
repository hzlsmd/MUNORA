# Android readiness and cleanup — 16 November 2026

Reviewed master at `e8732d4`, including startup, city selection/persistence,
weather and insight caching/freshness, screen layouts, local/push notifications,
native manifest/build/signing configuration, dependencies and release guidance.

## Repairs

The default local-notification APK registered a running-app tap callback but never
read `getNotificationAppLaunchDetails`. Tapping an alert with MUNORA closed
therefore opened Home instead of Alerts for the notification's city. Startup now
initializes the local notification adapter and reads the launch details, including
when the saved opt-in is off. Existing payload validation and splash queuing route
valid notices; invalid/expired/test payloads stay on Home. Resume/settings retries
and background checks do not consume launch details again. Startup still does not
request notification permission. The optional push startup path is unchanged.

Five new native-channel widget scenarios cover opted-in/opted-out cold launch,
returning Home before resume (no replay), missing test payload, malformed payload
and an expired alert. The two valid-launch scenarios failed on the original code
because Alerts was absent, then passed with the repair. These tests mock the
native platform, not Android itself.

## Redundancy removed

- Removed `google_fonts`: app typography already uses declared local Inter and
  Abyssinica fonts, with no `GoogleFonts` font API calls. Removed its otherwise
  unused configuration in startup and tests, plus eight unused transitive
  packages and generated desktop JNI plugin entries.
- Removed five unused Poppins font files (787,036 bytes) and their exclusive
  license. Removed the broad root font-assets entry. Inter/Abyssinica fonts and
  their licenses remain declared; Cupertino font support is retained because
  framework rendering needs it.
- Corrected the release checklist's outdated claims about missing push/ML code,
  the former Firebase backend, demo weather and a removed dependency override.

The prior Tips consolidation remains intact. Forecast notices, experimental
three-hour rain probability, activity plans, and optional multi-model insights
answer different questions; their distinct thresholds and freshness rules remain.

## Verification

- Flutter 3.47.9 / Dart 3.13.7.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --concurrency=2`: all 165 tests passed, including the
  five new launch scenarios. Focused startup suite: all 11 passed.
- Backend: `node --test backend/test/*.test.mjs`, 31 passed.
- Model: `python -m unittest discover -s ml/tests -v`, 7 passed.
- One live request to Open-Meteo returned current weather and 144 hourly points.
- `flutter build web --no-pub --no-web-resources-cdn`: passed, including Wasm dry run.
- Native Android build is **blocked by this environment**, not verified as passing.
  The first attempt found a runtime-only Java installation without `JAVA_COMPILER`;
  installed Temurin JDK 17.0.21 and retried. The next attempt reached
  `:app:mergeDebugNativeLibs` but exhausted the 8 GB filesystem. Reclaiming unused
  tool resources and retrying still ended with `No space left on device`.
  No APK was produced, so installation, signature, packaged manifest/ABIs and
  actual Android launch remain unverified. Optional push APK compilation was
  not completed. Run the existing Checks workflow on a runner with sufficient
  disk before downloading/distributing its APK.
- Native logs also flag the existing firebase_core/workmanager Kotlin-plugin
  compatibility mode for future Flutter upgrades; this is separate from the
  current environment failures. The repository remains on its pinned SDK.
- Browser regression (`node tools/check_weather_tips.cjs`): passed at 390×844
  and 1366×900, six controlled provider calls per viewport and no page errors.
  Packaged fonts include Inter, Abyssinica, Material and Cupertino; Poppins is absent.
- Separate read-only code review found no actionable issues. No merge or live
  backend deployment was performed.

## Installing and accepting on a phone

Use the **default local-notification** `munora-android-debug` artifact from the
Checks run for the reviewed branch/PR once published. Extract the ZIP, transfer `app-debug.apk`, then allow its
installation from your download/files app. The configured Flutter minimum is Android 7.0/API 24
or newer; verify it in the produced APK before distribution. `munora-android-push-debug` is a separate optional configuration requiring
the coordinated backend rollout; it is not the default phone download.

Debug APKs are for prototype testing. Android requires the same signing certificate
for an update: if an older APK used a different debug key, install a consistently
signed build or uninstall the old copy first (uninstalling clears saved settings).
Production release variants require all four documented signing variables; this
review does not replace the owner's signing identity or publish a release.

Before treating your phone as accepted:

1. Open the app, complete the splash, load weather, and switch among Home,
   Forecast, Alerts and Tips. Change city, close/reopen and confirm it persists.
2. With saved weather, disconnect/reconnect Wi-Fi or mobile data. Confirm the
   saved/offline label and successful refresh; first install offline must show
   retry, not fabricated weather. Check readability with your normal font scale.
3. In Tips, enable Weather notifications, grant Android permission and send a
   test. Deny/revoke permission too; weather must remain usable. Restore permission
   and resume to restore background work.
4. Tap an actual recent weather alert with the app running and with its process
   closed. Verify Alerts opens for its city. A test notification has no alert route.
5. Check category selection, quiet hours, city changes, opt-out, reboot and battery
   restrictions using the [notification acceptance steps](../NOTIFICATION_FIX_2026-11-16.md).
   Local checks are approximate hourly work; Doze/OEM restrictions can delay them,
   and Android force-stop prevents ordinary work until the app is reopened.

No physical phone is connected here, and this environment has no `/dev/kvm` for
an accelerated Android emulator. Automated tests/builds cannot certify your
particular phone's background delivery. Push delivery also needs live backend/FCM
and device verification; a successful APK compilation alone does not establish it.
