# Weather push verification — 12 November 2026

The following is a historical record, not current deployment status. See
[current status](../DEPLOYMENT_STATUS.md) and the 14 November entry below.
Originally prepared on feature branch feat/free-weather-push; not deployed then.

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

## Runtime regression discovered during live setup

Owner enabled the schedule and logging, created the D1 table, and deployed the
Worker. The public health endpoint returned the expected JSON, but city rows had
no completed-check timestamps. Reproduced the HTTP failure in real local workerd:
Cloudflare rejects `redirect: "error"`, although Node accepts it. The shared adapter
failed before sending weather, OAuth or FCM requests.

Fix: use `redirect: "manual"` and continue rejecting all non-2xx responses. Two
new runtime regression tests fail on the old code and pass with the fix. Complete
backend suite now passes 14 tests. Direct Miniflare dependency is pinned to the
same runtime version already resolved by Wrangler; CI installs backend dependencies.
The config now preserves the owner's active cron and logs through Git deployments.
Post-fix live weather checks, FCM authentication and phone delivery still require
verification after the fix is merged and deployed.

## Notification reliability — 14 November 2026

Reviewed baseline: `2a131538024f13bfa84348651d5b72faa7aa87f9`. The approved
fixes cover transient push rejection, Android notification mode recovery,
safe monitoring diagnostics and current deployment documentation.

- Reproduced an explicit FCM HTTP 503 rejection consuming the one-hour reminder.
  New failing tests demonstrated lost history and ignored Retry-After values.
  The fix restores prior history and persists a minimum five-minute retry lease
  for 429/5xx, respecting bounded Retry-After. Uncertain timeout/response failures
  retain the hourly reservation. Expired owners cannot undo a newer send.
- Backend: `npm test --prefix backend` passes all 23 tests, including real SQLite,
  generated OAuth keys, retry/backoff, diagnostic redaction and workerd semantics.
- Flutter 3.47.9 / Dart 3.13.7: `flutter analyze --no-pub` reports no issues;
  `flutter test --no-pub --reporter expanded` passes all 111 tests. Six new
  startup/widget regressions cover persisted opt-in restoration at startup/resume,
  opt-out cancellation, denied/restored OS permission without prompting, offline
  legacy cleanup, an opt-out during registration and the local setup retry button.
  Tests replace only the native scheduler/host boundary; they do not prove actual
  Workmanager execution or FCM delivery on a phone.
- Model: `python -m unittest discover -s ml/tests -v` passes all seven tests.
- Web: `flutter build web --no-pub --no-web-resources-cdn` succeeds, including
  the Wasm compatibility dry run. No Android SDK or physical phone was available
  for a new native build in this environment; the PR's Android CI job must confirm
  compilation of the final revision.
- Independent read-only review found no Critical/Important issue. It independently
  reran all 23 backend tests. One minor diagnostic limitation remains: if releasing
  a lease also fails after an upstream failure, the release error supersedes the
  earlier error. Reporting both safely is deferred; database lease expiry still
  provides recovery. `git diff --check` passes.
- A read-only public `/health` request returned the expected service JSON. It is
  liveness evidence only. No Worker deployment, database change, live topic send,
  billing change or credential rotation was performed by this fix.

Remaining acceptance: merge/deploy the selected revision, confirm successful city
checks and FCM acceptance from sanitized logs, verify both signed Android build
mode transitions and foreground/background/cold-start delivery on a controlled
phone, and verify the historical credential's revocation in its provider account.
