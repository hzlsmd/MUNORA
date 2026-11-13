# AI Rain and Heat Index Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the approved offline rain predictor and replace Pressure with current Heat Index.
**Architecture:** Offline Python training exports validated numeric JSON; Flutter performs local inference and NWS heat-index calculation. Existing push rules stay unchanged.
**Tech Stack:** Python/scikit-learn, Dart/Flutter, JSON assets.
**Spec:** docs/superpowers/specs/2026-11-13-ai-rain-heat-index-design.md

## Global Constraints
- No billing, paid inference, fabricated weights, random temporal splits or future-label leakage.
- Model activation requires held-out Brier improvement over both baselines.
- Reanalysis limitations must remain visible; no official warnings or certainty claims.

## Review Focus
- Purge three-hour targets across year splits; test missing and unordered hours.
- Group shared grid/time duplicates and report coverage.
- Reject malformed/missing models, stale inputs and unsupported cities.
- Heat index uses unrounded inputs and applicability screening, not apparent temperature.
- Model loading cannot block startup or change background push behavior.

### Task 1: Training and artifact
Files: ml/*.py, ml/tests/*, assets/models/rain_model.json, docs/AI_RAIN_MODEL.md.
- [x] Write and observe failing tests for labels, splits, feature parity, bounds and baselines.
- [x] Implement rate-limited provenance-preserving data loader and logistic pipeline; train2021–2023, validate2024, freeze and test2025 once.
- [x] Export schema1 JSON with featureNames, means, scales, coefficients, intercept, bounds, cities, validationPassed, metrics and provenance. If gate fails, do not activate.
- [x] Run Python tests and document actual metrics and domain limits.

### Task 2: Heat Index
Files: lib/services/heat_index.dart, lib/models/{weather_snapshot,city_weather}.dart, lib/widgets/weather_cards.dart, test/heat_index_test.dart.
- [x] Write failing NWS reference/boundary/invalid-input tests.
- [x] Implement double? heatIndexCelsius(double temperatureC,double humidity), applicability screening and corrections; preserve raw humidity/pressure for ML.
- [x] Replace shared card with HEAT INDEX and shade explanation, retaining Feels Like.
- [x] Run focused and existing Flutter tests.

### Task 3: Flutter inference and UI
Files: lib/services/rain_model.dart, lib/widgets/ai_rain_outlook.dart, lib/screens/{home_screen,ai_screen}.dart, pubspec.yaml, test/rain_model_test.dart.
- [x] Coordinate exact schema/features with training task; add failing artifact/freshness/golden-vector tests.
- [x] Implement validated JSON loading and stable logistic inference, freshness<=30min, future skew<=5min, three-hour estimate-time window.
- [x] Add reusable experimental AI outlook, unavailable fallback, no startup delay or push changes.
- [x] Run full Flutter/backend tests, analysis, web and browser checks; review final diff before publishing PR.

Native/phone acceptance remains pending; the CI debug build is prepared for remote validation.
