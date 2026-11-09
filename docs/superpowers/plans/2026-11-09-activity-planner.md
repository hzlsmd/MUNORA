# Activity Planner Implementation Plan

> **For agentic workers:** use superpowers:executing-plans, implementing inline with a final independent review.

**Goal:** Personalized, explainable weather planning in Tips.
**Architecture:** Validated hourly samples feed a pure rule engine; a stateful card
persists optional routines and prior assessments locally. Existing services and
cards remain compatible.
**Tech Stack:** Flutter, Dart, Open-Meteo, SharedPreferences.
**Spec:** docs/superpowers/specs/2026-11-09-activity-planner-design.md

## Global Constraints
Free forecast-based guidance; PHT times; no trained-AI claims; no favorable result
with missing or stale inputs; no changes to background notifications.

## Review Focus
- Incomplete or unknown weather codes must not yield favorable windows.
- Thunderstorms override mild temperature/rain values.
- Hour/date rollover and device timezone must not shift saved routines.
- Async preference loads/writes cannot overwrite newer user choices or another city.
- Forecast-change comparisons must refer to the exact same plan.

### Task 1: Forecast samples and activity rules
Files: models/planning_hour.dart, services/weather_insights.dart,
services/activity_planner.dart, test/activity_planner_test.dart, weather_insights_test.dart.
Interface: PlanningHour(at, temperature, feelsLike, rain, uv, wind, code);
assessActivity(insights, activity, start, durationHours, now) -> ActivityAssessment;
findBetterWindow(...same inputs) -> ActivityAssessment?.
- [x] Write tests for activity differences, hazard override, missing/stale data,
  full-window maxima, alternatives and hour/date bounds; run RED.
- [x] Implement validated hourly parsing and pure assessments; run GREEN.
- [x] Fix existing outdoor window to consider code/wind/feels-like; test.

### Task 2: Planner and local personalization
Files: widgets/activity_planner_card.dart, services/planner_preferences.dart,
screens/ai_screen.dart, widgets/insight_panels.dart, test/activity_planner_widget_test.dart.
- [x] Write widget tests for activity/time controls, saved routine reload/removal,
  city isolation, feedback reason persistence and narrow layout; run RED.
- [x] Add planner card, PHT hourly choices, duration, results/explanations,
  alternatives, saved routines and same-plan forecast-change notices.
- [x] Add optional feedback reasons and clearing without claiming automatic learning.
- [x] Run affected tests and whole suite.

### Task 3: Review and delivery
- [x] Document heuristic thresholds, preferences and research limitations.
- [x] Source review and regression coverage (independent reviewer unavailable; author review completed).
- [x] Analyze, full tests, release web build, Chromium mobile/desktop interactions.
- [x] Commit, push and create draft PR stacked on the existing parity branch.

Validation: 76 full-suite tests passed, plus the final same-plan change widget regression. Analyzer clean, release web build passed, Chromium checks passed at 390px and 1366px. No trained model or automatic learning is claimed.
