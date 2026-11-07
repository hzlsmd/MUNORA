# MUNORA (Flutter)

MUNORA is a weather app for Metro Manila. Everyone can use it without signing in.

**No backend deployment is supported by this PR.** The optional Cloud Functions
backend stays disabled until a separate, reviewed Flutter App Check integration
lands and the owner explicitly approves its infrastructure costs. No backend has
been deployed. Setting an endpoint URL alone does not make this client compatible
with that backend. See the [backend policy](docs/WEATHER_SETUP.md#backend-policy).

## Current status

- Home and Forecast implement the HTTPS weather contract; live weather is not
  configured. Firebase integration is blocked by the backend policy above.
- Provider credentials stay on the server.
- The city picker supports all 17 NCR cities/municipality and saves the selection locally.
- Loading, retry, refresh and saved-weather fallback are implemented.
- Forecast shows five days of available three-hour samples in Philippine time.
- Alerts and AI remain labeled demos, pending real integrations.

## Setup

See [Weather integration status](docs/WEATHER_SETUP.md) for the blocked backend
policy, client integration prerequisites and local fixture checks. For UI
development without live weather:

```sh
flutter pub get
flutter run
```

The app does not need Firebase Auth or a login screen. Local preferences and
cached weather are stored on the device using shared_preferences.
Without a configured compatible endpoint, weather shows its unavailable state;
the app does not substitute fabricated live data.

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
