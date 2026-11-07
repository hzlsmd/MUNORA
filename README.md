# MUNORA (Flutter)

MUNORA is a weather app for Metro Manila. Everyone can use it without signing in.

The optional Cloud Functions backend is disabled by default after security
hardening. Enabling it requires App Check integration that is not yet present in
the Flutter client. No backend has been deployed. See the
[release gates](docs/audit/RELEASE_CHECKLIST.md) before attempting deployment.

## Current status

- Home and Forecast load live weather through a Firebase HTTPS backend.
- Provider credentials stay on the server.
- The city picker supports all 17 NCR cities/municipality and saves the selection locally.
- Loading, retry, refresh and saved-weather fallback are implemented.
- Forecast shows five days of available three-hour samples in Philippine time.
- Alerts and AI remain labeled demos, pending real integrations.

## Setup

See [Live weather setup](docs/WEATHER_SETUP.md) for Firebase project creation,
replacement API-key configuration, deployment, request limits and release checks.

After deploying the backend:

```sh
flutter pub get
flutter run --dart-define=WEATHER_API_URL=PASTE_DEPLOYED_HTTPS_FUNCTION_URL
```

The app does not need Firebase Auth or a login screen. Local preferences and
cached weather are stored on the device using shared_preferences.

## Checks

```sh
npm --prefix functions ci
npm --prefix functions test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn --dart-define=WEATHER_API_URL=https://weather.example.invalid/weather
```

The example endpoint is for compilation only, not live weather. Tests mock the
weather provider and do not consume a real API key.
Use a current Flutter stable SDK; this change was checked with Flutter 3.47.9.

## Structure

- `lib/app.dart`: navigation, shared weather service, selected city.
- `lib/services/weather_service.dart`: HTTPS client and device cache.
- `lib/models/weather_snapshot.dart`: response parsing and Philippine-date grouping.
- `lib/widgets/weather_view.dart`: loading, saved data, errors and retries.
- `functions/`: public weather endpoint, server credentials, caching and request limits.
- `firestore.rules`: denies direct client access to backend storage.
- `lib/data/mock_data.dart`: remaining demo alerts and AI examples, not live weather.
