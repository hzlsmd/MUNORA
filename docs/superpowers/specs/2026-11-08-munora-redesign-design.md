# MUNORA UI redesign, Alerts and Tips

Status: approved scope. User selected app-generated forecast-based alerts and free forecast-based tips.

## Agreed scope

Replace the current Flutter UI/UX using the uploaded MUNORA.zip design. Keep the existing weather features, including five-day forecasts, current weather, the NCR city picker, saved-weather fallback, refresh/retry and existing notification behavior. Add or improve only Alerts and Tips.

Do not add seven-day forecasts, air quality or model-confidence scores. The user's previous selection was free forecast-based guidance rather than generative AI; retain that approach for Tips unless changed.

## Implementation approach

Port the prototype's five screens into the existing Flutter app, with shared pastel gradients, translucent cards, typography, bundled assets and bottom navigation. Adapt the prototype's content to the app's actual data. Preserve responsive layouts, accessible controls, safe areas and readable larger text.

Home and Forecast continue to use the current live Open-Meteo integration and five-day data model. Do not copy static weather values or unsupported AQI, confidence, radar, traffic or personalization claims from the prototype.

Tips use the existing weather-recommendation rules with the new presentation, category filters and expandable explanations. Connect the actual notification service. Saved or stale data must be identified, and unsupported categories must have an honest empty state.

Alerts currently display demo warnings. Replace those with forecast-derived notices from the existing weather data, as selected by the user. Forecast-derived notices can use rain/thunderstorm conditions and existing heat and wind thresholds; they must be labeled as app-generated guidance, not official warnings. Official advisories require a verified source and a separate integration. Missing or stale data must never be presented as an all-clear.

## Validation and delivery

Test the selected alert logic and tip filters/explanations, city changes, stale data, error recovery, navigation and responsive rendering. Run Flutter analysis, relevant tests and a web build. Compare the rendered UI against the uploaded reference. Preserve the existing weather and notification tests. Native notification behavior requires device validation when a device is unavailable.

Deliver a feature branch and draft pull request. Merging and deployment are outside this task.

## November 9 parity correction

The user explicitly requests every feature on the Figma Alerts and Tips screens.
Restore the view switcher, hazard badges/time windows, calm summary metrics and
return action; restore the microclimate/model panel, featured recommendation,
outdoor window, five detailed guidance cards and helpful/not-helpful feedback.
Fetch optional hourly rain probability, UV, humidity and temperature plus model
rain forecasts for these screens only. This does not extend the five-day forecast
or add AQI. Use actual three-model agreement, not calibrated confidence or the
prototype's fabricated four-model 91% claim. Keep calm preview explicitly labeled
when hazards exist; it cannot override real notices. Feedback is stored locally,
not described as training a model. General preparedness cards remain available
without claiming unsupported traffic, radar or personalization integrations.
