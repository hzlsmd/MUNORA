# Weather recommendations

The Tips tab replaces the AI demo and random chat with deterministic advice from
the selected city's validated live weather. It needs no trained model, new server,
API key or login. Data and refresh behavior are shared with Home and Forecast.

## Rules

Rules are evaluated in this order; all matching tips are shown once:

| Trigger | Recommendation |
| --- | --- |
| Current thunderstorm condition or a thunderstorm sample in the next six hours | Consider indoor activities and check official advisories. |
| Current rain/drizzle/showers or a matching sample in the next six hours | Bring rain protection and allow extra time if roads are wet. |
| Current temperature at least 32 C OR provider apparent temperature at least 35 C | Carry drinking water, seek shade and take breaks. |
| Current wind at least 10 m/s | Secure loose belongings and take care with umbrellas. |
| No matching trigger | Review the forecast before heading out; do not claim conditions are safe. |
| Data fails the live freshness check | Show only a request to refresh, not condition-specific advice. |

These are application-chosen preparedness thresholds, not official hazard levels
or medically calculated heat-index categories. Apparent temperature is the
provider's feels-like value. Numeric checks use validated unrounded measurements.
Rain uses condition descriptions; no rain probability is inferred or fabricated.
The next-six-hour check includes its end time and excludes past samples. Three-hour
samples can miss shorter events. Each matching tip states the measurement or
forecast condition/time that triggered it.

## Age and limitations

Existing snapshot freshness rules apply: update age at most 30 minutes, model/
observation age at most three hours, future skew at most five minutes, and future
forecast coverage. Saved weather may still be visible for up to 24 hours with
its source/time, but stale data gives only refresh guidance. A failed refresh can
retain still-fresh data and its original timestamps. WeatherView rechecks age on
resume and periodically while visible.

This is rule-based weather guidance, not a trained AI predictor, confidence score,
official advisory or unrestricted chatbot. Alerts now display the same rain,
thunderstorm, heat and wind triggers as app-generated notices. Routine advice is
not an alert, and the empty state does not claim conditions are safe. The thesis must
describe this implementation accurately; it does not fulfill an independently
trained predictive-model claim. Model training is intentionally excluded per the
team's time constraint.

## Verification

Focused tests cover current/forecast rain, exact six-hour and numeric thresholds,
past/distant events, storm ordering, stale/future data, city changes, manual refresh,
old offline snapshots and small-screen large-text layout. Existing service/widget
regressions remain in the full Flutter suite. Native Android testing is separate.

The Flutter suite and `tools/check_weather_tips.cjs` cover the new interface.
The browser check uses fixtures and sends no weather-provider traffic.
Native Android/device verification remains separate.

## Categories and explanations

Tips supports All, Rain, Heat, Outdoor and Travel. Rain includes rain and storm
rules; Heat includes heat; Outdoor includes heat, wind, storms and routine advice;
Travel includes rain, wind and storms. The general hydration, UV, outdoor, travel and storm-safety cards are also
filtered. The featured current recommendation remains visible. Changing cities
resets the filter to All. Stale-data guidance is always visible regardless of filter.
Every notice and tip can expand its actual triggering condition or measurement.
No routine learning, forecast confidence, radar or traffic integration is claimed.


## Figma Alerts and Tips parity

Alerts includes Active Hazards/Calm Skies switching, notice counts, priority badges,
time windows, calm illustration, wind/rain/UV metrics and return-to-hazards action.
Calm previews preserve a warning when current notices exist. PAGASA opens the
official source; app notices are not official warnings.

Tips includes the microclimate header, expandable model comparison, featured
recommendation and explanation, outdoor window with temperature/UV/humidity,
five category filters, expandable general guidance, and helpful/not-helpful feedback.
Feedback is stored on this device per city; it does not train a model.

Optional Open-Meteo data is cached ten minutes and expires after thirty minutes.
Three models (ECMWF IFS, GFS, ICON) are compared over six aligned forecast hours:
the average majority share agreeing on wet/dry conditions (0.1 mm threshold).
Agreement is not forecast accuracy or AI confidence. Missing comparisons show unavailable.
Outdoor windows require three consecutive daytime hours within 36 hours, each at
most 31 C, UV 5 and rain probability 30%. They are planning suggestions, not safety
guarantees. Missing hourly data cannot generate a suggested window. These optional
requests never block the existing weather feed or create background alerts.

## Plan My Activity

Tips now assesses commuting, walking, exercise or outdoor work for a selected
1–3-hour window within 36 hours. Every hour needs rain, temperature, feels-like,
UV, wind and a recognized condition code. Missing or stale inputs produce an
insufficient-data result. Known thunderstorms, wind ≥15 m/s or feels-like ≥41°C
recommend postponing exposed activity, including when other inputs are missing.
Activity-specific precautions use the thresholds documented in
`docs/superpowers/specs/2026-11-09-activity-planner-design.md`; these are app planning
heuristics. Better windows require complete data and fewer concerns throughout
the duration, between 06:00 and 18:00 Philippine time.

Daily routines and previous same-plan assessments are stored per city on this
device. Opening Tips checks the next routine occurrence and can highlight changed
forecast assessments. Routines do not schedule notifications. Feedback accepts an
optional reason and can be cleared. Feedback does not automatically train a model.
A future trained model requires consented labeled data, held-out evaluation and
comparison with this rule-based baseline before claiming improved accuracy.

The Tips UI exposes **Model Prediction Confidence** as an agreement-based indicator:
high at ≥90%, moderate at ≥75%, and low below 75%. Its visible explanation states
that this is three-model agreement, not measured forecast accuracy. Missing model
comparisons show unavailable. **AI Personalization Insights** contains the activity
planner, saved routines and outdoor forecast insights; recommendations use the
existing deterministic rules rather than a trained personal model.
