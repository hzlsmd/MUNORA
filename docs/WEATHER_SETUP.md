# Weather integration status

## Backend policy

**No backend deployment is supported by this PR.** The optional Firebase backend
is reference/hardening code, not a deployable product milestone. It must stay
disabled (`WEATHER_BACKEND_ENABLED=false`) until a separate reviewed client
integration lands and the project owner explicitly approves any infrastructure
costs. The current no-paid-services pilot must not enable billing or deploy this
backend. There is no supported live Firebase path with the current Flutter client.

Do not treat setting `WEATHER_API_URL` or enabling the backend parameter as a
workaround. Do not remove, bypass or make App Check optional to unblock the app.
App Check is app attestation, not resident login; no resident accounts are needed.
Firestore remains deny-all for direct client access.

### Requirements for a separate integration PR

- Register the actual Firebase apps for each supported platform and supply public
  app configuration through the platform's supported setup. The old statement
  that no Firebase client registration was needed no longer applies.
- Initialize Firebase and activate a production App Check provider on each
  supported platform before weather requests. Define unsupported-platform behavior
  explicitly; do not silently send unauthenticated requests.
- Retrieve a current App Check token and send it in `X-Firebase-AppCheck` on every
  weather request. Let the SDK manage token renewal. Handle missing, expired or
  rejected attestation without an anonymous fallback or an infinite retry loop.
- Keep attestation tokens out of preferences, committed files, URLs and logs.
  Keep provider keys in server secrets, not Dart or Firebase public configuration.
  Debug App Check tokens are local development credentials, never production defaults.
- Test verified success, missing/invalid/expired tokens, initialization failure,
  offline fallback, city changes and Web CORS on real supported platforms. Verify
  disabled/unauthorized requests do no database/provider work.
- Update deployment/run documentation only after this client/server path works.
  Owner approval of a paid architecture, IAM, TTL, cost controls and provider
  subscription remains a separate gate; client integration does not grant approval.

See [Release checklist](audit/RELEASE_CHECKLIST.md). The proposed no-paid-cloud
provider migration remains separate work, not implemented by this audit.

## Local development and checks

UI development does not need Firebase credentials or a paid project:

```sh
flutter pub get
flutter run
```

Without a configured compatible endpoint, Home/Forecast show unavailable/retry
states. No mock weather is presented as live. Existing tests inject fixture data
and consume no provider credentials:

```sh
npm --prefix functions ci --ignore-scripts
npm --prefix functions test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn --dart-define=WEATHER_API_URL=https://weather.example.invalid/weather
```

The example address is for compilation and intercepted browser fixtures only.
It cannot return live weather. `WEATHER_API_URL` is a public HTTPS endpoint
address, not a credential, and does not provision or enable a backend.

## Existing backend contract (inactive)

- Fixed provider URLs and coordinates cover the 17 supported NCR cities. The
  normalized DTO includes observation/update times, current measurements and at
  most 40 three-hour samples. Provider keys never appear in that DTO.
- An enabled backend requires valid `X-Firebase-AppCheck` attestation before
  database work. Supported GET requests receive 503 while disabled and 403 for
  missing/rejected attestation when enabled. Invalid methods/cities/origins may
  be rejected earlier. CORS is not authentication.
- Validated weather is cached for ten minutes. Refresh leases fence writers
  across instances; shared escalating provider backoff allows one recovery probe.
- The default cap is 1,000 refresh attempts per UTC day, up to two provider calls
  per attempt. Failures count. This cannot sustain all 17 cities continuously
  every ten minutes (2,448 refreshes/day).
- Rate accounting permits 30 requests per minute per keyed platform-IP hash.
  Shared networks share a limit. Raw IPs are not stored by this application, but
  infrastructure logs may retain network metadata. Key rotation resets the hashes.
- Provider/rate limits do not cap function/Firestore billing. A TTL policy must
  explicitly be configured for `weatherInternal.expiresAt`; the field alone does
  not delete documents. Admin SDK access still needs least-privilege IAM review.
- Saved weather can remain visible for up to 24 hours, labeled with its age and
  source. It is not a current advisory. Forecast ranges use Philippine calendar
  dates and available three-hour samples, not a separate daily forecast product.

## Credential ownership and remaining milestones

Revoke the historical OpenWeatherMap key exposed in commit `1244f8c`. Removing it
from current source does not invalidate it. Revocation is owner action; never
paste a replacement into Dart, Git or chat. No replacement is needed for fixtures.

Alerts and AI remain demos. Official warnings, push delivery, trained predictions
and real accuracy/latency evaluation are not connected. This app must not be used
as the sole source of emergency warnings. Do not deploy deny-all Firestore rules
over a database shared by other apps without reviewing their access needs.
