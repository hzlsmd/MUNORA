# Free push notification setup

Status: backend and optional Android FCM integration are implemented locally;
not deployed or validated on a phone. See [deployment instructions](DEPLOY_WEATHER_PUSH.md).

## Intended architecture

A Cloudflare Worker checks Open-Meteo for subscribed NCR cities every five minutes.
D1 records alert state to suppress duplicates. Firebase Cloud Messaging (FCM)
delivers notifications to opted-in Android installations. Weather is model-based;
five-minute polling is not a promise of five-minute detection or delivery.

Use Workers Free, D1 Free and Firebase Spark. Do not enable Workers Paid,
Firebase Blaze, a trial requiring a payment method, or paid Cloud Functions.
A free quota being exhausted can stop monitoring or delivery. Prototype capacity
must be measured, particularly Worker CPU time for weather parsing and FCM
OAuth signing, database operations and outbound request limits.

## 1. Cloudflare

1. Create or sign in to an account at https://dash.cloudflare.com/.
2. Use the free developer platform; purchasing a domain is unnecessary.
3. In Workers & Pages, create a Worker named `munora-weather`, on the Free plan.
   The dashboard may group this under Compute & AI.
4. In D1, create a database named `munora-weather`.
5. Record the account ID, Worker URL and database ID. These are identifiers,
   not account passwords. The implementation will provide the schema, D1 binding
   named `DB`, and cron configuration; do not deploy placeholder monitoring code.
6. If the dashboard requires a payment method for a feature, stop that setup
   step and report the feature name. Do not upgrade to satisfy it.

## 2. Firebase

1. Open https://console.firebase.google.com/ and create `MUNORA`.
2. Keep the project on Spark (no payment method). Analytics is optional and
   unnecessary for notifications.
3. Add an Android app. The repository's current application ID is
   `com.example.munora`; use that exact value unless we first change the app ID.
4. Download `google-services.json`. It is Android client configuration, not
   a service-account private key. Flutter Firebase configuration will be wired
   during implementation. It alone does not enable push delivery.
5. Open Project settings > Cloud Messaging. Confirm Firebase Cloud Messaging
   API (HTTP v1) is enabled. Use HTTP v1, not legacy server keys.
6. Record the Firebase project ID. No Firestore, Firebase Functions, Firebase
   Storage or paid Firebase service is required by this architecture.

## 3. Credentials (during deployment only)

The Worker needs an authorized identity to send through FCM HTTP v1. Configure
an identity with only the required messaging permissions. Put private keys and
other server credentials in Cloudflare Worker secrets using the dashboard or
`wrangler secret put`; never paste them into chat, commit them, or bundle them
in the Flutter app. Do not create or distribute account-wide API tokens.

Account creation does not connect either service to this Codex workspace.
Authenticated deployment access will need to be configured separately.

## 4. Required implementation and verification

- Worker: validated allowlisted city weather, fresh-data checks, scheduled
  monitoring, persisted duplicate suppression, bounded retries and FCM v1.
- Subscription API: per-installation authorization, city validation, token refresh,
  opt-out deletion and expired-token cleanup. An FCM token is not authorization.
- Flutter: explicit opt-in and Android permission, Firebase initialization,
  foreground/background handling, notification-tap routing, city synchronization,
  and automatic foreground weather refresh. Avoid simultaneous local and remote
  delivery for the same alert.
- Tests: stale/malformed data, provider failures, duplicate/retried cron execution,
  permission denial, opt-out, city changes, token replacement, and quota failures.
- A physical Android device: background delivery, notification tapping, revoked
  permissions, restart, and real delivery latency. Android force-stop and network
  restrictions can prevent delivery.
- Cloudflare: measure real CPU/subrequest/database usage, verify cron actually
  executes on Free, and confirm FCM authorization and delivery end to end.

No implementation should label unconfigured push as active. AI training and
predictive analytics are a separate project from this notification delivery work.

## Official references

- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/workers/platform/limits/
- https://developers.cloudflare.com/d1/platform/pricing/
- https://firebase.google.com/pricing
- https://firebase.google.com/docs/cloud-messaging/flutter/client
- https://firebase.google.com/docs/cloud-messaging/auth-server

Pricing pages checked 12 November 2026. Account-specific availability and actual
free-plan execution remain to be verified; this is not a deployed service.

## Current project identifiers

- Firebase project: `munora-5adfa`
- Android package: `com.example.munora`
- Worker: `https://munora-weather.hazelsomido0.workers.dev`
- Cloudflare account: `d47c9ddabf3322c910aec7a165616679`
- D1 database: `munora-weather`
- D1 database ID: `a0858a81-3f2c-4afb-8831-bc6ab65d4fbd`
- Binding name: `DB` (user reports configured; not remotely verified)

Worker URL checked 12 November 2026: HTTP 200 with `Hello World!`.
Android client JSON validated and placed locally at
`android/app/google-services.json`. No push credentials or deployment access
have been configured in Codex. Cloud resources are placeholders, not an active
weather monitoring service.
