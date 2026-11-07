# Security and Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit the whole current project, fix verified security/reliability/performance defects, and document residual risks and reproducible evidence.

**Architecture:** Keep the Flutter/Node boundaries and no-login model. Validate and bound untrusted weather at both boundaries, reduce redundant work, harden dormant backend release controls, and preserve the user's Spark budget.

**Tech Stack:** Flutter/Dart/http/shared_preferences; Node 22, Firebase Admin/Functions; native Node tests and Flutter tests; Chromium/Playwright fixture checks.

**Spec:** `docs/superpowers/specs/2026-11-07-security-performance-design.md`

## Global Constraints

- Baseline commit `47658457598b168688b8e19ee221364e63e4fcd0`; no resident login or billing activation.
- Response maximum 128 KiB; maximum 40 forecast samples; condition length 120.
- Live observation age 3 hours; future skew 5 minutes; offline age 24 hours.
- No live load tests, credential printing, destructive history rewriting or rule deployment.
- Execute directly as the user requested; review/audit subagents are read-only.

## Review Focus

- A valid JSON body can still contain impossible measurements or misleading timestamps: reject before cache publication (Tasks 1/2).
- Navigating between screens can overlap requests: share same-city requests and preserve cache order (Task 2).
- Slow or oversized streams can outlive widget timeouts: abort and enforce streaming bounds (Tasks 1/2).
- Provider outages can exhaust a shared daily budget: enforce cooldowns and fenced refresh publication (Task 1).
- Large accessibility text and repeated demo interaction can exhaust layout/state: exercise actual screens and bound chat work (Task 3).

## Tasks

### Task 1: Backend integrity, availability and dependencies

Files: `functions/weather.js`, new `functions/store.js`, `functions/index.js`, backend tests, package manifests/lock.
Interfaces: `createWeatherHandler({store,getKey,authorize,enabled,...})`; store `get/put/rateLimit/reserve/acquire/release` with owner fencing; `fetchWeather` returns the existing weather DTO.
- [x] Add failing native tests for invalid/future/stale measurements, bounded bodies, untrusted cache, disabled/unauthorized zero-database requests, outage cooldown and cross-instance stale publication.
- [x] Run `node --test --test-isolation=none` and record the expected failures.
- [x] Implement bounded parsing, validated weather DTOs, default-disabled production backend/App Check, refresh ownership/cooldowns, transactional publication, and compatible patched Firebase packages.
- [x] Run all backend tests, function export smoke check, and `npm audit --json`; record actual results and remaining advisories.
- [x] Commit this task.

### Task 2: Flutter request, data and lifecycle boundaries

Files: `lib/services/weather_service.dart`, `lib/models/weather_snapshot.dart`, `lib/widgets/weather_view.dart`, fixture/service/widget tests.
Interfaces: `fetch(city,{force:false})`; compatible snapshot DTO parsing with bounded, sorted samples and freshness predicates. Existing `cached(city)` remains offline-safe.
- [x] Add failing tests for duplicate concurrent fetches, fresh reuse/manual refresh, oversized/malformed body, time validation, timeout cancellation and cache preservation.
- [x] Run the Flutter suite and confirm the failures reproduce the defects.
- [x] Implement streamed abortable requests, limits, per-city coalescing, fresh reuse and validated persistence; revalidate saved UI on retry/resume/expiry.
- [x] Run all Flutter tests and analysis; record the results.
- [x] Commit this task.

### Task 3: User-facing and release safeguards

Files: Home/Forecast/AI screens and tests; Android Gradle/manifest, macOS entitlements, `.gitignore`, CI.
- [x] Add failing widget checks at 320px/2x text scale and repeated demo-chat submissions/disposal.
- [x] Fix overflow, bound chat input/history/timers, dispose resources, remove unsupported confidence claims, and remove the cosmetic three-second splash delay after a regression test.
- [x] Remove debug signing fallback; require external release-signing configuration; declare outbound network access and disallow cleartext Android traffic.
- [x] Add secret exclusions and dependency/CI checks with pinned action revisions where verified.
- [x] Run the full suite, config validation and release web build. Document Android/macOS/iOS verification limits rather than claiming native success.
- [x] Commit this task.

### Task 4: Measurements, report and independent review

Files: deterministic performance probes, `docs/audit/2026-11-07-security-performance.md`, Firestore audit JSON and implementation ledger.
- [x] Measure backend cold/cache-hit/burst behavior and bounded-request counts with fixtures; record wall-clock distributions and environment.
- [x] Build and inspect mobile/desktop fixture workflows, failed updates and large text; measure web assets and browser startup with network/provider costs excluded.
- [x] Report each finding, severity, trigger, mitigation, source location, state and unresolved owner action; include dependency and rules-check evidence.
- [x] Request one fresh whole-change review, address important issues with regression tests, run final verification and record residual risk.
- [ ] Publish a reviewable draft branch/PR if permitted by tools; never merge or deploy without the applicable authorization.
