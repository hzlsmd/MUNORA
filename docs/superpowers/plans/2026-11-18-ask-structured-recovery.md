# Ask structured recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement improvements 2–6 with enforceable weather grounding and useful failure recovery.
**Architecture:** Opt-in v2 shares current validation, quota and weather fetch; bounded intent selection and canonical rendering live in a separate module. Flutter upgrades to v2 and displays structured and fallback fields.
**Tech Stack:** Existing JavaScript Worker, Node tests, Dart/Flutter.
**Spec:** docs/superpowers/specs/2026-11-18-ask-structured-recovery-design.md

## Global Constraints
Preserve v1 compatibility, quotas, freshness and cancellation; one AI attempt; no paid services/dependencies; logs contain fixed categories only; six facts of <=180 characters.

## Review Focus
- Explicit dates around Philippine midnight cannot silently shift days.
- Unsupported claims/fields cannot enter generated explanations.
- Stale/missing evidence must never produce fallback summaries.
- Repeated retries remain explicit and cancellation/city switching cannot reveal late answers.
- Filipino and follow-ups preserve intended day while labeling fallback scope.

### Task 1: Backend
Files: new backend/src/ask_structured.mjs and backend/test/ask_structured.test.mjs; modify backend/src/ask_munora.mjs and Worker harness.
Interface: structuredReply(input,context,facts,env,signal,deps) returns validated v2 answer fields; fixed selection schema, canonical data rendering, safe diagnostic categories.
- [x] Write failing regression tests and observe RED.
- [x] Implement selection validation, rendering, diagnostics and bounded recovery; integrate v2 after current shared guards.
- [x] Run full backend suite and dry-run; record results.

### Task 2: Flutter
Files: lib/services/ask_munora_service.dart, lib/widgets/ask_munora_chat.dart and their existing tests.
Interface: AskAnswer adds optional advice/explanation/forecastDate and fallback metadata; v2 service validates all fields before constructing it.
- [x] Write failing parser/widget tests.
- [x] Implement structured display, labeled fallback and manual retry.
- [x] Run all Flutter tests, analysis and web build.

### Task 3: Review and publish
- [x] Independent review, address substantive findings with regressions, final checks and PR. No automatic merge/deployment or live inference.

## Execution evidence and review
- New backend schema-v2 tests failed before implementation. Additional review regressions reproduced current-time inheritance, subject loss, explicit Filipino recovery and wrong-topic selection before fixes.
- Final backend suite: 85/85 pass, including real workerd/D1 execution of v1 and v2 paths. Flutter suite: 193/193 pass, including structured fallback/manual retry at widths 320/800 with larger text and keyboard inset. Static analysis reports no issues.
- Worker packaging dry-run passes. Flutter web build passes.
- Independent review found incorrect inherited tomorrow dates for current-time requests and loss of current/wind/UV/humidity subjects. Both are fixed with regressions. Source facts now expand on demand instead of repeating the explanation. No remaining blocker identified in review.
- Ruling: v2 bounds AI to intent selection and renders canonical claims server-side, rather than attempting to validate arbitrary prose. Costs less flexibility; uncommon questions receive a scoped summary or unsupported response. Model intent can still fail for ambiguous phrasing; a fallback is labeled explicitly.
- Version 1 is preserved for existing installed apps. An updated APK is required to use v2, structured display, and labeled recovery. No automatic merge, production deployment or live model inference performed for this branch.
