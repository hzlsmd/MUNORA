# MUNORA experimental AI rain outlook

`assets/models/rain_model.json` contains a genuinely fitted standardized logistic
regression, not handwritten prediction weights. It passed the predeclared Brier
score activation gate on both validation and held-out test years. This is an
experimental reanalysis result; prospective validation on live app observations
remains necessary. Probability is not accuracy or confidence.

## Data and reproducibility

Source: [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api),
explicit `models=era5`, 2021–2025, Asia/Manila hourly times, Celsius, percent,
mean sea-level pressure hPa, wind m/s, rain mm, WMO weather code. Requests use
`elevation=nan` to avoid city-specific elevation downscaling when sharing a grid.
The existing 17 NCR cities resolve to two ERA5 grids: 14.5/121.0 and 14.75/121.0.
The first has 11 city aliases and the second six; these are not 17 independent
stations. Each grid/hour contributes total weight one, divided among its cities.
No future weather code, forecast, or rain value enters the predictor.

The loader makes 17 one-day requests to resolve cities, followed by ten bounded
one-year requests for the two unique grids. It waits 1.2 seconds before each HTTP
request, retries transient errors up to six attempts with exponential backoff,
and honors a numeric Retry-After. Successful responses and SHA256 metadata are
cached incrementally. Cache bytes are verified before reuse. No paid account,
API key, inference server, or additional live request is required.

Run from the repository root, using Python 3 with the pinned dependencies:

```sh
python -m pip install -r ml/requirements.txt
python -m unittest discover -s ml/tests -v
python ml/rain_model.py --cache /workspace/work/ai-weather-data
```

The cache lives outside the repository. It contains raw provider responses; do
not commit it. A retrain is a reproducibility check, not permission to select a
new model using the already inspected 2025 test period. A future changed candidate
needs a fresh untouched evaluation period. The committed report records the
27 source URLs, exact parameters, retrieval timestamps, units, returned
coordinates/elevation, response hashes and bytes, pipeline hash, and combined
source-response hash. Its city/time and season metrics include reliability bins.
The compact on-device artifact references the full report by SHA256.

## Target and evaluation

The label is total rain **at t+1, t+2 and t+3 >=0.1 mm**, requiring three complete,
consecutive hours. Missing future intervals and duplicate city/hour rows cannot
silently form targets. Labels crossing year-split boundaries are purged.
Train: 2021–2023; validation: 2024; frozen held-out test: 2025. Scaler and baselines
use training rows only. The fixed regularization candidates C=0.01, 0.1, 1 were
compared using 2021–2022 training and a 2023 internal validation block, with its
own three-hour boundary purge. Selected C=1. There is no class weighting.

An implementation audit corrected the internal block's boundary purge and
recomputed only its 2023 tuning scores. C remained 1. Frozen final weights and
2024/2025 predictions were unchanged; no second test evaluation or tuning on test
results occurred. Full audit details are recorded in provenance.

| Split | Unique grid/hour groups | Weighted rain prevalence | Model Brier | Train climatology Brier | Train-fitted wet/dry Brier |
|---|---:|---:|---:|---:|---:|
| Train 2021–2023 | 52,554 | 0.44689 | 0.12222 | 0.24718 | 0.14663 |
| Validation 2024 | 17,562 | 0.43287 | 0.10715 | 0.24569 | 0.13428 |
| Test 2025 | 17,514 | 0.51091 | 0.12049 | 0.25398 | 0.14166 |

2025 log loss: 0.38308; ROC AUC: 0.90892; PR AUC: 0.91908. At the UI's 60%
preparation threshold, precision=0.90489 and recall=0.72731 on weighted ERA5 test
rows. These are retrospective scores, not live accuracy promises. Baselines use
training prevalence 0.44689, P(future rain|current dry code)=0.22021, and
P(future rain|current wet code)=0.89046. The model must beat both baselines on
both validation and test; otherwise its exported `validationPassed` is false.

## Numeric contract and support

Schema version 1 exports modelVersion, featureNames, means, scales, coefficients,
intercept, units, bounds, supported city slugs, gate status, metrics, source hashes,
and Python golden vectors. Inference computes a stable sigmoid of the standardized
feature dot product plus intercept. Feature order is four current weather values,
current wet-code flag, local-hour sine/cosine, seasonal sine/cosine, then 17 city
one-hot values in `backend/src/cities.mjs` order. WMO dry codes are 0,1,2,3,45,48;
the artifact lists all accepted and wet codes explicitly.

The local hour is hour+minute/60+second/3600 in Asia/Manila. Seasonal phase is
(day-of-year−1+local-hour/24)/365.2425; both cycles use sine/cosine of 2π phase.
Training observed support is temperature 21.8–36.3°C, humidity 43–98%, pressure
988.8–1019.2 hPa and wind 0–11.42 m/s. The app rejects values outside these bounds,
unknown cities/codes, invalid/missing observations, estimates older than 30 minutes
or over five minutes in the future, and inactive/malformed artifacts. The three-hour
window is anchored to the observation, not screen render time. Out-of-range live
conditions can therefore legitimately show unavailable.

ERA5 is gridded reanalysis, not a street-level or rain-gauge observation. Historical
WMO codes themselves summarize ERA5 conditions and may differ from live forecast
model codes. No fair superiority comparison with the provider's forecast is made:
that requires forecasts archived before their verification windows. This outlook
does not create push-warning triggers, cancel current-rain advice, or give an
all-clear. Seasonal groups are May–October and November–April; finer local claims
are unsupported.

## Activity planning integration

Home and Tips identify the selected city, weather estimate time and exact
observation-anchored three-hour outlook. Their shared evaluator explains saved-only,
stale, future-dated, missing-input, unsupported-source/domain and model-loading
failures. Both use the same memoized model asset and existing weather snapshot;
opening the planner does not request additional provider data or send telemetry.

After selecting an activity and choosing **Check this plan** in Tips, the planner
shows supplementary experimental rain context when the entire future activity
window falls inside the current three-hour outlook. The displayed probability
covers the full three-hour outlook. It is not recalculated as the probability for
the selected one- or two-hour subinterval. A partially overlapping or later plan
gets a coverage explanation and is directed to the hourly forecast instead.

At >=60%, preparedness rules translate the model output into activity-specific
advice for walking, commuting, exercise or outdoor work. Lower probabilities still
tell the user to recheck conditions and preserve hourly forecast precautions.
The AI supplement does not change the existing forecast-derived planner status:
storm, heat and wind warnings, missing-data states and suggested forecast windows
remain independent of the rain model. The model does not infer a new future rolling
window, predict exact onset, forecast flooding or guarantee a safe activity time.
No push notification rule is changed.

This integration needs prospective validation before it can support AI-triggered
notifications. Record predictions before their outcome windows, keep model version,
input source and issuance/observation times, and compare them against independently
verified rainfall for the same location and window. Compare the existing model
with provider forecasts issued at that same time using calibration/Brier scores
and wet-event precision/recall. Do not tune on the already inspected 2025 test set
or treat retrospective ERA5 results as measured live accuracy. No automatic data
collection or validation service is added by this UI integration.

## Attribution

Weather data by [Open-Meteo](https://open-meteo.com/) under its
[CC BY 4.0 attribution terms](https://open-meteo.com/en/terms). ERA5 is produced by
the Copernicus Climate Change Service (C3S) at ECMWF. Contains modified Copernicus
Climate Change Service information (2026). Neither the European Commission nor
ECMWF is responsible for any use that may be made of the Copernicus information
or data it contains. See [ERA5 dataset and citation](https://doi.org/10.24381/cds.adbb2d47).
