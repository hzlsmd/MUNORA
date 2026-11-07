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
official advisory or unrestricted chatbot. Alerts remain a demo. The thesis must
describe this implementation accurately; it does not fulfill an independently
trained predictive-model claim. Model training is intentionally excluded per the
team's time constraint.

## Verification

Focused tests cover current/forecast rain, exact six-hour and numeric thresholds,
past/distant events, storm ordering, stale/future data, city changes, manual refresh,
old offline snapshots and small-screen large-text layout. Existing service/widget
regressions remain in the full Flutter suite. Native Android testing is separate.

Verification completed: 36 Flutter tests passed, Flutter analysis reported no
issues, and the release web build succeeded. Fixture browser checks at 390x844
and 1366x900 exercised all four rule types, inspected scrolling/layout, and
confirmed one shared provider request across Home and Tips with zero JavaScript
errors. Screenshots were visually checked. The optional browser check is
`node tools/check_weather_tips.cjs` with a local release server on port 8083;
Playwright/Chromium are required. It uses fixtures and sends no weather-provider
traffic. Native Android/device verification remains outstanding.
