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
