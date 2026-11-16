# Reliable Android weather assistant

Status: the user finished supplying the full issue list and authorized integrated implementation. Source changes are implemented; see WEATHER_ASSISTANT_IMPLEMENTATION.md for verification and physical-device acceptance requirements.

## Intent and constraints

Implement the requested notification, intelligent guidance, dynamic visuals and
offline improvements in the existing MUNORA Flutter application. Preserve the
NCR city selection, visual style, optional push mode, experimental local rain
model, forecast screens and activity planner. Never invent weather observations,
claim saved information is live, or promise exact Android background delivery.

The source reviewed is hzlsmd/MUNORA, master. No physical Android device is
connected. Flutter is not on the current environment's PATH; toolchain setup and
build feasibility must be established before reporting automated results.

## Findings from source review

- `home_screen.dart` hardcodes `assets/design/e0f7e.png` for every weather state.
- `WeatherService` already persists validated normalized forecasts in
  shared_preferences. `WeatherSnapshot.isUsable(offline: true)` rejects data
  after 24 hours; `WeatherView` removes it. Five-day forecasts consequently
  disappear during longer outages despite remaining useful as saved information.
- `WeatherView` refreshes every ten minutes and on resume, but has no connection
  listener. A newly restored connection does not immediately trigger a refresh.
- `WeatherInsightsService` caches optional forecast/planner data only in memory.
- The AI is real local logistic-regression inference from a bundled validated
  model, not a remote generative service. `evaluateRainOutlook` deliberately
  rejects saved input; previous AI results are not persisted for offline viewing.
- Core requests obtain hourly temperature and weather code only. Rain
  probability, UV and other planning fields use separate optional requests.
- Local notifications already use WorkManager, opt-in, Android permission checks
  and hourly network-constrained scheduling. Their policy allows unchanged tips
  every hour, with no quiet hours or category preferences and no clear-weather
  category. The body contains titles rather than actionable advice.
- Local delivery uses a constant ID with `onlyAlertOnce: true`, which can silence
  subsequent updates while the notification is still visible. Local channel
  creation is implicit on first delivery; push mode creates it explicitly.
- Push mode is build-time optional and replaces local work. Repository code
  cannot prove the installed device's build, Firebase configuration, permission,
  scheduler or battery settings; those remain diagnostic/device checks.

## Approaches

1. Recommended: extend existing Flutter services, shared_preferences storage,
   bundled ML model and local WorkManager delivery. Small validated JSON records
   suit the bounded 17-city cache; Room adds an unnecessary native storage layer.
2. Make a remote push/AI backend mandatory. Adds deployment and operational
   dependencies and weakens offline independence; retain existing optional push
   support instead.
3. Rewrite as native Kotlin/Room. Large migration with avoidable regression risk;
   incompatible with the request to reuse existing architecture.

The recommendation and detailed defaults below are implementation proposals,
not choices already approved by the user.

## Proposed implementation

### Weather, storage and connectivity

Extend the normalized snapshot with validated optional hourly rain probability,
humidity, apparent temperature, wind, UV and WMO code plus day/night information.
Reuse one core provider response where practical; missing optional readings must
remain unknown. Preserve compatibility with legacy cached JSON and fixtures.

Retain bounded saved weather for seven days, distinguishing recent saved
forecasts from expired forecast periods. Old observations remain visible with
their original timestamps and a prominent stale status, never as current alerts.
Do not extend the existing live freshness thresholds. Persist optional planning
data and the latest validated AI result with city, input time and model version.
Validate size, schema, city, measurements and timestamps on every disk read.
Storage failure must not discard successful network data.

Add a connectivity listener (connectivity_plus, subject to SDK compatibility)
and ACCESS_NETWORK_STATE. Treat connectivity as a transport hint, not proof of
internet access: the actual HTTPS result determines success. Render disk data
before attempting network requests; refresh on reconnection and resume, debounce
duplicate events, retain request deduplication and pause foreground timers in
background. Captive portals, timeouts, rapid city changes and disposal must not
leave a spinner or apply another city's result.

### Intelligent guidance

Add a Home Smart Recommendations section using existing preparedness/planner
rules and saved activity preferences. Explain measured/forecast reasons and
offer actionable advice for rain, storms, heat, wind and UV where data exist.
Label this guidance rule-based. Keep the separate experimental AI rain card,
its model provenance and limitations. Persist successful predictions; offline,
show the previous result with generation/input time and coverage window, clearly
mark expired coverage and fall back to rules derived from saved weather. Never
present an expired prediction as a current probability or invent AI prose.

### Android notifications

Explicitly initialize the local notification channel and background binding.
Preserve permission-on-opt-in and unique periodic work. Add an initial weather
check after enabling, retaining approximate hourly background updates and
transient retry/backoff without foreground services or exact alarms.

Persist category toggles and optional quiet hours in Philippine time, with
clear-weather suggestions opt-in. Use city/category/forecast-window fingerprints
and cooldowns to avoid repeating unchanged information; meaningful changes can
produce new advice while respecting quiet hours. Keep hazard decisions based on
fresh provider data. Include advice and reason in expanded notification text;
allow a new deduplicated event to alert even if the previous notification remains.
Recheck opt-out and selected city before delivery. Apply preference behavior
consistently to supported delivery paths; do not claim server push respects
device-only preferences unless its subscription/payload contract enforces them.

### Dynamic visuals

Map actual WMO codes to clear, partly cloudy, overcast, rain, thunderstorm, fog,
snow and unknown scenes. Use provider day/night data when available, with a
documented local-time fallback. Label the scene as the current estimate (or saved
estimate offline), independent of the selected hourly forecast. Use bundled
vector/painted scenes and a short crossfade rather than downloaded images or
continuous animations; all states must work offline and respect reduced motion.

## Verification and acceptance

Run existing regression tests, analyze, targeted new unit/widget tests and an
Android debug build where toolchains permit. Add meaningful coverage for:

- WMO/day-night mapping and visibly distinct rendered scenes.
- Weather request normalization, cache round trips, malformed data, expiration,
  cold-start offline use, reconnection and concurrent location changes.
- Advice evidence, missing optional inputs, cached ML results and stale labels.
- Notification category/quiet-hour policy, fingerprints, cooldowns, permission
  denial, initial scheduling, native channel/body arguments and opt-out races.
- Forecast/planner navigation during outages and existing push/local transitions.

Physical-device acceptance remains required: Android 13+ grant/deny/revoke,
channel blocking, actual notification sound/display/tap, swiping app away,
Doze, reboot, OEM battery restrictions, network loss/recovery, airplane-mode
cold start, UI responsiveness and battery use. Force-stop prevents background
delivery until Android permits the app to run again. FCM requires a configured
build and deployed service; no remote deployment is included by assumption.

The final report will identify code-level root causes versus unverified device
causes, changed files/dependencies/permissions, model and cache behavior, executed
checks with results, and remaining manual steps. No physical-device success
claims will be made from mocked plugin tests.
