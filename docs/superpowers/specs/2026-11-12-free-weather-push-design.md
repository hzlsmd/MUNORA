# Free weather push notifications

## Intent and constraints

Provide timely forecast-based Android notifications for MUNORA without a billing
account or payment by users. Keep Firebase Spark, Workers Free, D1 Free and
non-commercial Open-Meteo. No paid services or upgrade. Android only initially;
web retains existing weather features. This is not a trained AI implementation,
station observation feed, or official warning service.

Project: munora-5adfa. Android: com.example.munora.
Worker: https://munora-weather.hazelsomido0.workers.dev
D1: a0858a81-3f2c-4afb-8831-bc6ab65d4fbd, binding DB.
Worker secret FCM_SERVICE_ACCOUNT_JSON is reported saved by the user; never
read or return its value. Sender identity:
munora-weather-sender-483@munora-5adfa.iam.gserviceaccount.com.

## Approaches

1. Existing on-device checks: no backend, but Android delays checks; rejected
   for timely closed-app updates.
2. Firebase scheduled functions: straightforward but requires billing; rejected.
3. Cloudflare scheduled monitoring with FCM: selected in conversation because
   free plans can cover the prototype. Free execution feasibility must still be
   measured, especially OAuth signing CPU and scheduled-event CPU limits.

## Proposed implementation decisions

Design accepted in conversation on 12 November 2026 with a one-hour reminder interval. Use public FCM city topics (munora_weather_<stable city slug>).
This avoids collecting installation tokens and needing an exposed registration
API. Public city weather needs no private audience. D1 stores only per-city alert
state and monitor leases, not device identities. Although D1 was initially
suggested for subscriptions, topic subscriptions make those records unnecessary.

Check all 17 fixed NCR locations every five minutes, splitting bounded work across
cron invocations if needed to satisfy Free limits. Fetch once per city rather than
per phone. Use bounded timeouts and a response-size limit. Reject invalid units,
unknown codes, nonfinite/out-of-range measurements, incomplete/misaligned forecast
arrays, stale estimates over three hours, or timestamps over five minutes ahead.
Do not send alerts from cached failures. The update cadence cannot improve the
weather provider's own temporal resolution.

Use the existing app thresholds: current or sampled upcoming six-hour rain or
thunderstorm, temperature >=32 C or apparent temperature >=35 C, wind >=10 m/s.
Match the app's upcoming three-hour samples for rain/storm rather than silently
introducing a different forecast trigger. Group triggers into one city message.
Send when a trigger starts; permit a one-hour reminder while it remains active.
A new trigger can notify before the reminder window. Worsening-severity thresholds
are deferred until explicitly defined; do not claim escalation detection.
No all-clear push. A failed observation does not clear active alert state.

D1 must coordinate concurrent cron attempts using an atomic claim/lease. Persist
send intent before calling FCM. A timeout after submission has ambiguous delivery;
avoid an immediate retry, accept a possibly missed event instead of an alert burst.
No exactly-once delivery claim. Use deterministic event IDs, bounded TTL and a
per-city collapse key. Never log access tokens, private keys or complete messages
containing credentials. Return only a minimal public health response; expose no
public send/cron endpoint.

Use FCM HTTP v1 with short-lived OAuth access tokens and the existing messaging
role. Parse the secret server-side, validate expected project and identity, sign
using Web Crypto and cache tokens with an expiry margin. Configuration failure
stays silent and emits a sanitized operational error. Measure cold signing CPU on
Free before declaring this architecture deployable. No paid fallback.

Flutter initializes Firebase on Android, with auto-init disabled until opt-in.
Explicit Android notification permission precedes subscription. Persist confirmed
subscription state; synchronize selected city on changes and resume, including
retry state for failed unsubscribe/subscribe. Opt-out removes subscriptions,
cancels local jobs and displayed app notifications, and explains pending failures.
Unsubscribe cannot recall a notification already accepted by FCM/Android.
Topic delivery is designed for throughput, not a low-latency guarantee.

FCM notification+data messages permit OS background display. Foreground delivery
uses the existing local notification plugin. Taps select the message city and
open Alerts after initialization; expired or unsupported payloads are ignored.
A stable event ID prevents foreground duplicates. Disable the old hourly local
worker while push is enabled to avoid duplicate delivery; do not silently switch
backends on errors. Preserve a local-mode path when push configuration is absent.
Show push settings as unavailable until configured; never label placeholders live.
Refresh foreground weather automatically every ten minutes with no overlapping
requests, pause while backgrounded, refresh on resume and retain saved-data labels.

## Setup and release boundaries

Cloud resources exist but contain Hello World, with no schema or scheduler yet.
Only client google-services.json is present in the checkout. No authenticated
Cloudflare deployment session is available in Codex. Prepare reviewed source and
exact dashboard/CLI instructions first. User deployment must preserve DB and the
secret. No private-key transfer through chat or Git. A new Android build is needed.

## Verification and acceptance

Worker tests cover freshness, trigger thresholds, repeat windows, malformed data,
provider failure, overlapping schedules, ambiguous sends, credential errors and
public-route denial. Exercise D1 SQL with a real SQLite-compatible engine locally;
verify leases and schema remotely before enabling cron. Flutter tests cover city
synchronization, permission denial, opt-in/out retries, malformed/expired tap data,
foreground duplication and lifecycle refresh. Existing Flutter suite, analysis,
web build and Android debug build must pass where toolchains are available.

Live acceptance requires Worker Free CPU/subrequest measurements, an observed
scheduled run, FCM authorization, and a physical Android phone verifying foreground,
background, terminated-app, opt-out, city-change and tap routing. Force-stop,
offline phones and battery restrictions can block delivery. No guaranteed instant
or five-minute delivery. Record measured timing and provider estimate timestamps.

## Current tooling limitation

Flutter 3.47.9 and Dart 3.13.7 were provisioned from the official Flutter GitHub
tag during implementation. The environment has no Android SDK: the APK build
reports that explicit blocker. No push is active yet.
