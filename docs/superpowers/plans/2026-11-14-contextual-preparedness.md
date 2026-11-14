# Contextual Preparedness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Surface practical contextual weather recommendations and clearly labeled general disaster preparedness in Tips.

**Architecture:** A pure evaluator combines existing forecast rules and eligible AI rain output. A Tips card reuses RainOutlookBuilder; no new network or push work.

**Tech Stack:** Flutter/Dart and existing local rain model.

**Spec:** `docs/superpowers/specs/2026-11-14-contextual-preparedness-design.md`

## Global Constraints

- No inferred active flood/typhoon warning, safe-road claim or all-clear.
- Saved/stale weather cannot drive current contextual guidance.
- Preserve existing forecast/planner/notification behavior and AI validity rules.

## Review Focus

- Low/unavailable AI cannot cancel forecast storm/rain precautions.
- High heat index below existing temperature thresholds still yields heat advice.
- Changing city or expiring weather invalidates old contextual advice.
- General preparedness is visibly separate from live warnings.
- Narrow phone screens and large text must remain usable.

### Task 1: Context evaluator

Files: create `lib/services/preparedness_recommendations.dart`, `test/preparedness_recommendations_test.dart`.
- [x] Write decision tests against `preparednessRecommendations(weather, outlook: ..., live: ..., now: ...)` for rain threshold, forecast fallback, heat index, simultaneous hazards, stale/saved inputs and general precautions.
- [x] Run focused tests and observe missing-feature failure.
- [x] Add typed recommendation values containing ID, title, action, source, reason and optional validity window; implement the fixed rules from the design.
- [x] Run focused tests and verify green.

### Task 2: Visible Tips card

Files: create `lib/widgets/preparedness_recommendations.dart`, `test/preparedness_recommendations_widget_test.dart`; modify `lib/screens/ai_screen.dart`.
- [x] Write tests for rendered contextual sources/actions, general expansion disclosure, saved mode, city switch and narrow/large-text layout; observe missing-feature failure.
- [x] Add a compact card after the AI outlook, using existing memoized model loading and fresh weather context. Display why/time for contextual items and general precautions behind a labeled expansion.
- [x] Run the widget tests and existing planner/filter tests.

### Task 3: Verify and document

Files: update `README.md` with scope and source semantics.
- [x] Run `flutter analyze`, `flutter test`, and `flutter build web --no-web-resources-cdn`; all must pass.
- [x] Inspect the rendered Tips card in a browser at phone and desktop sizes.
- [x] Review diff and create a PR describing the tested source distinctions and remaining official-feed limitation; do not merge automatically.

## Execution record

- Baseline: 124 Flutter tests passed at `e8c0171d0ea64023be15191845ca5e591d91b64a`.
- Evaluator/widget tests were introduced before implementation and failed for the missing feature.
- Ruling: preserve the existing featured forecast cards and filters; the new compact checklist provides a single preparedness entry point without changing alert or activity-planner behavior.
- Review correction: combined rain advice preserves separate AI and forecast validity windows. A regression covers rain forecast five hours out while the AI covers only three hours.
- Added periodic reevaluation coverage across weather expiry, preserving general preparedness.
- Full Flutter suite: 138 passed. Static analysis: no issues. Release web build and Wasm dry run passed. Browser regression passed at 390×844 and 1366×900 with six provider calls per scenario and no page errors. Both review findings were addressed before publishing.
