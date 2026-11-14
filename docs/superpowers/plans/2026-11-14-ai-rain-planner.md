# AI Rain Planner Implementation Plan

> Execute inline using test-driven development and verification-before-completion.

**Goal:** Connect the approved existing AI rain outlook to activity advice.
**Architecture:** Shared typed outlook evaluation and async model loading, with a
compact planner supplement that leaves forecast assessments unchanged.
**Tech stack:** Existing Flutter/Dart model asset and weather services.
**Spec:** ../specs/2026-11-14-ai-rain-planner-design.md

## Constraints and review focus

- The model target remains the complete observation-anchored three-hour window.
- Never invent a probability for a one-hour plan or a future rolling window.
- Cached, stale, future, missing and unsupported inputs need distinct explanations.
- No AI notifications, new weather requests, telemetry, training or dependencies.
- Check partial overlap, exact end boundary, city changes, live-data loss and expiry.
- Preserve severe hourly forecast warnings even when AI rain probability is low.

### Task 1: Shared outlook evaluation

Files: lib/services/rain_outlook.dart, lib/widgets/rain_outlook_builder.dart,
lib/widgets/ai_rain_outlook.dart, test/rain_outlook_test.dart,
test/ai_rain_outlook_test.dart.

- [x] Write and observe failing tests for explicit unavailable reasons, city/time
  context and model probability preservation using existing golden-vector tests.
- [x] Implement typed outlook evaluation and shared async loading/expiry builder.
- [x] Run focused model and outlook tests, then verify no weather request changes.

### Task 2: Activity planning supplement

Files: lib/services/rain_outlook.dart, lib/widgets/ai_rain_plan_advice.dart,
lib/widgets/activity_planner_card.dart, lib/screens/ai_screen.dart,
test/rain_outlook_test.dart, test/activity_planner_widget_test.dart.

- [x] Write and observe failing coverage tests for full/partial/outside windows,
  threshold >=60%, all four activities and stale input suppression.
- [x] Pass live weather into the planner; show compact AI advice after plan check.
- [x] Verify planner results and severe warnings are preserved, including low AI
  probability, no hourly data, saved-only weather and narrow/large-text layouts.

### Task 3: Verification and delivery

- [x] Update AI documentation with the coverage contract and validation limits.
- [x] Run complete Flutter analysis/tests and web build; model/backend checks if
  their inputs or implementation change. Review the whole diff independently.
- [x] Publish a separate reviewable draft PR against master without merging.
