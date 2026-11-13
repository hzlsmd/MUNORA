# AI rain outlook and current heat index

Status: proposed design for review; no model has been trained or integrated yet.
Independent builder review on 13 November 2026 found no important unanswered questions.
Built on the hourly-forecast branch (PR #30). Keep that change when integrating.

## User intent

Add a genuinely trained rain-prediction model to MUNORA and replace the Pressure
metric card with Heat Index. The app and its operation must remain free, without
billing accounts or a paid inference API. Forecast entries are hourly. The model's
prediction horizon is separate from the forecast display interval.

## Recommended scope

Use the previously proposed three-hour rain-probability target. This is the
builder's recommended horizon, not a separate user decision about the hourly UI.
Heat Index is a current derived measurement, not an AI heat forecast. Add a small
trained model for an experimental AI rain outlook and supporting rain-preparation
guidance. Preserve the existing provider forecast and weather-rule notifications;
do not let an unvalidated research model automatically send new push warnings.

## Approaches

1. Train a small logistic-regression model offline and bundle numeric parameters
   in Flutter: recommended, consistent with the prior proposal. No inference
   server, key, new subscription or TFLite runtime is required.
2. Use a cloud language-model API for weather explanations: does not establish a
   validated rain predictor and introduces service quotas/possible costs.
3. Use only provider probabilities: useful as a comparison, but does not add the
   requested MUNORA-trained predictor to the existing application.

The user asked to proceed with the recommended AI model and Heat Index. The
specific data, evaluation and display decisions below are builder proposals.

## Data and provenance

No historical dataset or training pipeline is present in the repository. A public
Open-Meteo Historical Weather API sample was verified on 13 November 2026: 72
consecutive hourly ERA5 records for Manila, with temperature, relative humidity,
mean sea-level pressure, wind, weather code and rainfall, including units.

Use the 17 existing allowlisted NCR locations and years 2021–2025. Download bounded,
rate-limited requests, honor provider errors/Retry-After, and retain source URLs,
query parameters, timestamps, response hashes, units and returned grid/elevation
metadata. Use `models=era5`, Celsius, percent, hPa and m/s, and rainfall in mm.
Cite Open-Meteo and ERA5 with the applicable attribution. Keep large raw data out of
Git; commit download/training scripts, provenance summaries, evaluation and the
small validated model artifact.

ERA5 is gridded reanalysis, not measured rainfall at each city. Nearby cities may
share the same underlying grid. Deduplicate identical source records and weight
or group grid/time duplicates so they do not masquerade as independent stations.
Report both unique grid/time counts and city coverage. Do not claim station-level
or street-level accuracy. Current operational model estimates also differ from
historical reanalysis: prospective live validation remains required.

## Target, features and leakage controls

Target at time t: at least 0.1 mm total rainfall in the next three complete hourly
intervals (t+1, t+2, t+3). Exclude rows without all three consecutive future labels.
Predictors use only information at t: temperature, humidity, sea-level pressure,
wind speed, wet-condition flag from WMO code, local-hour and seasonal sine/cosine
features, and the supported location. Never include future rainfall, future
weather codes or future forecast values as training predictors.

Split all locations by time, not random rows: train 2021–2023, validation 2024,
held-out test 2025. Purge boundary rows whose three-hour label crosses the split.
Fit preprocessing only on training data. Select regularization/settings using
training time-block validation and the validation period; evaluate the frozen
candidate on the test period once. Do not tune using test results.

Use a scikit-learn StandardScaler + LogisticRegression pipeline with fixed random
seed, without class weights that would distort uncalibrated probabilities.
Report Brier score, log loss, ROC/PR AUC where defined, threshold precision/recall,
positive prevalence, reliability bins and per-city/per-season results. Compare
against training-only climatology and a training-fitted wet/dry persistence
baseline. Accuracy alone is insufficient for imbalanced rainfall events.

Enable the model in the app only after it has finite, reproducible held-out
results and improves Brier score over both baselines on validation and held-out
test. If it fails, retain the research report and do not invent confidence or
silently activate a weak model. Any subsequent candidate needs a fresh untouched
evaluation period. Do not claim it outperforms Open-Meteo: a fair comparison needs
forecasts issued before the target window and matching verification labels.

## On-device inference and user experience

Export a versioned JSON artifact with feature order/transforms, scaler parameters,
coefficients/intercept, coverage, training dates, metrics, hashes and provenance.
No pickle/model deserialization in the app. Validate size, schema, feature count,
finite values, units and coverage. Test Dart probabilities against Python golden
vectors. Use stable sigmoid math. Reject missing, invalid, stale or unsupported
inputs and observations outside documented training support.

Preserve validated raw humidity and pressure in WeatherSnapshot for inference;
hiding the Pressure card must not remove the pressure API field or validation.
Load the bundled model once without delaying app startup. Use existing current
Open-Meteo inputs, with no new request per prediction. Recompute after a successful
weather refresh. Require model-estimate age at most 30 minutes and at most five
minutes future skew. The window runs from estimate time through estimate time
plus three hours; show its actual Philippine-time end, not a moving window based
on stale input. Cached/invalid inputs show unavailable rather than fabricated AI.

Show an "AI rain outlook" card on Home and Tips with a model probability, time
window, model version/details and a concise experimental-estimate label. Probability
is not accuracy or confidence. Avoid displaying certainty as 0%/100%; use <1%/>99%
where appropriate. An estimate at least 60% may add rain-preparation advice;
current storm/rain guidance cannot be overridden by a low model score. No all-clear
claim. Do not change remote push triggers in this initial research integration.

## Pressure to Heat Index

Replace the shared Pressure card on Home and Forecast with "HEAT INDEX" in Celsius.
Compute from unrounded current temperature and relative humidity using the NWS
heat-index method: applicability screening, Rothfusz regression, applicable
low-/high-humidity adjustments and Fahrenheit/Celsius conversion. Never rename
provider apparent temperature or reuse it as heat index.

Conservatively bound the supported calculation domain to the documented method.
For cool/out-of-domain conditions show an em dash and an appropriate explanation;
missing/invalid inputs show unavailable. Do not extrapolate extreme polynomial
outputs or clamp humidity to fabricate an estimate. Use the same estimate and
freshness context as the weather card, with "Estimated in shade" explanation.
Keep the existing Feels Like card distinct. No new official warning categories,
medical-risk claims, heat forecasts or notification thresholds are introduced.

Reference verified for the regression coefficients:
https://www.weather.gov/epz/wxcalc_heatindex
Historical data: https://open-meteo.com/en/docs/historical-weather-api

## Build order and verification

1. Heat-index formula and raw feature preservation: reference-value, boundary,
   invalid-input and widget tests; card replacement and existing small-screen tests.
2. Reproducible historical-data validation, label construction, temporal splits,
   preprocessing and baseline tests; train and freeze a candidate and publish its
   actual evaluation. No synthetic data used as evidence of predictive skill.
3. Bundled model and golden-vector inference tests, freshness/domain rejection,
   startup/error-state tests and rain-outlook UI integration.
4. Full Flutter/backend suites, analysis, web build and browser regression. Android
   compilation/phone testing requires the still-pending Android SDK/device setup.
   Do not represent a web build as validation of an APK or live predictive accuracy.

Deployment: retain the GitHub PR review workflow. Training and inference remain
local/free. Existing Cloudflare notifications continue their current behavior.
