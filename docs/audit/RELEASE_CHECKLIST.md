# Release security gates

## Provider and project ownership

- Revoke the OpenWeatherMap key exposed in commit `1244f8c`. Its removal from
  current code does not revoke it; this audit did not test or reuse that key.
- Keep `munora-weather-hzlsmd` on Spark unless the project owner explicitly
  chooses paid infrastructure. This audit activates no billing and deploys nothing.
- The app still needs a weather endpoint. The proposed direct Open-Meteo/FCM
  migration and predictive model are separate, not implemented by this audit.

## Dormant paid backend

**No backend deployment is supported by this PR.** A separate reviewed Flutter
App Check integration must land first; the complete acceptance criteria are in
the [backend policy](../WEATHER_SETUP.md#backend-policy). This audit PR is not a
deployable production-backend release. No enabling, deployment or billing steps
are offered as a current setup path.

`WEATHER_BACKEND_ENABLED` defaults to false and rejects before database work.
Enabling it requires a compatible client that sends `X-Firebase-AppCheck` and a
configured App Check provider. The current Flutter app has no App Check SDK yet.
There is deliberately no anonymous attestation bypass. App Check is not resident
sign-in, cannot stop all abuse/token replay, and does not cap invocation charges.
Do not deploy this backend as a workaround for the no-paid-services requirement.

If the owner later chooses this backend: verify attestation on real devices,
configure billing alerts and upstream rate controls, establish Firestore TTL on
`weatherInternal.expiresAt`, review least-privilege IAM and logging retention,
and tune the provider budget to actual traffic. A 1,000-refresh daily cap with a
ten-minute cache cannot sustain all 17 cities continuously (about 2,448 refreshes
per day before duplicate work/failures). Failures count toward that cap.

## Android signing

Release builds no longer use the debug signing key. Configure these variables
on the trusted build machine, keeping the keystore outside the repository:

- `MUNORA_KEYSTORE_PATH`: path to the existing release keystore.
- `MUNORA_KEY_ALIAS`: release alias.
- `MUNORA_KEYSTORE_PASSWORD`: store password.
- `MUNORA_KEY_PASSWORD`: key password.

If any value is missing/blank, AGP disables all `release` build-type variants in
`beforeVariants`, including flavored variants, before generating their tasks.
No incomplete release signing config is created. Release APK/AAB invocations
then fail because the release variant/task is unavailable, not because a
task-name hook happens to match. Gradle logs the reason without credential values.
Debug builds keep their ordinary development signing and remain available.
Native release compilation/signing requires Android SDK and must be verified
on the team's build machine; this cloud audit does not claim that validation.

On that machine, verify the following before merging the signing change:

- With all four variables unset, and with each one individually missing or blank:
  debug APK builds work; release APK/AAB builds fail; `:app:tasks --all` exposes
  no app release variants. Repeat for every flavor if flavors are later added.
- With all four variables set to a disposable test keystore: release APK/AAB
  builds work and `apksigner verify --print-certs` / `jarsigner -verify` confirms
  the intended certificate. Invalid paths/passwords must fail signing.
- Never use production signing credentials in public logs or committed fixtures.

## Distribution and operations

- Test Android/iOS notification, permission and lifecycle behavior on hardware
  before claiming support. This repo currently contains no working push/ML module.
- Validate macOS outbound networking and signed entitlements on a Mac.
- Serve web builds over HTTPS; configure server HSTS, CSP compatible with Flutter
  rendering, `X-Content-Type-Options: nosniff` and frame restrictions at the actual
  hosting layer. A local Python preview does not demonstrate production headers.
- Weather cache and city preference data are local, unencrypted preferences.
  Store no tokens, credentials, exact location history or sensitive user data there.
- Keep alerts and AI marked as demos until real validated sources/models exist.
- Review dependency updates and the targeted rimraf override before SDK upgrades.
- Do not publish service-account keys, Firebase CLI authorization material, signing
  files, `.env` files, or raw exception/request URLs containing provider keys.
