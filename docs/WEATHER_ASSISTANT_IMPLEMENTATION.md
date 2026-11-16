# Integrated weather assistant improvements

This extends the notification repair in `NOTIFICATION_FIX_2026-11-16.md` with the
remaining issues supplied by the user. No further APK was built while the issue
list was being collected. Updated Android builds follow source verification.

## Findings and implemented behavior

- **AI visibility and interpretation:** a real experimental logistic-regression
  rain model already existed, but its result was easy to miss and Home lacked a
  consolidated explanation of forecast precautions. Home now places Smart
  Recommendations and the separate AI rain outlook immediately after the weather
  hero. Rule-based advice explains actual temperature, apparent temperature,
  humidity, rain probability, wind and UV inputs when available. It evaluates
  forecast conditions in the next six hours and avoids inventing missing values.
  Saved location-specific activity routines appear on Home with relevant rain
  preparation and a working shortcut to the existing full-window activity planner.
- **Real AI vs rules:** the bundled validated model still consumes structured
  temperature, humidity, pressure, wind, WMO code, city and timestamp. It requires
  fresh supported input; model failure never blocks weather or rule-based advice.
  Model probabilities are experimental and distinct from the rule explanations,
  multi-model agreement and planner thresholds. No remote generative AI or new AI
  credentials are introduced. No conversational text is passed off as model output.
- **Saved AI:** successful local predictions are persisted by city with their
  original input time, probability and model version. Offline, the last valid
  result is labelled saved reference with its original coverage window and model
  version. It never becomes a new forecast or a current planning probability.
- **Dynamic visuals:** Home previously hardcoded one image. A bundled vector scene
  now maps provider WMO codes to clear, partly cloudy, cloudy, rain, storm, fog,
  snow and unknown visuals, with condition-specific sky colors and symbols.
  Provider `is_day` selects day/night; older records fall back to the observation's
  Philippine hour (approximately 06:00–18:00). Labels distinguish current and saved
  estimates. Changes crossfade, reduced-motion settings disable transitions, and
  there are no remote images or continuous particle animations consuming battery.
- **Offline data:** validated core snapshots already persisted but expired after
  24 hours. Saved-reference retention is now seven days without loosening live
  freshness or notification eligibility. Original hourly/daily dates, conditions,
  metrics and selected city remain available through the existing navigation.
  Local weather advice can be derived from the saved snapshot with explicit saved
  labels; it is not represented as a current warning. No cache on first use means
  an honest unavailable/retry state, not fabricated weather.
- **Connectivity:** transport changes now update saved/offline state and refresh
  after reconnection, including a reconnect arriving during an active request.
  Pending requests remain bounded and location-request guards remain intact.
  Connection hints do not establish internet access: actual HTTPS results remain
  authoritative for captive portals, failures and live status. Foreground network
  refresh timers pause in the background; notification scheduling remains separate.
- **Optional forecast insights:** raw validated detail/model responses persist with
  their original retrieval time. Disk fallback is marked saved and cannot pass
  live freshness checks. Timestamped saved-reference panels retain the available
  hourly data in Tips and Alerts while the live planner remains conservative.
  A successful fresh detail response is preserved if only the model comparison
  fails; missing comparison data stays unavailable rather than inventing agreement.

## Files and dependencies

- `lib/widgets/smart_home.dart`: explained Home guidance and saved routine context.
- `lib/widgets/weather_scene.dart`: offline WMO/day-night scenes and transitions.
- `lib/screens/home_screen.dart`: integration and prominent insight placement.
- `lib/services/saved_rain_insight.dart`, `rain_outlook_builder.dart`,
  `ai_rain_outlook.dart`: persist valid ML results and show saved provenance.
- `weather_snapshot.dart`, `open_meteo.dart`: retained weather and validated
  optional provider day/night data, with compatibility for old cache records.
- `weather_recommendations.dart`: saved-reference eligibility and humid-weather
  guidance, retaining strict live eligibility for notifications.
- `weather_view.dart`: connection subscription, guarded reconnection and lifecycle.
- `weather_insights.dart`, `insight_panels.dart`, `ai_screen.dart`,
  `alerts_screen.dart`: optional persistence, saved provenance and reference views.
- `pubspec.yaml`, lockfile and generated platform registration: connectivity_plus
  6.1.5. Its Android manifest supplies ACCESS_NETWORK_STATE (normal permission,
  no runtime prompt). Existing notification permission and selected-city behavior
  remain; no GPS permission, exact alarm or foreground service is added.
- Added cache/reconnect, saved-ML, optional-insight, Home-guidance and scene tests;
  existing expiration tests now use eight-day-old records to verify the new bound.

Core weather and preferences continue to use bounded shared_preferences JSON;
SQLite from the notification fix remains dedicated to cross-isolate delivery
coordination. Invalid, oversized, future or expired saved records are rejected.
Storage failures do not discard successful network responses. References retain
original times; restoring connectivity never changes an old timestamp to now.

## Verification and remaining device acceptance

The local full suite passes 160 tests. Analyzer and CI outcomes for the final
revision are recorded in the PR. CI builds the integrated default local APK and
optional push APK only after implementation; the default APK needs no server
push deployment. The push build requires the coordinated backend rollout already
described in the notification report. No production deployment or live push
broadcast was performed.

Physical Android acceptance remains required:

1. Load a selected city online, save an activity routine, and verify the model
   and rule-based explanations are distinct and use the displayed weather.
2. Enable airplane mode, restart the app, and visit Home, Forecast, Alerts and
   Tips. Verify original timestamps, saved forecasts, saved AI coverage and saved
   optional details. A new location without saved data must not show another city.
3. Reconnect in foreground and after background/resume. Verify one coherent
   updated view, no stale city response, no endless spinner and no false live AI.
4. Exercise weather fixtures for every scene, provider day/night and unknown-code
   fallback. Inspect contrast, scrolling, reduced motion and large text on-device.
5. Complete the notification permission/channel, real scheduling, Doze, reboot,
   opt-out, duplicate-suppression and optional FCM tests in the notification report.
6. Observe responsiveness and battery use over normal device use. Automated widget
   and platform-call tests cannot prove OEM background delivery or battery behavior.

These are forecast-based precautions, not official emergency or road-flooding
warnings. Prospective real-world validation of the experimental rain model remains
necessary; offline caching does not create fresh weather or remote AI responses.
