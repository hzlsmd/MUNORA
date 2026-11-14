# AI rain outlook and Heat Index — implementation verification

13 November 2026. These features are prepared in source; phone installation and
prospective comparison with observed rainfall remain separate acceptance work.

## Actual model

- Five years of public ERA5/Open-Meteo hourly data, 2021–2025.
- 17 NCR city aliases cover two source grids; duplicate grid/time aliases receive
  aggregate weight one. Raw data are outside Git; provenance/hashes are recorded.
- Train2021–2023, validate2024, test2025 with three-hour boundary purges.
- Weighted logistic regression, selected C=1.0. The internal tuning-boundary audit
  retained the same candidate; frozen held-out predictions were not retuned.
- Validation Brier0.10715 vs climatology0.24569 and persistence0.13428.
- Held-out2025 Brier0.12049 vs climatology0.25398 and persistence0.14166.
- Gate passed. Probabilities are experimental estimates, not measured live accuracy.
- Versioned compact JSON and Python-to-Dart golden vectors are bundled with the app.
- No paid AI API, server inference, billing change or user telemetry was added.

See [full model report](AI_RAIN_MODEL.md) and `ml/reports/evaluation.json`.

## App behavior and checks

- Current Heat Index replaces the shared Pressure card; unrounded temperature/RH
  feed the NWS calculation. Feels Like remains distinct. Raw pressure is retained
  internally for inference. Invalid/out-of-supported-domain heat values show —.
- Home and Tips load the model asynchronously; stale, cached-only, unsupported or
  malformed inputs cannot generate a displayed probability.
- Review reproduced a saved-disk-cache path incorrectly marked live. Fixed by
  separating disk fallback from the network-only memory cache, and invalidating
  live reuse after a failed update. Both regressions were observed RED→GREEN.
- Decoder validates exact three-hour target, .1mm threshold, future offsets,
  PHT transforms and WMO code semantics. No invented default probabilities.
- 105 Flutter tests, seven Python tests and14 backend tests pass locally.
- Flutter analysis is clean and release web build succeeds.
- Browser regression passes at390×844 and1366×900, including actual bundled model
  loading/display on fresh supported fixtures; six provider calls and no page
  errors in each viewport. Browser fixtures do not prove live forecast accuracy.
- GitHub Actions now includes a push-enabled Android debug APK build/artifact;
  its remote result is pending publication. Local Android SDK remains absent.
- Existing background push triggers and cooldowns are unchanged.

## Activity planning integration — 14 November 2026

- Home/Tips use one typed outlook evaluator and the same memoized numeric model.
  The card now includes selected city and weather-estimate time and distinguishes
  saved-only, stale/future-dated, expired, missing-input, unsupported and unavailable
  model cases. A loading replacement model cannot display a previous prediction.
- Tips passes its existing live weather snapshot into Plan My Activity. After a
  plan check, a compact experimental supplement shows the full three-hour model
  probability only when the entire future plan fits inside that outlook. It never
  presents that probability as a one-hour or future rolling-window prediction.
- Preparedness rules provide activity-specific advice at >=60%; lower values
  still require checking current conditions and hourly forecasts. The existing
  forecast assessment, severe-condition warnings and better-window search are
  unchanged, as are notifications, model weights and training/evaluation data.
- New regression cases were observed failing before implementation: missing
  city/time and reason context, absent planner integration, retained probability
  while a new model was pending, and model details losing the loaded version when
  weather was stale. Focused cases cover full/partial/outside windows, exact end
  boundaries, past/invalid plans, threshold behavior for all four activities,
  saved/stale inputs, activity changes and low-AI/high-storm preservation at 320px
  with 2x text.
- The full Flutter suite passes 121 tests, including unchanged frozen Python→Dart
  model golden vectors. Flutter analysis reports no issues. The release web build
  succeeds, including its Wasm compatibility dry run. No dependencies were added.
- Independent read-only review found no Critical, Important or Minor issue.
  Real phone acceptance and prospective rainfall verification remain outstanding.
- Browser regression passes at 390×844 and 1366×900 with the actual bundled model
  and controlled Open-Meteo fixtures. Checking the plan after a city change shows
  the full-window AI context, with six provider requests per flow and no page
  errors; the count is unchanged from the existing flow. Fixture/browser results
  verify integration, not live predictive accuracy.

See [model and planner contract](AI_RAIN_MODEL.md#activity-planning-integration).

## Recommendation visibility — 14 November 2026

- Home/Tips show concise rain preparedness advice alongside the experimental AI
  prediction, with a Plan an activity shortcut. Home opens Tips with the planner
  expanded and scrolled into view; Tips reopens the same planner while preserving
  the selected activity. A city change creates fresh planner state.
- The supplement is labelled AI rain recommendation. Forecast-based activity
  planning, weather recommendations and three-model agreement use distinct source
  labels. The forecast model agreement percentage retains its existing definition;
  model probabilities, warning thresholds and notification behavior are unchanged.
- When loaded model inputs are unavailable, Refresh weather uses the shared
  WeatherView force-refresh path, bypassing fresh memory reuse. Model-loading
  failures retain their explanation instead of suggesting a weather refresh will
  replace the model. The action is unavailable during an in-flight weather load.
- Three new behavior tests cover shortcut expansion/scrolling without resetting
  activity, explicit planner entry after weather loads, and forced refresh beyond
  the memory cache. Existing label checks were updated intentionally.
- All 124 Flutter tests pass; analysis is clean and web/Wasm dry-run build succeeds.
  Independent read-only review found no defects. Prospective model accuracy and
  physical Android delivery remain outside what these repository checks establish.
- Browser regression passes at 390×844 and 1366×900 with zero page errors and
  six provider calls per flow (unchanged). It now exercises actual Home routing
  into the expanded/scrolled planner and the shortcut on Tips. The rendered
  mobile planner entry was inspected to confirm its controls are visible.
