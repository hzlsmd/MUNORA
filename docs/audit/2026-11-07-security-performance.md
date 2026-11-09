> Historical record: the Firebase backend and its performance probe were removed from the repository on 9 November 2026. This document describes the earlier implementation.

# MUNORA security and performance audit

Date: 7 November 2026. Baseline: `47658457598b168688b8e19ee221364e63e4fcd0`.
Scope: current repository and focused hardening, not the proposed future system.

## Executive assessment

The project is a capstone prototype, not ready to claim operational warning,
predictive-model or production push-notification capability. No critical
unauthorized Firestore data-access path was found in the current source. The
significant risks were exposed historical credentials, a potentially billable
public backend, unsafe release signing, unbounded/unvalidated weather data,
stale/racing cache publication, vulnerable dependencies, and misleading demo
confidence. Most code-level findings were hardened; release/owner prerequisites
below remain. No billing was enabled and no application/function/rule deployment
or destructive history change was performed during this audit.

This is an evidence-based code audit, not a guarantee that no vulnerabilities
exist. A dependency scan is not equivalent to a demonstrated remote exploit.

## Coverage and evidence boundaries

Reviewed Flutter app/services/models/widgets/screens/tests, all Node backend
modules, Firestore rules/config, dependency manifests/locks, CI, Android build
and manifest, Apple entitlements/plists, web bootstrap/manifest, repository
ignore policy and targeted secret-history patterns. Platform runner templates
contain no additional application auth/storage logic. Binary artwork/fonts were
inventoried; font license is present, but binary supply-chain forensics was not
performed. Third-party SDKs, operating systems, Firebase internals and weather
provider infrastructure were not independently audited.

Read-only parallel reviews covered backend and Flutter domains. A separate
whole-change reviewer was requested after implementation. Tests use fixture
weather and an in-memory Firestore transaction boundary. No load traffic was
sent to Firebase/OpenWeatherMap and the exposed key was not tested or reused.
No claim of measured native-device speed, real Firestore contention, cloud IAM
hardening or real provider availability is made.

The earlier setup verified Standard/Native Firestore in `asia-southeast1` and
deployed deny-all rules. This audit reviewed their source without redeploying.
Local Firebase CLI credential-cache permissions were checked as metadata only:
directories 0700 and credential file 0600; contents were not printed/read for
this audit. These files are outside the repository and should remain private.

## Components, flow and trust boundaries

The Flutter screens consume `WeatherView`, which owns screen lifecycle/error
states and calls the app-owned `WeatherService`. It reads a city-keyed public
snapshot from preferences, validates it, and requests the configured HTTPS
endpoint. Same-city requests share one operation. The service validates the
bounded response before caching; the widget ignores obsolete city responses.
No resident account, password, session, access token or refresh token is stored.

The optional Functions entry point checks its enable flag and verifies an
`X-Firebase-AppCheck` token before Firestore work. App Check attests an app/client,
not a user's identity; **the current Flutter client does not send that token**.
The handler validates the method, origin and allowlisted city, then hashes the
platform-provided IP with HMAC for rate accounting. It serves validated fresh
cache or obtains a fenced refresh lease, checks shared outage controls, reserves
the daily refresh budget, and fetches current/forecast data from fixed provider
URLs. A transaction publishes only valid, non-older data owned by that lease.
App Check verification and Cloud IAM are different boundaries; Admin SDK writes
bypass Firestore client rules by design.

The provider key is read only from the server's configured secret binding and
is sent in the provider request query, never in the client DTO or error response.
The same key currently supplies the HMAC rate-identity secret; rotating it resets
those pseudonymous identities. Cloud secret access, IAM and provider access logs
still require owner review. No raw IP or resident login token is written by the
application code. App Check tokens are verified, not persisted by this handler.
Local preferences are not encrypted and must not be extended to credentials.

## Findings and implementation state

| ID | Severity | Finding / trigger | Mitigation and residual state |
| --- | --- | --- | --- |
| SEC-01 | High | Provider API key is present in public Git history (`1244f8c`, `lib/services/weather_service.dart`). | Current source contains no literal provider credential. **Owner action remains:** revoke the old key; deleting source does not revoke it. History rewrite was not authorized or performed. |
| SEC-02 | High if deployed | Anonymous valid requests could cause function invocations and Firestore transactions even after IP/provider limits. CORS and `maxInstances` are not spending caps. | Backend defaults disabled; enabled requests must verify App Check before database work. No backend deployment is supported by this PR: separate client integration and owner cost approval must land first. Setup no longer offers an incomplete deployment path. Invocation costs, replayed valid tokens and distributed abuse are not fully eliminated. |
| SEC-03 | High release risk | Android release build used debug signing; the initial replacement relied on task-name heuristics. | Removed fallback and task-name hooks. Release signing config is created only with complete credentials; AGP disables release variants before task creation otherwise. Debug stays available by configuration. Native SDK/variant/signing verification remains a merge gate; this environment cannot run it. No signing key was generated. |
| SEC-04 | Moderate | npm initially reported nine affected packages through an obsolete `uuid` dependency chain. | Updated Firebase Admin/Functions and a targeted rimraf override; final scan reported zero known advisories. Major SDK/utility changes passed Node 22 tests and export smoke checks; deployed compatibility remains unverified. |
| SEC-05 | Moderate | Both client and provider paths buffered unbounded JSON and accepted oversized forecasts/conditions. | Streamed 128 KiB caps, at most 40 samples, condition length 120, cancellation and bounded cache decoding. Oversized input cannot replace a good saved snapshot. |
| SEC-06 | Moderate | Humidity/wind/pressure, timestamp age, forecast ordering and range consistency could be invalid yet display as successful weather. | Finite plausible measurements, explicit timestamp-zone parsing, live age/skew checks, future forecast coverage, offline limits, sorting and duplicate rejection. Forecast expiry is rechecked over time. Provider data is still a third-party estimate, not a validated local sensor reading. |
| SEC-07 | Moderate | Separate instances could refresh the same city and older or malformed privileged cache results could defeat valid refreshes. | Persisted refresh ownership/fencing, atomic publication, validation of previous and final returned data, and observation/update ordering. Adapter tests cover invalid cache and ownership expiry; real Firestore concurrency remains a release test. |
| SEC-08 | Moderate | Provider failure immediately allowed repeated budget reservation, potentially exhausting all cities' daily quota. | Persisted shared escalating backoff for transport/5xx/data failures (60 seconds up to 15 minutes), at least five minutes for auth/quota errors, and one cross-city recovery probe. Retry-After reflects the persisted delay. Attempts still count; no hidden budget increase. |
| SEC-09 | Moderate reliability | Timeout did not cancel the client transport; navigation and refresh repeated same-city work. | Abortable requests, disposal/timeout signals, per-city in-flight sharing and ten-minute fresh reuse; explicit refresh bypasses reuse. A shared request may continue after an individual screen closes until it completes or its 25-second bound, since the service belongs to the app. |
| SEC-10 | Moderate integrity | An expired saved snapshot could remain visible, and storage failure could block all updates. | Revalidate saved data on load/resume and periodic age checks; discard expired data, label saved data, keep network path available on storage errors. |
| SEC-11 | Moderate usability | Home forecast cards and opened picker/AI/chat headers overflowed at 320px width and 2x text scaling. | Flexible headers, constrained scrollable picker, scale-aware cards and content-driven forecast rows; interactive regression widgets pass at those dimensions. Screen-reader focus, keyboard/safe areas and other scales/localizations still need review. |
| SEC-12 | Moderate safety | Demo AI advertised an unsupported 85% confidence value. | Replaced numeric claim with "Not evaluated" and retained demo notices. No trained model or official hazard integration is implied. |
| SEC-13 | Low | Demo chat retained unlimited input/history, scheduled overlapping replies, leaked its controller and rejected valid emoji input. | Input limited to 1,000 displayed characters consistently with its counter, history 40 messages, one pending response, cancellable timer and disposed controller. Demo messages remain local/in memory. |
| SEC-14 | Low / release availability | macOS sandbox lacked outbound client networking entitlement. | Added `network.client` to debug/profile and release entitlements; signed Mac verification remains untested. |
| SEC-15 | Low supply chain | CI actions used movable tags, SDK floated with stable, and no audit gate existed. | Verified action commit pins, Flutter 3.47.9 pin, bounded job runtime/concurrency, npm audit gate, install scripts disabled in CI, weekly dependency update configuration. Update pins deliberately; pinned dependencies can age. |
| SEC-16 | Low credential hygiene | Root secret/signing filenames lacked comprehensive ignore patterns. | Added environment/key/service-account exclusions. Ignore rules do not detect every possible secret or remove anything already tracked. |

Source entry points for fixes: `functions/weather.js`, `functions/validation.js`,
`functions/store.js`, `functions/index.js`, `lib/services/weather_service.dart`,
`lib/models/weather_snapshot.dart`, `lib/widgets/weather_view.dart`, screen files,
Android Gradle/manifest, macOS entitlements, and `.github/workflows/checks.yml`.
See the regression tests named below for executable triggers.

## Existing controls retained

- No resident password, account, access/refresh-token or session-cookie flow exists.
  That is appropriate for public weather; adding login is not the remediation.
- Firestore client reads/writes are denied globally. Create/update bypass,
  self-assigned roles and unbounded direct-client writes are not possible under
  these rules. [Structured rules assessment](firestore-rules-assessment.json):
  5/5 for the current architecture, not an IAM certification.
- Provider URLs and city coordinates are server-owned and allowlisted. Callers
  cannot choose arbitrary provider URLs, file paths, database keys or commands.
  No caller-controlled SSRF path was identified.
- HTTPS is required by the Flutter endpoint configuration; embedded credentials
  and fragments are rejected and redirects disabled. Android explicitly forbids
  cleartext traffic. iOS has no broad ATS exception in the checked plist.
- UI weather strings use Flutter Text, not an HTML/script interpretation sink.
  No SQL/query-building path or command execution from app input was found.
- Provider failures remain generic; exception URLs and secret values are not
  returned. API keys belong only to the dormant server's secret binding.
- Local preferences hold city/public weather, not sensitive credentials. Source
  timestamps, stale labels and demo notices remain visible.

## Performance measurements

Environment: Linux cloud execution, Flutter 3.47.9/Dart 3.13.7, Chromium headless;
Node 22 functional suite and Node 24.22.1 in-process microbenchmark. Values below
are one controlled measurement per browser viewport, not a statistical field
study. Both builds use local rendering assets and locally fulfilled weather.

| Browser fixture metric | Baseline | Hardened |
| --- | --- | --- |
| Weather visible, 390x844 | 4,662 ms | 1,409 ms |
| Weather visible, 1366x900 | 4,747 ms | 1,515 ms |
| Requests after Home -> Forecast -> Home -> change city | 4 | 2 |
| Requests after additional failed manual refresh | 5 | 3 |
| Page errors in each measured workflow | 0 | 0 |

The primary startup improvement is removing the artificial three-second splash
timer; a first splash frame remains. The request reduction is from shared/fresh
weather reuse, not reduced provider freshness. Offline fallback was checked after
an explicitly failed refresh and remains clearly marked. Screenshots were
visually inspected at phone and desktop sizes; 320px/2x text is separately covered
by widget tests.

The 40-point backend fixture microbenchmark measured 57.99 ms initial handling,
0.040 ms warm median and 0.149 ms warm p95 over 1,000 cache hits. A burst of 100
same-city requests issued two provider-fixture calls and one cache write (one
refresh) in 5.55 ms. Serialized response was 3,773 bytes. These timings exclude
all real Firestore, network, provider, App Check and cold-cloud-runtime latency.
Rate-limit and cache reads still occur in the adapter boundary on each accepted
request; the microbenchmark is not evidence of low Firestore billing.

Web output is approximately 41 MiB on disk, including about 37 MiB of rendering
engine alternatives, not all fetched by a browser. Poppins assets occupy about 792 KiB.
Serve appropriate compression and immutable versioned assets at the eventual
host. After final-review fixes, `main.dart.js` measured 2,533,803 bytes raw /
751,176 bytes gzip. No claim of a 41 MiB user download or native APK size is made.

## Verification and reproduction

Baseline: 10 backend tests / 8 Flutter tests passed before adding regression
tests. New invalid-input, outage/store, coalescing, stale data, accessibility,
chat and splash tests were observed failing before their fixes.

Commands (from repository root):

```sh
npm --prefix functions ci --ignore-scripts
npm --prefix functions test
npm --prefix functions audit --audit-level=moderate
flutter pub get
flutter test
flutter analyze
flutter build web --no-web-resources-cdn --dart-define=WEATHER_API_URL=https://weather.example.invalid/weather
node tools/performance_backend.mjs
```

The example endpoint is deliberately non-live; browser tests fulfill its requests
with fixtures. `tools/browser_performance.cjs` requires Playwright/Chromium plus
two local HTTP servers for baseline/hardened builds (default ports 8080/8081).
Environment variables `MUNORA_BASELINE_URL`, `MUNORA_HARDENED_URL` and
`MUNORA_AUDIT_OUTPUT` configure the fixture check. Artifacts default to `build/audit`.
Do not point fixture load probes at public services.

Final verification: 22 backend tests on Node 22, 25 Flutter tests, analysis with
no issues, release web build success, zero npm audit advisories, valid Android
XML/Apple plist syntax, zero errors in four browser workflows, and a clean
whitespace check. Returned Dart package metadata reported no affected locked
packages; that is not an exhaustive independent vulnerability database audit.
The independent review found three important integrity/outage defects and two
UI/input gaps; all five received regression tests and fixes in one final pass.
The reviewer did not independently rerun Flutter/Node 22/cloud/native checks;
the main implementer ran the final local suites. Full rulings and limits are in
the [implementation ledger](implementation-ledger.md).

## Open risks and release prerequisites

1. Revoke the historical provider key. Revocation status is unknown.
2. The optional paid backend is intentionally unusable until enabled and App
   Check is integrated; this client integration was not added. The user's
   no-paid-cloud provider/sender migration remains a separate proposed design.
3. Billing was not activated; there is no deployed live-weather endpoint. The
   app remains a prototype and requires backend/provider configuration to run live.
4. App Check cannot prevent all valid-client abuse or token replay and does not
   bound Cloud Function invocation charges. IPs may be shared and platform proxy
   identity behavior must be verified after an authorized deployment.
5. The default 1,000-refresh budget cannot support a ten-minute cadence for all
   17 cities continuously (17 x 144 = 2,448 refreshes/day). Configure a deliberate
   traffic/freshness budget before any paid deployment; don't silently raise it.
6. Firestore `expiresAt` requires a configured TTL policy; without one, rate,
   budget and cooldown documents accumulate. TTL is not a security rule and
   cannot be assumed enabled from the field name.
7. Real Firestore transactional contention, SDK 14 deployment compatibility,
   provider errors and credentials, cloud IAM and log retention remain untested.
8. Android release signing/package creation, physical Android/iOS behavior,
   APNs credentials, Mac signed entitlement checks and native resource profiling
   need the team's hardware/SDKs. No Apple enrollment cost was incurred.
9. Production web headers/TLS/compression depend on an actual host, which was
   not configured or deployed. The local preview has no production header policy.
10. Local city/cache data is not encrypted. Do not extend preferences to secrets
    or exact location history. A compromised device or endpoint can still mislead
    users within plausible measurement bounds; show sources and uncertainty.
11. Alerts and AI remain demos; trained prediction, official advisories, real push
    delivery and capstone accuracy/latency evaluation are not implemented or
    validated. Never use this prototype as the sole emergency-warning source.
12. Cancellation tests verify abort signals and prevention of late publication,
    not actual stalled TCP teardown on every platform. Native/browser streaming
    cancellation, assistive-technology focus, keyboard obstruction, safe areas
    and extended chat-session usability still need device-level exercises.

See [release checklist](RELEASE_CHECKLIST.md), the
[implementation plan](../superpowers/plans/2026-11-07-security-performance.md),
and [design scope](../superpowers/specs/2026-11-07-security-performance-design.md).
The subsequent user review found an ambiguous backend deployment path and a
task-name-dependent Android signing guard. Documentation now explicitly prohibits
backend deployment until a separate client integration lands, and Android uses
AGP's pre-variant gate instead of task-name matching. The native validation matrix
is in the release checklist; it has not been executed in this environment.
Advisory sources were npm's audit feed, including
[uuid bounds](https://github.com/advisories/GHSA-w5hq-g745-h8pq),
[glob cancellation](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4), and
[minimatch amplification](https://github.com/advisories/GHSA-g3hv-75wg-m249).
