# MUNORA (Flutter)

MUNORA is a weather app for Metro Manila. Everyone can use it without signing in.

Home and Forecast use Open-Meteo directly, without an account, API key or backend deployment. This configuration is for the non-commercial school prototype, within
Open-Meteo's free-service limits. See [weather setup](docs/WEATHER_SETUP.md).

## Current status

- Home and Forecast show current model estimates and forecasts from Open-Meteo.
- Weather requests contain city coordinates, with no provider credentials.
- The city picker supports all 17 NCR cities/municipality and saves the selection locally.
- Loading, retry, refresh and saved-weather fallback are implemented.
- Forecast shows five days of available three-hour samples in Philippine time.
- Tips provides rule-based rain, heat, wind and thunderstorm guidance from live
  weather, with category filters and an expandable reason for each tip. [Rules and limits](docs/WEATHER_RECOMMENDATIONS.md).
- Alerts shows app-generated rain, thunderstorm, heat and wind notices from the
  selected city's weather, with explanations and a link to official PAGASA advisories.
  No forecast triggers is explicitly not an all-clear.
- Android weather-tip notifications can be enabled from Tips, with a test
  notification and approximate hourly background checks. Native phone validation
  is still required. See [notifications](docs/NOTIFICATIONS.md).

## Setup

For Android builds in GitHub Codespaces, follow
[Android SDK setup](docs/CODESPACES_ANDROID.md).

Run on a connected device or emulator:

```sh
flutter pub get
flutter run
```

The app does not need an account or a login screen. Local preferences and
cached weather are stored on the device using shared_preferences.
No WEATHER_API_URL define is needed. In Codespaces, preview in the browser with
`flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080` and open port 8080.
Provider failure shows retry/saved-weather states, never fabricated live data.

## Checks

```sh
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

Tests use weather fixtures. Browser use of the default build contacts Open-Meteo.
Use a current Flutter stable SDK; this change was checked with Flutter 3.47.9.

## Structure

- `lib/app.dart`: navigation, shared weather service, selected city.
- `lib/services/weather_service.dart`: HTTPS client and device cache.
- `lib/services/open_meteo.dart`: allowlisted coordinates, provider request and data normalization.
- `lib/models/weather_snapshot.dart`: response parsing and Philippine-date grouping.
- `lib/widgets/weather_view.dart`: loading, saved data, errors and retries.
- `lib/services/weather_alerts.dart`: forecast notices derived from the shared tip rules.
- `assets/design/`: original local imagery and SVGs from the supplied Figma Make export.
- `lib/services/weather_recommendations.dart`: deterministic preparedness rules.

## Interface

The Flutter UI follows the supplied MUNORA Figma Make design: pastel sky gradients,
translucent cards, bundled Inter/Abyssinica typography and a rounded navigation bar.
Home and Forecast retain the existing five-day, three-hour forecast data. AQI, seven-day forecasts and fabricated AI confidence are not shown.
Alerts/Tips optionally fetch hourly UV, precipitation probability and three-model
rain agreement; missing data is explicitly unavailable. Humidity, pressure, wind and feels-like values use the existing provider.

Alerts and Tips share the same weather client, refresh/caching and freshness checks.
They do not introduce new background notification triggers or an official alert feed.
The Flutter splash remains visible for 5 seconds after its first frame on startup.
Android 12+ uses a plain sky-colored startup surface with a transparent icon;
its required system startup surface may briefly appear before Flutter renders.

Browser regression check: serve `build/web` on port 8083 and run
`node tools/check_weather_tips.cjs` with Playwright installed and Chromium available.
It checks the redesign with controlled weather fixtures; real Android notification
validation still requires a device.
