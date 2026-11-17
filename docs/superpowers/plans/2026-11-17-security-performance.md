# MUNORA Security and Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** address verified source weaknesses and measured/static performance costs without changing unrelated behavior.
**Architecture:** retain Flutter public-weather services and Worker/D1/AI/FCM boundaries; change trusted decision points and bounded local state only.
**Tech Stack:** existing Dart/Flutter, Node24, Worker ES modules/D1, Playwright; no new dependencies.
**Spec:** `docs/superpowers/specs/2026-11-17-security-performance-design.md`.

## Global Constraints

- No production probes, credential reuse, paid inference, cloud changes or history rewriting.
- Preserve weather/model/notification contracts and current UI styling.
-12 question/answer pairs maximum retained in the open chat; request history remains6 messages/2400characters.
- Keep atomic2/minute/IP,10/day/IP and60/global/day limits; no state allocation when global quota is already exhausted.
- Run cached dependencies only inside bounded offline OS sandbox; no dependency installs.

## Review Focus

- Global quota reaching60 between precheck and UPSERT: guard allocation atomically.
- Old chat eviction must preserve paired roles, most recent context and newest scroll/cancel.
- Corrupt local cache must fail closed without rejecting valid existing plans.
- Browser fixture routing must deny unexpected external requests and label timing scope honestly.
- Source reports must preserve baseline refs, external blockers and unavailable-validator disclosure.

### Task1: quota allocation containment
**Files:** `backend/src/ask_munora.mjs`, `backend/test/ask_munora_workerd.test.mjs`.
**Interfaces:** `claimQuota(db,ip,now,signal)` keeps status/retry behavior; SQL decides whether per-IP allocation is allowed.
- [x] Add D1 regression: preload global60;3 distinct-IP calls return429; usage-row count stays1 and inference never runs. Add a race regression that saturates global between a read and the next per-IP allocation.
- [x] Run fixture tests; expected RED: rows grow after full global budget.
- [x] Add cheap global read before cleanup/hash and global guard inside per-IP UPSERT; keep final atomic global claim and accurate Retry-After. No transactional API assumptions.
- [x] Run full backend suite offline; expected all tests PASS, quota concurrency acceptance unchanged.
- [x] Commit task.

### Task2: bounded chat session
**Files:** `lib/widgets/ask_munora_chat.dart`, `test/ask_munora_widget_test.dart`.
**Interfaces:** existing Ask service request contract unchanged; chat retains latest12paired exchanges and explains eviction.
- [x] Add regression:15 successful exchanges retain only latest12, evict first3, preserve most recent response, and follow-up sends paired bounded context. Clear resets eviction notice/history.
- [x] Run focused Ask tests; expected RED: old exchanges remain rendered.
- [x] Evict whole oldest user/assistant pairs and corresponding answer metadata; retain current scroll/cancel/keyboard/accessibility behavior.
- [x] Run focused tests and full Flutter suite offline; expected PASS.
- [x] Commit task.

### Task3: planner cache resilience
**Files:** `lib/services/planner_preferences.dart`, `test/planner_preferences_test.dart`.
**Interfaces:** `loadRoutine` and `lastAssessment` keep null-on-corruption; saved assessment shape remains `{plan,summary}`.
- [x] Add regressions: routineJSON>1024chars rejected before parsing; assessmentJSON>8192chars rejected; non-string/blank plan/summary rejected; valid records unchanged.
- [x] Run focused tests; expected RED for oversized/wrong-type valid JSON.
- [x] Apply read caps and exact required value-type checks; no local encryption or account-auth changes.
- [x] Run focused and full Flutter suites; expected PASS.
- [x] Commit task.

### Task4: dependency maintenance and current benchmark
**Files:** `.github/dependabot.yml`, `tools/browser_performance.cjs`, `tools/browser_performance.test.cjs`, `docs/audit/2026-11-17/PERFORMANCE.md`.
**Interfaces:** current direct Open-Meteo fixture URLs, `MUNORA_PREVIEW_URL`, JSON timing summary; no legacy baseline/hardened speed claims.
- [x] Correct npm update directory to/backend; retain pub/actions schedules and add pip/ml maintenance.
- [x] Add failing harness tests for current provider fixture units, shape, city and unexpected-host rejection.
- [x] Replace obsolete weather.example.invalid benchmark with bounded current-provider fixtures; measure cold weather visibility/navigation/request counts at390/1366px and report intentional5second splash separately.
- [x] Run offline harness tests, bounded component benchmark and sandboxed web/browser smoke; expected PASS with no unexpected page errors or network calls.
- [x] Commit task.

### Task5: review and evidence handoff
**Files:** audit report, structured findings/coverage, implementation ledger.
- [x] Run full backend/Flutter suites, analysis, web compilation and source/config checks; record failures/gaps without hiding supervisor issues.
- [x] Fresh whole-change reviewer checks plan/spec and residual risks. Fix important issues with RED→GREEN, then rerun affected suite.
- [x] Record precise source/test results and deferred owner/device/advisory checks. Preserve formal packaged-validator limitation.
- [x] Publish reviewable changes without merging or releasing/deploying production changes.
