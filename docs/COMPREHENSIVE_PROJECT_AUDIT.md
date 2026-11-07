# MUNORA Comprehensive Project Audit

**Audit date:** 7 November 2026  
**Repository:** [hzlsmd/MUNORA](https://github.com/hzlsmd/MUNORA)  
**Audited branch:** `master`  
**Integrated commit:** `914f27e6c11301b180f1e7e8b450b5893b6742fb`  
**Audit type:** Source/configuration review and evidence reconciliation; not a penetration test or production certification.

## 1. Executive summary

MUNORA is a Flutter weather prototype for Metro Manila/NCR. The integrated `master` branch now contains the cumulative weather, security, performance, and developer-experience work from `codex/weather-without-login`. The default app uses Open-Meteo directly, without resident login, a provider API key, Firebase deployment, or a paid backend. The optional Firebase Functions backend is dormant and must remain disabled until a separate App Check client integration and explicit owner cost approval are completed.

The integrated source contains meaningful defensive controls: fixed city coordinates and provider URL, bounded response parsing, weather measurement/time validation, stale-cache limits, request coalescing, explicit offline states, deny-all Firestore client rules, pinned CI actions, npm audit gating, and fail-closed Android release signing. The existing security audit records regression testing and fixture-based performance measurements.

**Overall assessment: suitable as a school prototype for continued development; not ready to be described as an operational emergency-warning service or production-grade mobile release.** The largest outstanding owner/security action is revocation of the OpenWeatherMap key exposed in Git history. Native Android release/signing verification, iOS/device verification, real provider/platform validation, and any future Firebase backend enablement remain separate gates. Alerts are a demo. Tips are deterministic rules, not a trained AI forecasting model.

## 2. Scope, method and evidence quality

### Included

- Flutter screens, navigation, weather services, data models, widgets and tests.
- Open-Meteo adapter and city-coordinate allowlist.
- Optional Firebase Functions source, Firestore rules and Firebase configuration.
- Dependency manifests/lockfiles and GitHub Actions workflow.
- Android Gradle/manifest settings, platform configuration and Codespaces SDK setup.
- Existing security/performance audit, release checklist, deployment status, weather setup and recommendations documentation.
- Git branch topology and PR integration history.

### Evidence classes

| Label | Meaning |
| --- | --- |
| **Current source verified** | Read from files on the integrated `master` commit. |
| **Repository-recorded test evidence** | A prior audit/PR document reports a command/result. It is not a fresh execution in this integration session. |
| **GitHub integration verified** | GitHub reports the PR merged and provides the merge commit and parent SHAs. |
| **Not verified here** | Requires a local Flutter/Node runtime, native SDK/device, cloud project, provider account, or production host not available through this repository-only session. |

The existing detailed audit is dated 7 November 2026 and records a prior baseline commit `47658457598b168688b8e19ee221364e63e4fcd0`. Its implementation/test evidence is retained as historical repository evidence. It must not be confused with tests newly rerun against merge commit `914f27e`. The integration session inspected current source and GitHub metadata, but did not have a local shell/worktree to run Flutter, Node, Android or web build commands.

Third-party SDKs, operating systems, Open-Meteo infrastructure, Firebase internals, cloud IAM, account security, and the full public Git history were not independently penetration-tested. No live load test was sent.

## 3. Integration record

- Before integration, `master` was `804613c5bf2067ed55bcbdf60b169942a120c5db` (including the approved design and implementation-plan documentation commits).
- The cumulative source branch was `codex/weather-without-login` at `0dff89abe0e570c45b188345b9de73d9fabb6f16`.
- The GitHub comparison reported the source branch 15 commits ahead and 4 behind master, with a shared ancestor `88a03aad67c726eac59b52027cf74568af0cb6fd` and 64 changed files.
- PR [#8](https://github.com/hzlsmd/MUNORA/pull/8) was created from the cumulative branch to master, reviewed for mergeability, and merged using a normal merge commit.
- Result: `914f27e6c11301b180f1e7e8b450b5893b6742fb`. GitHub's commit API confirms two parents in order: master `804613c...`, then source `0dff89a...`. The commit reports 64 files changed, 3,876 additions and 1,724 deletions.
- The recovery reference `recovery/master-before-integration-20261107` was observed at `4af276d35dc99aedcfcc394ef77902f2d908c968`; it was not modified.
- After merge, the cumulative source branch was 5 commits behind master and 0 ahead, confirming the source commits are contained in master. No branch was deleted and no history was rewritten.

The repository also contains the approved design and execution plan under `docs/superpowers/`.

## 4. Architecture and data flow

### Default Flutter/Open-Meteo path

1. The Flutter app presents Home, Forecast, Tips and Alerts screens; it does not require resident registration or login.
2. The app-owned `WeatherService` accepts only supported NCR city names and an HTTPS endpoint. The default endpoint is `https://api.open-meteo.com/v1/forecast`.
3. `open_meteo.dart` maps the selected city to a fixed latitude/longitude pair and requests current/hourly values with explicit units and `Asia/Manila` timezone. The caller does not supply arbitrary URLs or coordinates.
4. The provider response is normalized and validated before it becomes a `WeatherSnapshot`. The model checks plausible measurement ranges, timestamps, forecast ordering/horizon, duplicates, and a maximum of 40 normalized forecast samples.
5. The service shares an in-flight request for a city, reuses a fresh in-memory snapshot for up to ten minutes unless explicitly refreshed, and stores city-keyed weather in SharedPreferences. Saved data is revalidated and can be used offline for up to 24 hours with age/source labeling.
6. Screens show loading, retry, error and saved-weather states rather than fabricating live weather.

Open-Meteo receives the request's network IP and selected city coordinates. The app does not request GPS permission in this flow and does not send a resident login credential. Local city/weather preferences are not encrypted and should not hold secrets or sensitive location history.

### Tips and Alerts

- Tips are deterministic rule-based guidance triggered by current and forecast conditions. Documented thresholds include temperature at least 32°C or apparent temperature at least 35°C, wind at least 10 m/s, and rain/thunderstorm conditions. These are application-selected thresholds, not official hazard levels.
- Forecast samples are three-hour presentation samples derived from hourly provider data. Short-lived weather events may be missed.
- Alerts remains a demo; no authoritative government advisory feed or push delivery is implemented.
- No trained predictive model, validated confidence score, or official emergency-warning capability is implemented.

### Dormant Firebase alternative

The Functions code is an optional backend path, not the default application data path. It contains App Check verification, rate/budget controls, cache/refresh leases, provider request validation and bounded response handling. The current Flutter app does not send an App Check token. Backend defaults disabled; do not enable or deploy it until a separate reviewed client integration and explicit owner approval of any infrastructure costs. Firestore rules deny all direct client reads and writes. Admin SDK access bypasses those client rules and still needs IAM review.

## 5. Findings and risk register

Severity describes potential impact if the relevant condition occurs, not a claim that an exploit has been demonstrated.

| ID | Severity | Area | Current state and residual risk | Required action |
| --- | --- | --- | --- | --- |
| MUN-01 | **High** | Historical secret exposure | An OpenWeatherMap API key was committed in public history (identified by prior audit as commit `1244f8c`). Current source cleanup does not revoke it. | Owner must revoke/disable the exposed key in the provider account and confirm it is no longer valid. Do not paste a replacement into source/chat. No history rewrite was performed. |
| MUN-02 | **High if backend enabled** | Firebase cost/security boundary | Backend is intentionally disabled. Current Flutter client does not send App Check. App Check is attestation, not user identity, and does not cap invocation charges or eliminate replay/valid-client abuse. | Keep disabled. Any future integration requires reviewed client token lifecycle, real-platform tests, explicit owner cost approval, billing alerts, IAM and TTL review. |
| MUN-03 | **High release gate** | Android release signing | Debug-key release fallback has been removed. Release variants are disabled before task creation unless all four signing variables are present. | Run the documented missing/blank/valid/invalid keystore matrix on the team's Android SDK machine; verify APK/AAB signatures and certificate. |
| MUN-04 | **Moderate** | Weather data integrity | Current source applies unit, measurement, timestamp, forecast sequence, response-size and freshness validation. Third-party estimates can still be wrong, incomplete or unavailable. | Keep source/model timestamps visible; test provider schema changes and malformed/edge responses; never treat model output as an official observation. |
| MUN-05 | **Moderate** | Provider terms and availability | Open-Meteo direct free endpoint is documented for a non-commercial prototype, with attribution and rate/usage conditions. Shared networks can hit IP-based limits early. | Recheck current terms, limits and attribution before wider distribution, commercial use, ads or subscription features. Define provider-failure behavior and cost/availability strategy. |
| MUN-06 | **Moderate** | Local data privacy | City and weather cache use local preferences and are not encrypted. Current data is public weather, not authentication material. | Do not add tokens, secrets or precise location history to preferences. Reassess retention and disclosure if data collection expands. |
| MUN-07 | **Moderate** | Emergency communication safety | Alerts is still demo-only; Tips are rule-based and not official advisories or a trained predictor. Three-hour samples can miss brief events. | Keep demo labels and safety disclaimers. Integrate authoritative sources and test delivery/latency before any emergency-use claim. |
| MUN-08 | **Moderate** | Cloud backend operations | Real Firestore contention, Functions SDK deployment compatibility, provider credentials/errors, IAM, TTL policy and log retention are not verified by source tests. | Treat as a separate backend release project. Configure TTL for `weatherInternal.expiresAt`; review least-privilege IAM and operational logs. |
| MUN-09 | **Moderate** | Native platform readiness | Android release builds/signing and physical Android/iOS behavior are not verified in this integration session. APNs and signed macOS entitlements also need platform-specific checks if those targets are supported. | Run debug/release build matrix, physical-device smoke tests, lifecycle/network/accessibility checks and signed entitlement checks on supported hardware. |
| MUN-10 | **Moderate** | Web hosting security | Local web build evidence does not establish production TLS, HSTS, CSP, compression, immutable asset caching or frame restrictions. | Before public hosting, configure and test HTTPS/TLS, HSTS, CSP compatible with Flutter, nosniff/frame restrictions and asset compression. |
| MUN-11 | **Low–Moderate** | Accessibility | Existing widget coverage includes narrow 320px layout and 2x text scaling. Screen-reader focus, keyboard obstruction, safe areas and broader localization/scale combinations remain unverified. | Conduct assistive-technology and device-size testing before release. |
| MUN-12 | **Low–Moderate** | Dependency maintenance | CI pins GitHub Actions by commit, pins Flutter 3.47.9, runs npm audit and Dependabot is configured. Pinned dependencies still age; npm audit is not a full supply-chain audit. | Review Dependabot changes, keep pins maintained and repeat dependency checks at release. |
| MUN-13 | **Low** | Android build resource pressure | Gradle heap/metaspace/workers are bounded to reduce pressure in small Codespaces. The settings do not prove the cause of prior daemon failures. | If daemon failures persist, capture memory/cgroup events and daemon logs; validate debug APK build after SDK setup. |
| MUN-14 | **Low** | Backend budget sizing | Existing dormant backend's 1,000 daily refresh-attempt budget cannot support 17 cities refreshed every 10 minutes (2,448/day), before failures/duplicate work. | Do not silently raise the budget. Recalculate freshness, traffic, quotas and cost in any separately approved backend design. |

### Positive controls observed in current source

- Firestore rules globally deny direct client reads and writes.
- Open-Meteo URL and city coordinates are application-owned; no caller-controlled provider URL path was identified in the reviewed adapter.
- Weather response is bounded to 128 KiB in the client; normalized forecasts are capped at 40 samples and condition strings at 120 characters.
- Client validates HTTPS, rejects embedded URI credentials/fragments and disables redirects; Android manifest disables cleartext traffic.
- Cache entries have freshness/age checks; obsolete city responses and expired cache data are guarded.
- CI uses pinned action SHAs, Node 22, Flutter 3.47.9, npm audit and automated tests.
- Android release signing is fail-closed instead of falling back to debug credentials.

These controls reduce identified risks but do not prove absence of vulnerabilities.

## 6. Performance and test evidence

### Prior recorded measurements (not rerun during this integration)

The existing security/performance audit reports one controlled Linux/Flutter 3.47.9/Dart 3.13.7/Chromium fixture run:

| Metric | Baseline | Hardened |
| --- | ---: | ---: |
| Weather visible at 390×844 | 4,662 ms | 1,409 ms |
| Weather visible at 1366×900 | 4,747 ms | 1,515 ms |
| Requests after Home → Forecast → Home → city change | 4 | 2 |
| Page errors in measured fixture workflows | 0 | 0 |

The same audit reports an in-process backend fixture benchmark: 57.99 ms initial handling, 0.040 ms warm median and 0.149 ms warm p95 over 1,000 cache hits; a 100-request same-city burst made two provider-fixture calls and one cache write. These numbers exclude real Firestore/network/provider/App Check/cloud runtime latency and are not a production load test.

The audit reports approximately 41 MiB web output on disk (including rendering-engine alternatives), and `main.dart.js` raw 2,533,803 bytes / gzip 751,176 bytes after its final review fixes. This is not a claim about actual user download size or native APK size.

### Prior recorded automated checks

The existing audit records 22 backend tests on Node 22, 25 Flutter tests, Flutter analysis with no issues, successful release web build, zero npm audit advisories, valid Android XML/Apple plist syntax and four browser fixture workflows with zero JavaScript errors. The later Tips document records 36 Flutter tests, clean analysis and successful web build. These records refer to prior branch work and are not newly executed against the integrated merge commit here.

### Integration-session verification

- GitHub reports PR #8 merged.
- GitHub reports merge commit `914f27e6c11301b180f1e7e8b450b5893b6742fb`, with the expected first and second parents.
- PR diff contained 64 files, 3,876 additions and 1,724 deletions.
- After merge, the feature branch was 0 commits ahead and 5 behind master.
- The merge commit itself returned no associated pull-request-triggered workflow runs and no combined status records. A subsequent push-triggered GitHub Actions run on the final documentation head `b7f94c27dda679bc8e3f29cb8a03ddd6837b4cbb` completed successfully: backend install, npm audit and backend tests passed; Flutter dependency resolution, analysis, tests and web build passed. [Run #42387683306](https://github.com/hzlsmd/MUNORA/actions/runs/42387683306).
- The integration session did not have a local shell/worktree, so commands were not run interactively by the assistant. The successful GitHub Actions workflow provides exact-head automated verification. Native Android/iOS builds and device checks remain unverified.

## 7. Release readiness decision

**Current disposition: continue prototype development; do not represent as production-ready or as an emergency-warning system.**

Release gates before a broader public mobile release:

1. Revoke historical OpenWeatherMap key.
2. Reconfirm Open-Meteo terms/attribution and usage suitability for intended distribution.
3. Run CI and local Flutter/Node checks against the exact release candidate SHA.
4. Verify Android debug build, release-variant gating and signing certificate on a supported SDK machine.
5. Test supported physical devices, offline/resume behavior, screen readers, keyboard/safe areas and network transitions.
6. Configure production web hosting controls if web is distributed.
7. Keep Firebase disabled unless a separate reviewed App Check client/server integration, IAM/TTL design and owner cost approval are completed.
8. Keep Alerts marked as demo until authoritative sources, push delivery and operational monitoring are implemented and validated.
9. Describe Tips accurately as rule-based guidance; a trained prediction capability requires a separate model, dataset, evaluation protocol and user-facing limitations.

## 8. Source references

- [README](../README.md)
- [Weather setup and backend policy](WEATHER_SETUP.md)
- [Weather recommendations](WEATHER_RECOMMENDATIONS.md)
- [Deployment status](DEPLOYMENT_STATUS.md)
- [Detailed security/performance audit](audit/2026-11-07-security-performance.md)
- [Release security gates](audit/RELEASE_CHECKLIST.md)
- [Implementation ledger](audit/implementation-ledger.md)
- [Codespaces Android setup](CODESPACES_ANDROID.md)
- [Master integration design](superpowers/specs/2026-11-07-master-integration-design.md)
- [Master integration execution plan](superpowers/plans/2026-11-07-master-integration.md)

## 9. Follow-up Integration Review (8 November 2026, Asia/Manila)

This addendum preserves the earlier report and distinguishes fresh local evidence from its repository-only evidence. During verification, master advanced to `ad61ec29d1cc053a4503c6b6ee843943b5d77c2b`. The final integration was rebuilt on that head, retaining all newer documentation, dependency updates, material_ui migration and CI changes. No concurrent user work was overwritten.

### Complete Branch Disposition

Thirteen development branches were accessible at the final inventory, plus the recovery reference. Fourteen PRs were inspected; all were closed/merged. No main branch existed.

| Branch | Head reviewed | Disposition |
| --- | --- | --- |
| master | ad61ec2 | Authoritative base, includes PRs 8-13 |
| codex/security-performance-audit | bf5b06d | Already integrated; validation, abuse controls, signing and CI retained |
| codex/codespaces-android-sdk | 91bb221 | Already integrated; checksummed installer retained |
| codex/open-meteo-weather | 083a857 | Already integrated; no-login default retained |
| codex/weather-recommendations | dc71ba7 | Already integrated; rule-based tips retained |
| codex/android-build-memory | 9097e65 | Merge history and preserve user null guard plus dictionary entry; exclude invalid gitlink |
| codex/weather-without-login | 6ff447d | Earlier history through 0dff89a already integrated; exclude latest revert-only delta |
| revert-6-codex/weather-recommendations | ef5f410 | Excluded: deletes working rules/tests and restores fixed AI demo, conflicting with the requested rule-based feature |
| dependabot/github_actions/actions/checkout-7.0.1 | f2c000c | Already merged in PR9; SHA pin retained |
| dependabot/github_actions/actions/setup-node-7.1.0 | f6eac21 | Already merged in PR10; Node22 job retained |
| dependabot/pub/cupertino_icons-2.0.0 | 5ffb8bf | Already merged in PR11; retained |
| dependabot/pub/flutter_lints-6.0.0 | be0bd19 | Already merged in PR12; retained |
| dependabot/pub/google_fonts-9.0.0 | 008aca4 | Already merged in PR13; material_ui imports, SDK floors and lockfile migration retained |

The revert branches are left untouched, not undone or deleted. A stale local Codespace tracking ref at initial-upload commit 1244f8c has no additional changes and is absent from the live remote inventory. The recovery branch remains at 4af276d. Git history is retained through merge parents; the only new source delta beyond ad61ec2 is the user's explicit null check and editor dictionary entry. No textual conflict occurred.

### Additional Findings and Verification Limits

| ID | Severity | Likelihood / impact and scenario | Remediation / verification |
| --- | --- | --- | --- |
| MUN-15 | Low | Commit 9097e65 adds a mode-160000 MUNORA entry pointing to the old repository without .gitmodules; recursive checkouts may fail or confuse dependency ownership | Exclude that accidental entry only; preserve the user commit and its useful changes. Verified final tracked tree and diff |
| MUN-16 | Low | Existing Dart formatting drift makes automated style gates fail, despite clean analysis | Reported, not suppressed. Format dry-run flags 13 files in the initial combined tree; formatting-only cleanup deferred |

No account login/password/session/JWT/RBAC, upload endpoints, SQL queries or user-owned server resources are implemented in the default app; related password, SQL injection, upload, session-CSRF and IDOR tests are not applicable to that path. Runtime source review found no arbitrary shell execution or HTML evaluation path. Weather text is rendered by Flutter. This does not constitute a general proof against injection or XSS in future features.

Current-tree targeted private-key/provider-key pattern scan returned no matches; history metadata confirms the earlier key-removal commits. This limited scan is not a comprehensive secret detector. No secret value was printed or reused. Deployed IAM, TLS/security headers, real App Check replay behavior, Firestore contention/TTL and infrastructure logs remain unverified. There is no production database query plan to measure locally; backend uses fixed document reads and transactions, not SQL joins.

### Fresh Local Evidence

The first combined candidate passed 36 Flutter tests, 22 Node22 tests, Flutter analysis and release web build. Coverage was 652/683 instrumented Dart lines (95.46%, not whole-repository coverage). npm ci --ignore-scripts installed 224 dependencies with lockfile integrity; npm audit reported zero known vulnerabilities. Installation used host Node24 with an engine warning; backend tests separately used Node22. SDK installer bash syntax and git diff --check passed.

Fixture browser checks at 390x844 and 1366x900 passed with one weather request across Home/Tips and no JavaScript errors. Backend fixture baseline on Node24: cold 49.66 ms; 1,000 warm requests p50 0.0746 ms/p95 0.1471 ms; 100 concurrent cold requests 2.09 ms with two provider calls and one cache write; response 3,773 bytes. These exclude provider/Firestore latency. Initial web build took 57.0 seconds and main.dart.js was 2,232,005 raw bytes. No new speedup is claimed; later dependency changes make that bundle measurement historical, not final.

Initial sandbox attempts could not bind Flutter test sockets; approved-network reruns passed. A dependency attempt hit an approval-service usage limit, and a later cache-path failure was resolved using a writable npm cache. Tests were not weakened. Android release was attempted but failed downloading absent Flutter Android artifacts under restricted networking; common local Android SDK paths were absent and private signing material was unavailable. Native release/signatures, hardware behavior, comprehensive Dart/native advisory scanning and production penetration/load tests remain unverified.

Final review used the Superpowers reviewer checklist in a separate self-review pass; no independent subagent reviewer was available. Native release limitations and owner credential revocation remain release gates. The retained master dependency migration requires fresh final-candidate checks rather than relying on the earlier candidate's measurements.

Final candidate after retaining ad61ec2: dependency resolution succeeded without lockfile changes; all 36 Flutter tests passed again, analysis reported no issues, and production web compilation succeeded in 106.8 seconds. A repeat npm audit returned zero known vulnerabilities. Backend source/lockfile are unchanged from the 22-test Node22 run. Build timing differences are not evidence of an optimization or regression because concurrent compiler load differed. The final merge preserves ad61ec2 and 9097e65 as parents and excludes only the incompatible revert delta and accidental gitlink.

Publication verified: master integration commit `6db9d456cd1dc6bdb49aac42711c4de7e007e4ac` has those expected parents and tree `41f78c86cf831b0e9d5dfd8dfa2c38b704f1386d`, identical to the tested local candidate. Final browser checks again passed both viewports with one provider request and no page errors; final main.dart.js is 2,259,293 raw bytes. A following documentation-only commit records this verification. No deployment or signed APK release was performed.
