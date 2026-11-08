# MUNORA UI, Alerts and Tips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Port the supplied design to Flutter and replace demo alerts with explainable forecast notices, adding tip filters and expandable explanations.

**Architecture:** Keep WeatherService and WeatherSnapshot unchanged. Derive alerts from existing tested weather recommendation rules; share visual components across all screens and use WeatherView for loading, refresh and stale-data behavior.

**Tech Stack:** Flutter, Dart, material_ui, google_fonts, flutter_svg for supplied SVG assets.

**Spec:** docs/superpowers/specs/2026-11-08-munora-redesign-design.md

## Global Constraints

Keep five-day forecasts and existing notification behavior. No AQI, seven-day extension, generative AI or confidence scores. Label alerts as app-generated, never official. No invented weather values or claims of radar, personalization or training.

## Review Focus

- Stale data must not imply an all-clear or present current notices.
- City changes must replace notices and explanations together.
- Filters with no matching tips need a clear empty state.
- Narrow screens and large text must not overflow or hide navigation.
- Notification controls must retain real permission and platform behavior.

### Task 1: Forecast notices

Files: create lib/services/weather_alerts.dart and test/weather_alerts_test.dart; consume WeatherSnapshot and weatherRecommendations.
Interface: List<WeatherTip> weatherAlerts(WeatherSnapshot weather, DateTime now). Return only storm, rain, heat and wind recommendations; return stale refresh guidance for unusable snapshots; do not return routine guidance as an alert.
- [ ] Write tests for heat/wind boundaries, rain/storm, stale snapshots and benign conditions.
- [ ] Run tests and observe missing behavior.
- [ ] Implement the pure adapter and run alert and recommendation tests.

### Task 2: Shared styling and all screens

Files: theme.dart, app.dart, widgets/bottom_nav.dart, widgets/weather_icon.dart, new widgets/atmosphere.dart, all five screens, pubspec.yaml and bundled assets.
Interfaces: AtmosphereScreen(title, subtitle, active, onNavigate, child, actions); GlassCard(child, padding, color); retain public screen constructor dependencies and shared weather service.
- [ ] Bundle exact static imagery/icons referenced by the supplied design, with local Inter and Abyssinica fonts; use Flutter SVG rendering.
- [ ] Apply the gradient and glass design to all five screens. Preserve real weather values, five-day grouping and loading/error behavior.
- [ ] Replace demo Alerts with WeatherView + weatherAlerts, explanation expansion, refresh guidance and official-advisory link. Do not add new notification delivery semantics.
- [ ] Make Tips stateful with All/Rain/Heat/Outdoor/Travel filters and explanations. Keep NotificationSettings connected. Filters reset on city change and never hide stale-data guidance.
- [ ] Write and run behavioral widget tests before implementing filters/alert wiring: benign/stale alerts, city change, category empty state and explanation expansion.
- [ ] Run existing and new widget tests at narrow width and larger text; fix regressions.

### Task 3: Verification and delivery

Files: README.md and docs/WEATHER_RECOMMENDATIONS.md.
- [ ] Document notice thresholds, forecast scope and limitations; remove obsolete demo-alert documentation.
- [ ] Run flutter analyze, flutter test and flutter build web --no-web-resources-cdn.
- [ ] Render the original prototype and Flutter app in Chromium; compare all five screens and check navigation, city picker, filters, explanations and responsive layout.
- [ ] Obtain a fresh whole-branch review, resolve significant findings and rerun affected checks.
- [ ] Commit changes, create a draft PR and attach it to this chat. Do not merge or deploy.
