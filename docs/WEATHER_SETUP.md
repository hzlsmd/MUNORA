# Live weather without accounts

**Audit release gate:** this optional Cloud Functions backend is not the agreed
zero-paid-services architecture. It remains disabled by default through
`WEATHER_BACKEND_ENABLED=false`. Enabling it also requires App Check verification
before database work. The current Flutter client has no App Check integration;
setting a URL alone is insufficient. See [Release checklist](audit/RELEASE_CHECKLIST.md).
Do not enable billing as part of the no-cost pilot.

Home and Forecast call a public Firebase HTTPS Function. Users do not sign in.
The function reads `OPENWEATHER_API_KEY` from Secret Manager, fetches current
weather and the five-day / three-hour forecast, and returns only weather fields.
The Flutter app contains no provider credential. Firebase Auth is not required.

## 1. Replace the exposed credential

Revoke the old key in your OpenWeatherMap account and create a replacement with
access to the Current Weather and 5 Day / 3 Hour Forecast APIs. Removing the key
from the latest source does not remove it from Git history or invalidate it.
Never put the replacement in Dart, a committed file, or a chat message.

## 2. Create Firebase infrastructure

1. Create a project at <https://console.firebase.google.com/> and note its project ID.
2. Enable billing (Blaze is required for deployed Cloud Functions). Set billing alerts.
3. Create the default Cloud Firestore database in production mode, preferably in
   Singapore near the function's `asia-southeast1` region.
4. Install Node.js 22 and the Firebase CLI, then authenticate from your own terminal:

```sh
npm install -g firebase-tools
firebase login
```

No Firebase client app registration or `google-services.json` is needed for this
milestone: the Flutter app calls HTTPS and does not use a Firebase client SDK.

## 3. Configure and deploy the backend

From the repository root, replace `YOUR_PROJECT_ID` with the actual project ID:

```sh
npm --prefix functions ci
npm --prefix functions test
firebase functions:secrets:set OPENWEATHER_API_KEY --project YOUR_PROJECT_ID
firebase deploy --only functions:weather,firestore:rules --project YOUR_PROJECT_ID
```

The secret command prompts for the replacement key. Use the HTTPS function URL
printed by deployment; do not guess the URL. Deployment does not validate the
provider subscription: test a real response before distributing the app.

```sh
curl --get 'PASTE_DEPLOYED_HTTPS_FUNCTION_URL' --data-urlencode 'city=Muntinlupa'
```

This endpoint accepts `GET ?city=<supported NCR city>` and requires no resident
login, but an enabled backend requires a valid `X-Firebase-AppCheck` token.
The unmodified curl example above is a negative-access check: expect 503 when
disabled or 403 without attestation. It is not a successful live-weather test.
An unknown city or extra query parameter returns 400. Provider failures return a
generic error without including upstream request URLs or credentials.

For Flutter Web, create the ignored file `functions/.env.YOUR_PROJECT_ID` with:

```dotenv
ALLOWED_WEB_ORIGINS=https://your-web-app.example,http://localhost:8080
WEATHER_DAILY_FETCH_LIMIT=1000
```

Use exact origins with scheme and port, no trailing slash or path. Redeploy the
function after changing parameters. Android/iOS requests do not need a web origin.
CORS is a browser policy, not authentication or protection against non-browser clients.

## 4. Run and build Flutter

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=WEATHER_API_URL=PASTE_DEPLOYED_HTTPS_FUNCTION_URL
flutter build apk --dart-define=WEATHER_API_URL=PASTE_DEPLOYED_HTTPS_FUNCTION_URL
```

For Web, use `flutter run -d chrome --web-port=8080` with the same dart define and
enable `http://localhost:8080` in `ALLOWED_WEB_ORIGINS`. The endpoint must use HTTPS.
For a release web build, add `--no-web-resources-cdn` to bundle the rendering
engine locally rather than depending on a separate rendering CDN at startup.
`WEATHER_API_URL` is a public endpoint address, not a secret. A missing endpoint
shows an unavailable/retry state and does not substitute mock weather.

## Behavior and limits

- Supported locations: the 17 NCR cities/municipality in `supported_cities.dart`.
  The server uses matching coordinates rather than accepting arbitrary URLs or locations.
- Home shows temperature, feels-like, humidity, pressure, wind and upcoming three-hour points.
  The selected city is saved locally and shared with Forecast and Alerts.
- Forecast uses five calendar dates of available three-hour samples in Philippine
  time (UTC+8). Daily ranges are aggregated sample ranges, not a separate daily
  forecast product. The first day can be partial. UV is not supplied by these APIs
  and is not fabricated.
- Successful responses are cached in Firestore for ten minutes. Requests on one
  function instance share an in-flight fetch. Different instances can refresh the
  same city concurrently; all refreshes reserve the shared provider budget.
- The default global cap is 1,000 refresh attempts per UTC day (up to 2,000 provider
  calls). Failed attempts count. Fresh cached responses remain available at the cap.
  Tune this to your provider plan and traffic; it can pause updates before midnight.
- Each address is limited to 30 requests per minute using Firestore transactions.
  Shared networks share a limit. Only a keyed hash is stored, not the raw address.
  Rotating the provider key also resets address hashes. Platform request logs may
  still retain network metadata under your cloud logging settings.
- Configure a Firestore TTL policy on `weatherInternal.expiresAt` to clean up rate
  and budget documents. TTL deletion is asynchronous; rate windows reset in code.
  Direct client Firestore access is denied; the function accesses it using its service account.
- On failure, previously fetched weather up to 24 hours old can remain visible,
  labeled as saved weather with its observation time. It is not a current advisory.
- Poppins fonts and their license are bundled. No font-provider download is needed
  to display saved weather.
- Rate limits and the provider cap do not cap Cloud Function/Firestore billing.
  Before broad release, monitor usage and add App Check/platform abuse controls
  if traffic requires them. This does not require user accounts.

## Remaining milestones

Alerts and AI are visibly labeled demos. Official warnings, push notifications,
and real AI requests are not connected. Do not present the sample warnings as
current conditions. Connect an authoritative advisory source before enabling
alert notifications; put any future AI provider credentials behind the backend.

Before release, verify the real provider response, key rotation, offline/retry
behavior, city changes, release Android networking, and the Web CORS origin.
Do not deploy the supplied deny-all Firestore rules over an existing database
that serves other apps without reviewing their rules.
