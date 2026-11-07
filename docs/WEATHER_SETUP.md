# Weather setup

## Default: direct Open-Meteo

Run `flutter pub get` and `flutter run` with an Android device/emulator connected.
No login, API key, Firebase project or WEATHER_API_URL define is needed. For a
Codespaces browser preview, run:

```sh
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

Open port 8080 in the Ports panel. For an Android debug APK, use
`flutter build apk --debug` after the Android SDK setup.

The app requests Open-Meteo directly for the selected city's fixed coordinates.
The provider sees your network IP and city coordinates; the app does not request
GPS access or send login credentials. Current conditions are model estimates,
not station observations or official warnings. The visible model timestamp and
local fetch/update time are distinct.

The adapter validates units, WMO codes, hourly array alignment/order, measurements
and age. Six days of hourly data supply at most 40 upcoming three-hour samples;
the UI groups the first five Philippine calendar dates. Daily ranges are sampled
temperature ranges, not full daily extrema. Ten-minute fresh reuse and concurrent
request sharing reduce traffic; manual refresh forces a request. Offline data is
labeled and expires after 24 hours. Provider caches use separate namespaces.

### Terms, attribution and scale

Checked 7 November 2026: the free endpoint is for non-commercial use, with limits
below 600 calls/minute, 5,000/hour, 10,000/day and a stated 300,000/month allowance.
Limits apply by IP/application; shared networks can reach them earlier. Review
the current [terms](https://open-meteo.com/en/terms) and
[pricing](https://open-meteo.com/en/pricing) before adding ads, subscriptions or
broad distribution. No paid plan is enabled.

Weather data is provided under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The app links to Open-Meteo and the license. Data is adapted into descriptions,
rounded display values and three-hour samples. These are third-party estimates
without an availability/accuracy guarantee. See the
[forecast API documentation](https://open-meteo.com/en/docs).

An explicit WEATHER_API_URL overrides the default for a compatible normalized
backend or fixture. Remove old placeholder defines from run configurations to
use Open-Meteo. This override does not integrate Firebase App Check.

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

See [Release checklist](audit/RELEASE_CHECKLIST.md). The direct Open-Meteo default
above is independent of this dormant Firebase option.

## Local development and checks

UI development does not need Firebase credentials or a paid project:

```sh
flutter pub get
flutter run
```

The default build requests Open-Meteo. Existing tests inject fixture data and
consume no provider credentials:

```sh
npm --prefix functions ci --ignore-scripts
npm --prefix functions test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

`WEATHER_API_URL`, when explicitly supplied, is a public HTTPS endpoint address,
not a credential, and does not provision or enable a backend.

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

Alerts remains a demo. Tips uses live weather with documented rules; it does not
run a trained AI model. Official warnings, push delivery, trained predictions
and real accuracy/latency evaluation are not connected. This app must not be used
as the sole source of emergency warnings. Do not deploy deny-all Firestore rules
over a database shared by other apps without reviewing their access needs.
