# Weather push verification — 12 November 2026

Prepared on feature branch feat/free-weather-push; not deployed.

- Backend: 12 Node tests pass using real SQLite for D1 statements and generated
  ephemeral cryptographic keys for OAuth signing. Includes expired-owner duplicate
  reproduction (failed with 2 sends; fixed to 1), freshness/units/forecast validation,
  one-hour reminders, overlapping cron, failed sends, public-route denial and payload.
- Flutter: full suite passes 84 tests, including default-build migration cleanup. Subscription tests exercise uncertain subscribe cleanup
  and failed unsubscribe; foreground refresh pauses in background and resumes.
- Flutter analysis: no issues (Flutter 3.47.9 / Dart 3.13.7).
- Release web build succeeds on the final source (232.5 seconds).
- Wrangler dry-run succeeds with the existing DB binding and no embedded secret.
- Android debug APK attempted with ENABLE_WEATHER_PUSH=true: blocked by no Android
  SDK in this execution environment. Plugin/Gradle native compilation remains
  unverified. No phone delivery or foreground/background native plugin test occurred.
- Remote Worker still serves Hello World. No schema was applied, no source deployed,
  no cron enabled, no live FCM send attempted and no billing enabled by Codex.
- Owner reports DB binding and FCM secret saved; Codex has not read the secret or
  verified remote binding/credential contents.

Independent review identified expired lease writers, startup waiting on network,
and legacy subscriptions in local-mode builds. Fixes fence lease owners, launch UI
before push network setup, and retry legacy cleanup. Foreground message handling is
serialized. Native scenarios and actual Free CPU limits still need acceptance.

Operational choices: reserve cooldown before sending to avoid duplicates after an
ambiguous timeout (can postpone a failed send until the next hour); split cities
across five minute slots (can wait five minutes before the first city check).
FCM topic/normal-priority transport does not guarantee immediate delivery. Never
label these automated model-based notices as official warnings or trained AI.
