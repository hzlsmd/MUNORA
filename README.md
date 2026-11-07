# MUNORA (Flutter)

MUNORA is a weather app for Metro Manila. Everyone can use it without signing in.

Home and Forecast use Open-Meteo directly, without an account, API key or Firebase
deployment. This configuration is for the non-commercial school prototype, within
Open-Meteo's free-service limits. See [weather setup](docs/WEATHER_SETUP.md).

## Current status

- Home and Forecast show current model estimates and forecasts from Open-Meteo.
- Weather requests contain city coordinates, with no provider credentials.
- The city picker supports all 17 NCR cities/municipality and saves the selection locally.
- Loading, retry, refresh and saved-weather fallback are implemented.
- Forecast shows five days of available three-hour samples in Philippine time.
- Tips provides rule-based rain, heat, wind and thunderstorm guidance from live
  weather, with a reason for each tip. [Rules and limits](docs/WEATHER_RECOMMENDATIONS.md).
- Alerts remains a labeled demo, pending an authoritative advisory integration.

## Setup

For Android builds in GitHub Codespaces, follow
[Android SDK setup](docs/CODESPACES_ANDROID.md).

Run on a connected device or emulator:

```sh
flutter pub get
flutter run
```

The app does not need Firebase Auth or a login screen. Local preferences and
cached weather are stored on the device using shared_preferences.
No WEATHER_API_URL define is needed. In Codespaces, preview in the browser with
`flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080` and open port 8080.
Provider failure shows retry/saved-weather states, never fabricated live data.

## Checks

```sh
npm --prefix functions ci
npm --prefix functions test
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
- `functions/`: dormant alternative backend; not used by the default app and not cleared for deployment.
- `firestore.rules`: denies direct client access to backend storage.
- `lib/data/mock_data.dart`: remaining demo alerts, not live warnings.
- `lib/services/weather_recommendations.dart`: deterministic preparedness rules.
