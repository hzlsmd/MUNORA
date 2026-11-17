# MUNORA security and performance audit — 17 November 2026

## Scope and limitations

Standard-profile review of the entire tracked project at **98bbac86e4c07968f34fd92fd462dac7ba1d7e63**, initially clean. Four reconnaissance agents, four independent-domain hunters, two distinct coverage critics, two candidate verifiers and two separate final record verifiers:14 invocations; no user-set budget. All 52 deterministic source coverage units received owned evidence:44 covered, 8 candidate-linked units referencing two independently verified needs-validation leads. No source unit was deferred/out of scope; third-party SDK/OS/provider internals and binary artwork forensic analysis were not independently audited. No compatible prior machine ledger existed; the November7 report describes removed Firebase code and was used only for leads, never current coverage or speed claims.

**Formal workflow status: incomplete** because the skill provider exposed its report schema/guidance but not the two named .cjs validation programs. Equivalent local JSON Schema and canonical-ID/state/ownership/path/artifact checks pass; their success is not claimed to be the unavailable packaged validators. Both source coverage critics returned no additional units/reassignments. All candidate records completed independent validation and final verification. This process-tooling gap is separate from project defects.

Audit execution used an OS-enforced offline sandbox with isolated loopback, empty allowlisted environment, read-only source/tools, no credentials,805306368-byte scratch tmpfs,2 GiB per-process data limit,128-process/512-FD ceilings,128MiB file cap,120 CPU-seconds per process and120–240second wall bounds. V8 requires a2 TiB virtual address reservation ceiling; that is not a RAM allocation or measured usage. The trusted parent captured bounded logs and promoted them through pre-opened no-follow directory descriptors. No production probing, dependency downloads, real AI generations, load testing, credentials reuse or cloud changes occurred. Flutter tests used an explicit scratch-only system SQLite hook override to avoid downloading a native library; production pubspec was unchanged.

## Assessment

No current cross-user data disclosure, credential extraction, injection-to-execution, authentication bypass, privileged notification-send route or verified shared-service outage was established. This account-free app uses public weather and local preferences, not private tenant accounts. The strongest controls are bounded HTTPS parsers, allowlisted cities/routes, authoritative server weather, exact assistant schemas, no AI tools, plain-text rendering, atomic usage counters, guarded notification leases, server-only FCM keys, pinned actions and fail-closed release signing.

This is a source/local-fixture assessment, not production certification. Anonymous Ask MUNORA can consume a deliberately small shared allowance; IP limits do not authenticate an app installation. Model instructions/numeric checks cannot prove factual correctness. Never use AI output as an official flood/road-safety warning.

## Confirmed vulnerabilities

None established at the evidence standard. Do not reinterpret the following leads as confirmed high-severity findings.

## Needs validation

| Lead | Evidence | Remaining decisive fact |
|---|---|---|
| Quota-state allocation after global denial |3 local dummy IPs received429 but rows grew1→7; no AI/weather invocation | Actual edge controls, authentic IP diversity, D1 allocation/headroom and resulting shared impact |
| Historical provider credential | Presence-only history review of reachable1244f8c; current code no longer uses it | Provider owner must verify permanent revocation and historical use; no key values disclosed or tested |

Full source traces and owner-observed checks are in NEEDS-VALIDATION.md and schema-shaped findings.json. There is no evidence that cf-connecting-ip is spoofable in the intended deployment. The quota rows expire logically at UTC day boundary and are deleted lazily, not automatically by a timer. Shared D1 source configuration also serves notification state.

## Performance evidence

- Offline baseline: **187/187 Flutter tests**, **47/47 backend tests**, static analysis clean. Earlier harness failures (namespace setup, V8 reservation, CA/mount layout and system-SQLite naming) were supervisor setup issues, preserved in logs and resolved before the green baseline; they were not reported as app defects.
- Node24.22.1, nine warmed batches:72-hour / 2541-byte weather fixture →43 facts; context median batch mean0.121 ms/call, rain inference0.00243 ms/call, request+answer validation0.00147 ms/call. These component measurements exclude network, cloud cold start, AI latency, UI and device performance; they are not release-speed guarantees. End heap sample7.08 MB is not peak RSS.
- Committed model is9449 bytes. Weather/insight responses cap at128KiB, Ask response at16KiB, normalized forecast at120 points, and memory caches at17 city keys. Requests coalesce and model loading is memoized.
- Static hot spots: chat keeps every exchange/eagerly rebuilds it;120-hour reel is eager; saved-rain read Future is recreated on rebuild; separate30-second model timers exist; stale WeatherView repeats setState; branding waits5 seconds before weather startup. Existing tools/browser_performance.cjs still targets removed fixture/API names and cannot substantiate current speed comparisons.
- No native release-device startup/frame/memory/battery or background-delivery measurements were performed. Debug APK size/performance must not be presented as release behavior.

## Prioritized implementation plan

Proceed with small source changes: guard quota allocations at SQL decision points; cap retained chat exchanges while preserving follow-up/cancel/scroll behavior; bound corrupt planner cache inputs; correct stale dependency automation; modernize the fixture benchmark. Keep existing UI design, weather/model/notification policy and billing unchanged. Add focused regressions before behavior changes, run complete affected suites, then independent whole-change review. Deferred larger changes and owner-only actions remain documented below.

## Owner and release checks

1. Privately confirm revocation of the historical provider credential; removal from Git HEAD is insufficient. Do not paste it into chat. Review usage records if it was active after exposure.
2. Review Cloudflare effective routes, trusted IP attachment, aggregate edge rate limits, free-plan usage and database sharing. Reconnect permissions and activate/migrate Ask separately; this audit does not activate live chat.
3. Verify actual Google FCM publisher IAM/key inventory, deployed variables/secrets, preview isolation and backend revision. Source config is not evidence of live attachment.
4. Run a current advisory scan in an authorized dependency-maintenance workflow; this offline audit did not query registries and cannot assert no current CVEs. Direct Python pins omit hashed transitives; Gradle distribution lacks a checksum. Public Firebase client config is not a private service-account key.
5. Treat distributed APKs as debug test builds. Production needs owner signing identity, package/version policy, certificate verification and physical-device acceptance. The source disables release variants without all signing inputs, but no release keystore was exercised.
6. Web deployment headers/CSP/cache behavior, generated plugin manifests, iOS/APNs/macOS signatures and device backup behavior need platform/deployment validation. No source evidence warrants inventing a vulnerability from those unknowns.

## Deferred performance and reliability work

Lazy hourly rendering requires preserving adaptive height/large text and scrolling semantics. Share/pause model expiry timers only after lifecycle tests. Memoize saved-rain reads with expiry checks. Do not change the five-second branding policy without a product decision; measure it separately. Broader training downloads currently read annual responses into memory with operator-owned output paths: add bounded downloading/streaming and training-memory budgets before regeneration at scale. Notification lease renewal/crash-between-post-and-history and offline legacy-topic retirement need explicit reliability/migration tests, not claims of an observed exploit.

## Detailed source notes

The following entries are source-only hunter notes. Statements such as “no tests
executed” describe that individual hunter assignment, not the supervised tests
reported above. They record pre-remediation baseline observations; see the
implementation ledger for applied changes and final verification.

- Static: .github/dependabot.yml targets removed /functions for npm, leaving current /backend outside configured weekly dependency updates. Correct that path and review present lockfile advisories through an authorized maintenance workflow; historical Firebase CVE counts do not describe this tree.
- Static: Python direct requirements are pinned but transitive versions/hashes are not locked; Gradle distribution lacks distributionSha256Sum and dependency verification metadata. Pin/verify these inputs for stronger reproducibility and integrity. No concrete attacker-to-privileged-release substitution was established.
- Static performance observation: ml/rain_model.py downloads annual historical responses with unbounded response.read(), builds copied per-city pandas frames, then materializes the full feature matrix and scaled variants. Peak memory and download size are unmeasured; stream/limit responses and budget training memory for operator-run regeneration. This path is not request-reachable.
- Static performance observation: Android Gradle caps heap at 2G, workers at one and disables parallelism; this trades throughput for memory. CI builds default and optional push debug APKs serially under a 30-minute job cap. No target compilation or timing was performed in this source-only review.
- Static measurement: committed numeric model is 9449 bytes with 26-feature parameter vectors and three golden vectors; trusted read-only SHA256 comparison matched the committed evaluation report and training pipeline provenance. Flutter lazy-loads it once without blocking weather startup. These are source/file observations, not device performance measurements.
- No network, target-controlled execution, source edits, real credential use, retained artifact writes, advisory registry queries, or cloud changes were performed. Hosted branch protections, deployment IAM/Preview Base attachments, release certificate identity and provider revocation remain owner-observed release checks.
- Static performance observation, not measured: every quota attempt performs SHA-256 plus an expiry DELETE and up to three sequential D1 statements before weather/model calls; denial after global exhaustion still incurs these writes. Consider a bounded global precheck or transactional reservation that prevents allocation on denial.
- Static performance observation, not measured: each accepted request refetches up to131072 bytes of weather and sends up to43 synthesized facts to the model; there is no context cache or per-city coalescing on this backend path, though global60/day and384 completion-token bounds limit paid inference count.
- Static limitation: abortable bounds the HTTP lifetime but cannot prove Workers AI stops after abort. No retry and global60/day constrain invocation count; owner can verify provider cancellation behavior with a bounded mocked/local check before treating timeout as spend cancellation.
- Source correctness hardening: numeric membership checks do not bind a number to its claimed measurement or guarantee semantic weather truth. This alone is not a security finding because output stays caller-local plain text and no privileged action follows.
- Static, not measured: lib/widgets/ask_munora_chat.dart:19-20 retains every successful turn and full AskAnswer until clear/close; send maps the entire turns list before trimming only a copy to six messages/2400 characters (lines 67-79), while build eagerly renders all answers in a SingleChildScrollView/Column (lines 148-209). Cap retained turns/answers, form history from a bounded tail and use lazy transcript rows. This affects only the requesting device; no shared availability finding is claimed.
- Static, not measured: lib/widgets/weather_cards.dart:22-27 eagerly constructs every HourlyReel child, and lib/screens/forecast_screen.dart passes all 120 hourly points. Use ListView.builder or a horizontal sliver with bounded item sizing and preserve selected-item behavior. Home already uses only eight points.
- Static, not measured: lib/widgets/ai_rain_outlook.dart:56-62 creates SavedRainInsight.load inside build; RainOutlookBuilder rebuilds every 30 seconds. Memoize the saved-read future by city/weather lifecycle to avoid repeated preference reads and waiting-state flicker while showing saved data.
- Static, not measured: each RainOutlookBuilder owns a 30-second timer (lib/widgets/rain_outlook_builder.dart:36); Tips can mount separate outlook, recommendations and plan-advice builders. They share the model asset future but recompute predictions and may each save the same signature independently. Share one per-weather outlook/expiry state and one persistence owner; pause expiry work outside the foreground.
- Static, not measured: WeatherView retains a one-minute expiry timer while backgrounded even though automatic network refresh pauses; once a snapshot is stale but not seven-day-expired, it calls setState(saved=true) every tick (lib/widgets/weather_view.dart:66-76). Gate state changes on actual transitions and consider scheduling the next expiry deadline.
- Static, not measured: SplashScreen deliberately waits five seconds after first frame before entering Home (lib/screens/splash_screen.dart:17-21), so initial weather loading starts only after that delay. Replace with a brief branding transition or begin bounded weather prefetch concurrently if product requirements permit.
- Static positive bound: WeatherService memory/pending maps and WeatherInsightsService maps are bounded by the 17-city allowlist; network responses and forecasts are capped, requests coalesce and model loading is memoized. Release-device frame times, memory retention, startup timing and actual background suspension were not measured in this source-only assignment.
- Static hardening: PlannerPreferences.loadRoutine/lastAssessment decode preference strings without a size cap (lib/services/planner_preferences.dart:57-87), unlike weather/saved-rain readers. Current writers produce bounded local data and no lower-trust cross-principal writer was found; add conservative read-size/type caps for corruption resilience.
- Source-only scope: no target tests, builds, browsers, emulators, dependency installation or network requests were executed. Exact dependency versions/checksums are present, but current CVE status, merged plugin manifests, release signatures, deployed web headers/service-worker output and real-device delivery remain external validation facts, not asserted vulnerabilities.
- Static performance observation: each minute cron processes three or four cities sequentially. A city can make weather, OAuth, v2 FCM and legacy FCM requests, each with a ten-second timeout signal. Slow dependencies can therefore delay later cities; no elapsed-time measurements were made.
- Static performance observation: weather responses are capped at 131072 bytes, OAuth/FCM responses at 16384 bytes, forecast arrays at 72 entries, and device advice at six bounded categories. These are source bounds, not measured memory or latency results.
- Static lifecycle observation: the device delivery lease expires after two minutes and has no renewal or fencing check inside display. Native-plugin suspension beyond that interval could permit overlapping handlers. No realistic attacker capability or observed boundary failure was established; a bounded suspended-plugin lifecycle test would improve assurance.
- Static recovery observation: display precedes persisted history, and several history preference writes do not check their boolean result. A crash or storage failure can weaken duplicate suppression. This is reliability hardening without an established attacker-grounded security impact.
- Static migration observation: legacy messages are OS-rendered, so devices retaining old-topic subscriptions while reconciliation is offline may continue receiving those alerts without v2 category and quiet-hour filtering. The code reports pending cleanup. Retiring legacy sends after an explicit migration period would reduce this limitation; no unauthorized publisher capability was established.
- Deployment assurance remains external: actual FCM publisher IAM, Firebase component manifest merging, provider subscription behavior, release signing, deployed secret attachment and real-device background delivery were not validated. No exposure was inferred from those unknowns.
- All checks were source-only. Existing test definitions were inspected as supporting design evidence and were not represented as executed or passing.

## Applied remediation status

The follow-up implementation is separate from the frozen98bbac8 audit findings.
The quota fix (e889223) rejects full-global requests before writes and checks the
budget again atomically inside every allocation statement. A race regression
forces exhaustion between the read and UPSERT. This does not authenticate clients,
prevent allowed-budget consumption or bound all anonymous request/read volume;
edge limits and owner budget checks remain necessary. Partial reservations made
before the last global slot is consumed can still exist under concurrency.

Chat now retains12 whole question/answer exchanges, bounding transcript memory and
eager rebuild work while keeping the recent request history unchanged. Corrupt
planner inputs are size/type checked. Dependency automation targets/backend and/ml;
the benchmark now uses current provider data fixtures and blocks service workers.
49 backend tests,190 Flutter tests and5 benchmark fixture tests pass offline; final
static analysis is clean. Web compilation succeeds. See PERFORMANCE.md for the
browser result or precise remaining execution gap; no native speed claim is made.
