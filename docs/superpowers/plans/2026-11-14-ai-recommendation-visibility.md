# AI Recommendation Visibility Implementation Plan

**Goal:** Make the approved existing recommendation discoverable and distinguish
its AI rain estimate from forecast-based advice.
**Spec:** ../specs/2026-11-14-ai-recommendation-visibility-design.md
**Method:** Inline TDD; preserve model/notification behavior and provider count.

- [x] Add failing behavior tests for a shortcut expanding/scrolling to the planner
  without resetting activity, Home-to-Tips entry, and unavailable-weather refresh
  bypassing the live memory cache. Update existing label assertions intentionally.
- [x] Add the outlook summary/shortcut, planner open action and screen wiring;
  route unavailable-weather refresh through the existing WeatherView action.
- [x] Clarify prediction, recommendation, activity guidance and model agreement
  labels. Preserve full-window probability, severe warnings and experimental copy.
- [x] Run focused tests, full Flutter suite/analysis, web build and browser flow
  at mobile/desktop sizes; independently review changes and update documentation.
- [x] Publish a separate draft PR against master without merging or deploying.
