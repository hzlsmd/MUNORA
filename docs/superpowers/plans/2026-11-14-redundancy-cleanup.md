# Redundancy Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Remove repeated advice, dead code and redundant build work while preserving distinct weather/AI/notification semantics.
**Architecture:** A single Tips recommendation area owns contextual action presentation and filtering. Shared app configuration removes literal duplication; backend/runtime boundaries remain separate.
**Tech Stack:** Flutter/Dart, Node Workers, Python research and GitHub Actions.
**Spec:** `docs/superpowers/specs/2026-11-14-redundancy-cleanup-design.md`

## Global Constraints
- Preserve AI/forecast provenance, independent horizons, stale-data rejection and general-warning disclosures.
- Preserve notification opt-in, cooldowns, IDs, channel identity and mode switching.
- Do not change model weights, training pipeline or official-warning coverage.

## Review Focus
- Category filters must reset on city change and never imply an all-clear.
- One action per hazard, with all concurrent hazards preserved under All.
- Home keeps its quick rain recommendation; Tips does not repeat it.
- City order and coordinates must retain model feature compatibility.
- CI must still validate master and PR updates; standalone branches have manual dispatch.

### Task 1: Consolidate advice presentation
- [x] Add regression tests for absence of duplicate Tips advice and functional category filters; observe failure.
- [x] Consolidate `ai_screen.dart` into the checklist plus distinct prediction/UV/planner/insights components; move filters into `PreparednessRecommendations` and preserve Home rain action.
- [x] Update affected interaction/browser tests to the consolidated behavior; run focused tests.

### Task 2: Remove dead code and shared constants
- [x] Derive Dart city names from the existing coordinate registry, preserving order and values; verify request/model tests.
- [x] Centralize local/push notification configuration; verify native channel/opt-in/cancellation regression tests.
- [x] Reuse backend `topicFor`; remove proven unused demo data/type/widget/service, direct icon dependency and identical font copy.
- [x] Update CI triggers to PR/master/manual; validate workflow syntax and lockfile.

### Task 3: Review and verify
- [x] Run full Flutter analysis/tests/web/browser checks and backend/model tests.
- [x] Obtain independent review, address material findings and record retained intentional boundaries.
- [x] Create a separate cleanup PR with final scope/evidence; do not merge automatically.

Execution record: scoped audits found dead assets/code and a duplicated backend topic template. Whole-cleanup review found no Critical/Important issues; both minor refresh/filter test findings were addressed with a red-to-green regression. Provider WMO labels and ordered city coordinates were preserved exactly. See `docs/audit/2026-11-14-redundancy-cleanup.md` for intentional boundaries.

Final verification: 138 Flutter tests passed; Flutter analysis clean; release web build and Wasm dry run passed; browser regression passed at 390×844 and 1366×900 with six provider calls each and no page errors. Backend24 and model7 passed. Workflow parsed for master/PR/manual triggers. Physical Android testing remains pending.
