# Release security gates

## Provider and project ownership

- Revoke the OpenWeatherMap key exposed in commit `1244f8c`. Its removal from
  current code does not revoke it; this audit did not test or reuse that key.
- Keep `munora-weather-hzlsmd` on Spark unless the project owner explicitly
  chooses paid infrastructure. This audit activates no billing and deploys nothing.
- The app now defaults to direct Open-Meteo for the non-commercial prototype.
  Review its current terms/rate limits and attribution before distribution.
  The default Android build uses local notifications. The optional FCM build
  requires the coordinated rollout in [push setup](../setup/DEPLOY_WEATHER_PUSH.md).
  The bundled rain model remains experimental; see [model limitations](../AI_RAIN_MODEL.md).

## Former Firebase backend

The former Firebase weather-functions backend was removed on 9 November 2026.
The current optional push backend is a Cloudflare Worker using FCM; its rollout
and delivery acceptance are tracked in [deployment status](../DEPLOYMENT_STATUS.md).
The default local-notification APK does not require that backend. Historical
Firebase-functions audit findings describe removed source.

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
  before claiming device delivery. Android notification code and a local experimental
  rain model are present; the push-enabled build requires backend and phone acceptance.
- Validate macOS outbound networking and signed entitlements on a Mac.
- Serve web builds over HTTPS; configure server HSTS, CSP compatible with Flutter
  rendering, `X-Content-Type-Options: nosniff` and frame restrictions at the actual
  hosting layer. A local Python preview does not demonstrate production headers.
- Weather cache and city preference data are local, unencrypted preferences.
  Store no tokens, credentials, exact location history or sensitive user data there.
- Label forecast notices and rule-based Tips with their source, trigger and data
  timestamp; they are not official advisories. Label the separate trained rain
  outlook experimental and preserve its freshness/domain gates.
- Review dependency and Android toolchain requirements before SDK upgrades.
- Do not publish service-account keys, Firebase CLI authorization material, signing
  files, `.env` files, or raw exception/request URLs containing provider keys.
