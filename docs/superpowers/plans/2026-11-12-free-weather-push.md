# Free Weather Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare free-tier city monitoring and Android FCM integration with one-hour reminders.

**Architecture:** Worker cron partitions 17 city checks across five minute slots; each city is checked every five minutes. D1 leases prevent concurrent city sends. Public FCM city topics avoid a device registration API.

**Tech Stack:** JavaScript ES modules, Node test runner/SQLite, Cloudflare Worker/D1, Flutter, Firebase Messaging.

**Spec:** docs/superpowers/specs/2026-11-12-free-weather-push-design.md

## Global Constraints

- No paid plans or billing enablement; no private keys in Git or chat.
- Android initially; preserve web and local-mode operation.
- One-hour reminders; fresh model estimates only; no official-warning or instant-delivery claims.
- No public send endpoint. FCM_SERVICE_ACCOUNT_JSON exists only in Worker secrets.

## Review Focus

- Overlapping cron deliveries: a D1 lease permits only one active worker per city.
- Ambiguous FCM responses: reserve delivery cooldown before sending; no immediate resend.
- Failed city unsubscribe: keep pending cleanup state and retry before enabling another city.
- Notification taps during splash: defer routing until startup finishes.
- Free-plan limits and unavailable mobile tools: report measurements/checks missing rather than claim readiness.

### Task 1: Weather monitoring backend

**Files:** backend/src/{cities,weather,fcm,worker}.mjs, backend/schema.sql, backend/wrangler.jsonc, backend/package.json, backend/test/*.test.mjs.
**Interfaces:** weatherTriggers(payload, now) -> string[]; monitorCity(city, env, now, deps) -> status; default.fetch/request and scheduled/event Worker handlers. FCM topics use stable city slugs.

- [x] Add tests for known weather thresholds, freshness, malformed arrays, one-hour suppression, SQL leases, ambiguous sends, read-only HTTP and city partitioning.
- [x] Run `node --test backend/test/*.test.mjs`; observe missing implementation failure.
- [x] Implement validated forecast adapter, limited HTTP reads, OAuth/FCM v1, persisted lease and cooldown and cron partition.
- [x] Run the complete backend test suite and a Wrangler dry-run if tooling is available; verify no credentials bundled.

### Task 2: Android push and foreground updates

**Files:** lib/services/{push_notifications,push_state}.dart, lib/app.dart, lib/main.dart, lib/services/notification_service.dart, lib/widgets/notification_settings.dart, lib/widgets/weather_view.dart, Android Gradle/manifest, pubspec.yaml, test/push_state_test.dart, test/notification_policy_test.dart.
**Interfaces:** PushState stores enabled/topic cleanup/last event state; PushNotifications synchronizes selected city, manages permission, subscriptions, foreground display and tap callbacks.

- [x] Add pure state/payload tests and one-hour policy test; run to demonstrate missing behavior if SDK available.
- [x] Configure Firebase Core/Messaging only on Android; keep feature opt-in and default build without push fully operational.
- [x] Wire city synchronization, persisted topic cleanup, foreground display and deferred tap routing. Disable local background job in push mode.
- [x] Add ten-minute foreground refresh with lifecycle pause and no overlapping calls.
- [x] Run Flutter analyze, tests, web and Android debug builds; document explicit blockers if SDK cannot be provisioned.

### Task 3: Deployment guide and review

**Files:** docs/NOTIFICATIONS.md, docs/setup/FREE_PUSH_SETUP.md, README.md, .github/workflows/checks.yml.
**Interfaces:** documented commands preserve DB/secret and require no paid services.

- [x] Add backend CI, deployment/schema commands, topic/payload contract, opt-out limitations and physical-device acceptance checklist.
- [x] Run `git diff --check`, complete backend suite and available mobile checks.
- [x] Review final diff for correctness and credential exposure, fix significant issues, and record missing live acceptance. Do not deploy from unauthenticated tools or claim push is live.
