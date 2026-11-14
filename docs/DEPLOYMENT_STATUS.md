# MUNORA deployment status — 14 November 2026

## Current architecture

- The Flutter app fetches weather directly from Open-Meteo. Local preferences,
  feedback and cached weather stay on the device. Browsing needs no account.
- Default Android builds use local notifications and approximately hourly
  Workmanager checks. Startup/resume reconcile the saved opt-in and OS permission,
  including restoring local jobs after switching away from a push-enabled build.
- Android builds with `ENABLE_WEATHER_PUSH=true` use Firebase Messaging city topics
  and replace local background checks. Firebase client configuration is present;
  the private FCM service-account key belongs only in the Worker secret.
- `backend/` contains the Cloudflare Worker/D1 monitoring service. The one-minute
  cron partitions 17 cities into five slots: each city is checked every five
  minutes. Ongoing conditions have one-hour reminder suppression.
- Explicit FCM 429/5xx rejections restore prior history and wait at least five
  minutes before retrying. Valid Retry-After headers can extend that delay to at
  most 24 hours. Uncertain sends keep the one-hour reservation to limit duplicates.

## Evidence and limits

On 14 November 2026, a read-only request to
`https://munora-weather.hazelsomido0.workers.dev/health` returned the expected
`munora-weather` service JSON with five-minute cadence and 60-minute reminders.
This confirms the public route responds; it does not identify the deployed source
revision or prove cron execution, D1 state, OAuth success, FCM acceptance or phone
delivery. Earlier setup records report that the owner deployed the Worker,
created the table and enabled scheduling. Those reports are separate from the
current health observation.

The latest baseline GitHub Checks run at source `2a131538024f13bfa84348651d5b72faa7aa87f9`
passed Flutter analysis/tests/web build, backend/model tests and Android debug
compilation. See [verification](setup/VERIFICATION_WEATHER_PUSH.md) for historical
records and the notification reliability regression checks. A debug APK build is
not a physical-phone acceptance test.

The notification reliability changes still require merge, deployment and real
Android acceptance. No deployment, cloud mutation or live FCM topic send was
performed as part of this review/fix. Verify both local-to-push and push-to-local
updates with the same application ID and compatible signing key.

Historical notes about removing an older Firebase backend on 9 November do not
describe the newer Cloudflare/FCM implementation. Historical credential revocation
remains unverified; check the provider's credential inventory without copying
secret values into source, logs or issues. Open-Meteo needs no replacement key.

See [push runbook](setup/DEPLOY_WEATHER_PUSH.md),
[local notifications](NOTIFICATIONS.md) and [weather setup](WEATHER_SETUP.md).
