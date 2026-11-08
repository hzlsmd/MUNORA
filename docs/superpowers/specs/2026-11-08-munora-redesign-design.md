# MUNORA UI redesign, Alerts and Tips

Status: approved scope recovered from the user-provided conversation. Forecast-based notices selected.

## Agreed scope

Replace the current Flutter UI/UX using the uploaded MUNORA.zip design. Keep the existing weather features, including five-day forecasts, current weather, the NCR city picker, saved-weather fallback, refresh/retry and existing notification behavior. Add or improve only Alerts and Tips.

Do not add seven-day forecasts, air quality or model-confidence scores. The user's previous selection was free forecast-based guidance rather than generative AI; retain that approach for Tips unless changed.

## Implementation approach

Port the prototype's five screens into the existing Flutter app, with shared pastel gradients, translucent cards, typography, bundled assets and bottom navigation. Adapt the prototype's content to the app's actual data. Preserve responsive layouts, accessible controls, safe areas and readable larger text.

Home and Forecast continue to use the current live Open-Meteo integration and five-day data model. Do not copy static weather values or unsupported AQI, confidence, radar, traffic or personalization claims from the prototype.

Tips use the existing weather-recommendation rules with the new presentation, category filters and expandable explanations. Connect the actual notification service. Saved or stale data must be identified, and unsupported categories must have an honest empty state.

Alerts currently display demo warnings. The remaining scope decision is whether to replace those with forecast-derived notices from the existing weather data or authoritative PAGASA advisories. Forecast-derived notices can use rain/thunderstorm conditions and existing heat and wind thresholds; they must be labeled as app-generated guidance, not official warnings. Official advisories require a verified source and a separate integration. Missing or stale data must never be presented as an all-clear.

## Validation and delivery

Test the selected alert logic and tip filters/explanations, city changes, stale data, error recovery, navigation and responsive rendering. Run Flutter analysis, relevant tests and a web build. Compare the rendered UI against the uploaded reference. Preserve the existing weather and notification tests. Native notification behavior requires device validation when a device is unavailable.

Deliver a feature branch and draft pull request. Merging and deployment are outside this task.
