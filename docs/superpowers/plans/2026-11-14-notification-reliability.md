# Notification Reliability Implementation Plan

> Execute inline using superpowers:executing-plans and test-driven development.

**Goal:** Address the four approved audit findings without changing deployment.
**Architecture:** Typed upstream errors, fenced retry state in the existing D1
lease, startup/resume reconciliation in the existing Android services.
**Tech Stack:** Node 24, Cloudflare Workers/D1, Flutter 3.47.9, Workmanager/FCM.
**Spec:** ../specs/2026-11-14-notification-reliability-design.md

## Global constraints

- Preserve one-hour duplicate protection for uncertain sends.
- Explicit transient rejections retry after at least five minutes/Retry-After.
- No schema migration, raw errors in logs, permission prompts on startup or deploy.

## Review focus

Expired lease owners, repeated rejection, prior successful history, denied OS
permission, and offline legacy cleanup must not corrupt state or silently stop
the selected delivery mode. Tests below cover these cases where feasible.

### Task 1: Backend retries and diagnostics

Files: backend/src/weather.mjs, backend/src/worker.mjs, backend/test/*.test.mjs.
Interface: HTTP rejection carries safe status/retry delay; monitor retains its
existing return values and dependency interface. Logs expose stage and category.

- [x] Add behavioral tests for HTTP status/Retry-After, 503 retry after five
  minutes, 429 delay, previous history, uncertain send cooldown, and expired owner.
- [x] Run tests and observe the new cases fail against the original behavior.
- [x] Implement typed errors, fenced history restoration/retry lease and safe logs.
- [x] Run the complete backend suite, including real workerd adapter tests.

### Task 2: Android delivery mode reconciliation

Files: lib/services/notification_service.dart, lib/services/push_notifications.dart,
lib/main.dart, lib/app.dart, test/notification_service_test.dart.
Interface: NotificationService.initialize() reconciles local delivery without
prompting for permission and also initializes/cleans up push as appropriate.

- [x] Add platform-channel tests: persisted local opt-in restores Workmanager;
  opt-out cancels; startup does not ask permission; offline cleanup does not block
  local job; push mode retains local cancellation.
- [x] Observe regression failures, then implement startup/resume reconciliation.
- [x] Run focused tests, Flutter analysis and the complete Flutter suite.

### Task 3: Documentation and final verification

Files: README.md, docs/DEPLOYMENT_STATUS.md, docs/setup/DEPLOY_WEATHER_PUSH.md,
docs/setup/VERIFICATION_WEATHER_PUSH.md.

- [x] Correct obsolete deployment claims and describe retry/logging/migration behavior.
- [x] Record exact checks run, source revision and remaining device/live checks.
- [x] Run backend/model tests, Flutter analysis/tests/web build; review the diff.
- [x] Publish a branch and reviewable PR using the connected GitHub tools.
