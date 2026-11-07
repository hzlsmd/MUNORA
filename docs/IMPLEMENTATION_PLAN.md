# MUNORA Implementation Plan

**Date:** 7 November 2026  
**Target branch:** `master`  
**Baseline:** integrated commit `914f27e6c11301b180f1e7e8b450b5893b6742fb`  
**Companion audit:** [COMPREHENSIVE_PROJECT_AUDIT.md](COMPREHENSIVE_PROJECT_AUDIT.md)

This plan is ordered by risk reduction and release dependency. It distinguishes owner actions, prototype-quality improvements and optional future capabilities. Do not skip the gates to meet a presentation deadline.

## Priority summary

| Priority | Workstream | Why it comes first | Exit condition |
| --- | --- | --- | --- |
| P0 | Revoke exposed historical provider key | A credential exposed in public history may still be usable. | Provider confirms the old key is revoked/disabled; no replacement secret is committed. |
| P0 | Keep optional Firebase backend disabled | Current Flutter client does not send App Check and backend costs are not approved. | Disabled state remains tested/documented; any enablement is a separately approved project. |
| P1 | Exact-commit automated verification | No CI status was returned for the integration merge and tests were not rerun in this session. | All repository CI jobs pass on the release-candidate SHA; failures are triaged. |
| P1 | Android build and signing validation | Release signing is fail-closed but native build/variant behavior is not verified. | Debug APK succeeds; missing/invalid signing gates release; valid test keystore produces verifiable signed artifact. |
| P1 | Device, privacy and accessibility validation | Browser/widget tests do not establish physical-device behavior. | Supported-device matrix passes and limitations are documented. |
| P1 | Open-Meteo usage and distribution review | Free endpoint is documented for non-commercial prototype use and has provider/IP limits. | Current terms, attribution and expected traffic are approved for the actual distribution model. |
| P2 | Authoritative advisories and notifications | Alerts is a demo and cannot be treated as an emergency channel. | Source, consent, delivery, latency, monitoring and fallback are validated before enabling. |
| P2 | Predictive analytics research/evaluation | Current Tips are deterministic rules, not trained AI. | A separately scoped model is evaluated against documented data/metrics before any predictive claim. |
| P3 | UX and operational polish | Improve quality after safety and release gates. | Accessibility, localization, observability and support tasks are completed or explicitly deferred. |

---

## Phase 0 — Immediate owner security action (P0)

### 0.1 Revoke the historical OpenWeatherMap credential

**Owner:** repository/provider account owner  
**Finding:** MUN-01  
**Dependency:** access to the OpenWeatherMap account that owns the exposed key.

Tasks:
1. Identify the key committed in historical commit `1244f8c` using the provider account's key inventory. Do not print or paste the key into issues, source code, or chat.
2. Revoke/delete that key in the provider dashboard.
3. Confirm that the key is disabled; if provider tooling supports it, verify the old credential no longer authorizes requests without exposing it.
4. Review usage/billing history for unexpected activity around the exposure window.
5. Do not create a replacement key for the current default app: Open-Meteo does not require one.
6. Record the date and confirmation of revocation in the team's private security record. Do not record the secret value.

**Acceptance criteria**
- Provider account confirms the old key is revoked/disabled.
- No provider credential is present in current app source, public configuration, tests or docs.
- No Git history rewrite is performed without a separate explicit owner decision and coordinated contributor plan.

### 0.2 Preserve the Firebase backend prohibition

**Owner:** project owner and backend maintainer  
**Finding:** MUN-02, MUN-08, MUN-14  
**Dependency:** none; this is a safety constraint.

Tasks:
1. Keep `WEATHER_BACKEND_ENABLED=false` and do not deploy Functions or activate billing for the current no-paid-services prototype.
2. Do not bypass App Check, add anonymous attestation fallback, or treat `WEATHER_API_URL` as proof that the backend is secured.
3. Keep deny-all Firestore client rules in place.
4. Treat any proposal to enable Firebase as a separate architecture/cost decision requiring explicit owner approval.

**Acceptance criteria**
- Default application remains direct Open-Meteo and does not require Firebase Auth, Firebase App Check or paid Firebase services.
- Backend remains disabled and undeployed unless a separately approved milestone is completed.
- No documentation implies that the dormant backend is ready for deployment.

---

## Phase 1 — Exact-commit verification and integration baseline (P1)

**Owner:** maintainer  
**Findings:** all; especially MUN-03, MUN-04, MUN-12, MUN-13  
**Dependency:** integrated `master` commit exists.

Tasks:
1. Run checks from the repository root on the exact candidate SHA:
   ```sh
   node --version
   npm --prefix functions ci --ignore-scripts
   npm --prefix functions audit --audit-level=moderate
   npm --prefix functions test
   flutter --version
   flutter pub get
   flutter analyze
   flutter test
   flutter build web --no-web-resources-cdn
   ```
2. Save CI run links, commit SHA, tool versions, command output and timestamps in the release record.
3. Investigate all failures; do not suppress an audit finding or change a test merely to obtain a green check.
4. Review Dependabot updates and pinned GitHub Actions SHAs. Upgrade deliberately and rerun checks.
5. Re-run focused malformed-input, freshness, stale-cache, coalescing, retry, city-switch and 320px/2x text tests when changing their code paths.

**Acceptance criteria**
- Backend tests, Flutter tests, Flutter analysis and web build pass on one recorded SHA.
- npm audit reports no moderate-or-higher known advisories, or every exception has an approved, time-bounded risk record.
- CI status is green and links to the exact commit.
- A missing workflow run is reported as unverified, not as success.

**Not included:** native Android/iOS signing, live provider load tests or Firebase deployment.

---

## Phase 2 — Android build and release signing gate (P1)

**Owner:** Android build maintainer  
**Finding:** MUN-03, MUN-13  
**Dependency:** Android SDK/Java environment; access to a disposable test keystore for positive signing verification.

Tasks:
1. Set up the Android SDK using [Codespaces Android setup](CODESPACES_ANDROID.md), or use the team's supported local Android Studio/SDK machine.
2. With no signing variables set, run:
   ```sh
   flutter pub get
   flutter build apk --debug
   cd android && ./gradlew :app:tasks --all
   ```
3. Verify that debug builds remain available and app release variants/tasks are absent when any signing variable is missing or blank.
4. Repeat the release-gate check with each of these individually missing/blank: `MUNORA_KEYSTORE_PATH`, `MUNORA_KEY_ALIAS`, `MUNORA_KEYSTORE_PASSWORD`, `MUNORA_KEY_PASSWORD`.
5. Use a disposable test keystore outside the repository with all four values set; build a release APK and AAB.
6. Verify output signatures with `apksigner verify --print-certs` and/or `jarsigner -verify`. Confirm the certificate is the intended test certificate.
7. Verify invalid paths/passwords fail safely. Never expose credentials in logs.
8. Capture memory limits and Gradle daemon logs if the daemon disappears; the Gradle memory cap is mitigation, not proof of root cause.

**Acceptance criteria**
- Debug APK builds successfully.
- All missing/blank-variable cases keep release variants disabled and do not fall back to debug signing.
- Valid disposable signing credentials produce verifiable release APK/AAB.
- Invalid credentials fail; no keystore/password is committed.
- Test results and SDK/Gradle/JDK versions are recorded.

**Release gate:** no public Android release until a trusted release keystore, signing ownership, backup and certificate continuity process are established.

---

## Phase 3 — Physical-device, privacy and accessibility validation (P1)

**Owner:** mobile team  
**Findings:** MUN-04, MUN-06, MUN-09, MUN-11  
**Dependency:** debug build and supported devices.

Tasks:
1. Define supported Android and iOS OS/device versions before claiming cross-platform support.
2. On real devices, test first launch, city selection, refresh, airplane/offline mode, stale saved data, app resume, app termination during request, poor network, provider 429/5xx, and recovery.
3. Verify the app never displays expired weather as current and always exposes source and timestamps.
4. Test screen readers, semantics/focus order, large text, 320px narrow layouts, keyboard obstruction, safe areas, landscape and localization.
5. Verify permission prompts and privacy disclosures. The current default flow should not request GPS permission; explain that the selected city coordinate is sent to Open-Meteo.
6. Inspect local preferences to ensure only city/public weather cache is stored. Do not add secrets, tokens or precise location history.
7. If macOS is a supported target, validate signed entitlements and outbound networking on a Mac.
8. Record device, OS, build SHA, steps, expected/actual behavior and defects.

**Acceptance criteria**
- All critical data-freshness/offline scenarios pass on supported physical devices.
- No secret or sensitive location data is stored in preferences.
- Accessibility blockers are fixed or documented with an approved exception.
- Platform support claims match the tested matrix.

---

## Phase 4 — Open-Meteo distribution and reliability review (P1)

**Owner:** product owner and maintainer  
**Findings:** MUN-04, MUN-05, MUN-14  
**Dependency:** intended distribution model and expected traffic.

Tasks:
1. Recheck the current [Open-Meteo terms](https://open-meteo.com/en/terms), [pricing](https://open-meteo.com/en/pricing), attribution and applicable license before distribution.
2. Decide whether the app remains a non-commercial classroom prototype or expands to public/commercial use. Do not assume free endpoint terms permit ads, subscriptions or broad commercial distribution.
3. Estimate requests per active user, refresh behavior, city changes and shared-network traffic. Account for provider limits by IP/application.
4. Verify attribution and source/model timestamp display remain visible.
5. Test provider schema changes, malformed arrays, unknown WMO codes, clock skew, delayed responses and rate-limit errors with fixtures.
6. Keep explicit refresh semantics and the ten-minute reuse behavior documented.
7. Define a provider migration/availability plan only if the current terms or usage model require it.

**Acceptance criteria**
- Intended use is consistent with current provider terms and license.
- Expected usage stays within applicable limits with a documented safety margin.
- Failure states are tested and no synthetic weather is displayed as live.
- Provider attribution and timestamp semantics are understandable to users.

---

## Phase 5 — Authoritative advisories and notification capability (P2, separate feature)

**Owner:** capstone/product team  
**Finding:** MUN-07  
**Dependency:** approved authoritative data source, platform delivery design, privacy review and device access.

Tasks:
1. Define the exact advisory scope: heavy rain, flood, thunderstorm, heat, wind, evacuation or other categories.
2. Identify official sources (for example PAGASA and relevant Muntinlupa/DRRMO channels), confirm permitted access, update frequency, attribution and reliability. Do not scrape private or unstable channels as the sole source.
3. Preserve the distinction between MUNORA and existing official incident/reporting systems such as iRespond; do not imply that MUNORA replaces them.
4. Define source, issued-at, valid-until, affected area, severity, revision/cancellation and confidence/provenance fields.
5. Define location consent and data minimization. Do not collect background GPS unless a reviewed requirement and consent flow justify it.
6. Design Android/iOS notification permission, token lifecycle, opt-out, deduplication, quiet hours, expiry, delivery monitoring and fallback behavior.
7. Test delayed, duplicate, withdrawn, stale and geographically mismatched advisories.
8. Run a controlled pilot with clear non-emergency disclaimers before wider rollout.

**Acceptance criteria**
- Every advisory can be traced to an authorized source and valid timestamp.
- Expired/withdrawn advisories are removed or visibly marked.
- Notification consent and opt-out work on supported devices.
- Delivery latency, failure and duplicate rates are measured.
- The product never claims guaranteed delivery or replaces official emergency channels.

---

## Phase 6 — Optional Firebase backend (P2, only with separate approval)

**Owner:** project owner and backend maintainer  
**Findings:** MUN-02, MUN-08, MUN-14  
**Dependency:** explicit written owner approval of costs and architecture; complete App Check client integration; approved Firebase project policy.

**Do not start this phase under the current no-paid-services prototype decision.**

If the owner later approves a backend, create a separate design and implementation PR with these tasks:
1. Register Firebase apps for each supported platform and initialize Firebase in Flutter.
2. Integrate production App Check providers and send current `X-Firebase-AppCheck` tokens on every backend request; handle token renewal, unsupported platforms, expiry and initialization failure without anonymous fallback.
3. Prove unauthorized/missing/expired token requests do no Firestore or provider work.
4. Review Cloud Functions and Firebase SDK deployment compatibility in a staging project.
5. Configure least-privilege IAM, Firestore TTL on `weatherInternal.expiresAt`, log retention, alerting and incident response.
6. Model expected invocation/Firestore/provider costs, configure budget alerts and upstream controls, and explicitly decide daily refresh budget. The existing 1,000/day budget cannot sustain all 17 cities every ten minutes (2,448/day).
7. Validate shared-network IP rate limiting, App Check replay assumptions, provider quotas, transaction contention and multi-instance refresh fencing.
8. Document rollback and disablement before any production deployment.

**Acceptance criteria**
- Separate owner approval and reviewed threat/cost model exist.
- App Check is enforced before database work on every supported client.
- Real staging tests cover abuse, contention, TTL, failure and cost behavior.
- Production deployment is separately approved; no deployment is implied by completing source changes.

---

## Phase 7 — Predictive analytics research (P2, separate capstone scope)

**Owner:** capstone research team  
**Finding:** MUN-07  
**Dependency:** adviser-approved problem statement, lawful historical dataset, target labels and evaluation protocol.

The current Tips tab is deterministic rules. It is not an AI model, predictive analytics engine, official forecast or validated confidence estimator. If the capstone requires a genuine model, scope it separately instead of relabeling the existing rules.

Tasks:
1. Define the prediction target (e.g. probability of rain in a defined area/time horizon) and prediction horizon.
2. Identify lawful, sufficiently representative historical weather data and document missingness, geographic coverage, update frequency and source rights.
3. Define train/validation/test splits by time to avoid leakage; retain a held-out period.
4. Establish baselines before selecting a model. Compare against simple climatology and persistence baselines.
5. Select appropriate metrics (e.g. Brier score, calibration, precision/recall at operational thresholds, MAE/RMSE for continuous targets) and evaluate across seasons/locations.
6. Assess class imbalance, uncertainty, drift and subgroup/geographic performance.
7. Expose model source, issue time, horizon, uncertainty and limitations in the UI. Do not display confidence percentages unless calibrated and supported by evaluation.
8. Keep official advisories separate from model predictions and retain safe fallback when model/provider data is unavailable.

**Acceptance criteria**
- Reproducible training/evaluation pipeline and documented dataset provenance.
- Held-out metrics beat the declared baseline under the chosen evaluation protocol.
- Calibration/limitations and failure behavior are documented.
- Adviser approves claims; UI labels prediction as experimental and not an emergency warning.

---

## Phase 8 — Product polish and maintenance (P3)

**Owner:** team  
**Dependencies:** P0/P1 safety and release gates.

Candidate tasks:
- Expand accessibility/localization and visual regression coverage.
- Review city naming, coordinate precision and data-source attribution.
- Add privacy notice and a concise data-flow explanation.
- Add non-sensitive diagnostics/telemetry only after consent and privacy review.
- Keep dependencies and GitHub Actions pins current through reviewed updates.
- Add support/incident contact and a versioned release checklist.
- Reassess app package identifier, icons, store metadata and platform permissions before distribution.

**Acceptance criteria**
- Every added feature has tests and a documented owner.
- Privacy and safety disclosures match actual behavior.
- Maintenance updates pass the same exact-commit verification gates.

---

## Suggested execution order

1. Complete Phase 0 owner action immediately; keep Firebase disabled.
2. Complete Phase 1 on the exact current release-candidate commit.
3. Complete Phase 2 Android build/signing validation.
4. Complete Phase 3 device/privacy/accessibility validation.
5. Complete Phase 4 provider terms/traffic review before wider distribution.
6. Decide with the adviser whether Phase 5 and Phase 7 are required capstone deliverables.
7. Consider Phase 6 only if the owner explicitly changes the no-paid-backend decision.
8. Schedule Phase 8 as ongoing maintenance.

## Definition of done for a prototype release

- Historical provider key revoked.
- Current source contains no committed secrets.
- Flutter/backend tests, static analysis, dependency audit and web build pass on the exact release candidate SHA.
- Android debug/release signing gate is validated on the supported SDK machine.
- Supported-device and accessibility smoke tests are recorded.
- Open-Meteo terms/attribution fit the intended distribution.
- Alerts remain clearly marked demo; Tips remain clearly described as rule-based.
- Firebase backend remains disabled unless a separate approval and release process is complete.
- Audit, limitations, owner actions and versioned release evidence are updated.
