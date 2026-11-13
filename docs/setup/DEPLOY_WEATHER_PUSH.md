# Deploy MUNORA free weather push

The implementation is prepared locally, not deployed. Keep Firebase Spark and
Cloudflare Workers/D1 Free. Do not enable a billing plan or trial to complete
these steps. No domain purchase or public device-registration endpoint is needed.

## Existing resources

- Worker: `https://munora-weather.hazelsomido0.workers.dev`
- Firebase project: `munora-5adfa`
- Android package: `com.example.munora`
- D1: `munora-weather`, ID `a0858a81-3f2c-4afb-8831-bc6ab65d4fbd`
- D1 binding: `DB`
- Worker secret: `FCM_SERVICE_ACCOUNT_JSON` (already saved by owner)
- FCM identity: `munora-weather-sender-483@munora-5adfa.iam.gserviceaccount.com`

The private service-account JSON belongs only in the Worker secret. The app's
`android/app/google-services.json` is client configuration, not that private key.
Do not replace the client file with a service-account JSON.

## Prepare backend (on a computer with Node 24+)

From the MUNORA repository:

```sh
cd backend
npm ci
npm test
npx wrangler login
npx wrangler d1 execute munora-weather --remote --file=schema.sql
npm run deploy
```

Login grants local CLI deployment access. It is separate from the GitHub plugin
and the browser session. Confirm the account and resource names before running
remote commands. Wrangler configuration preserves variables and references the
existing DB; no secret value is included in the bundle. Deploying this replaces
the Worker source. The current config preserves the one-minute cron already
enabled by the owner and persists invocation logs. Deployment starts scheduled
monitoring; use an empty cron list only when deliberately pausing monitoring.

Check `/health`; it describes the service, not successful FCM delivery or provider
freshness. No `/send` or public manual-trigger endpoint exists.

## Configure the Android build

Use the repository's supported Flutter 3.47.9 and Android SDK setup. The client
config is already placed in `android/app/google-services.json`.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=ENABLE_WEATHER_PUSH=true
```

Install `build/app/outputs/flutter-apk/app-debug.apk` on an Android phone with
Google Play services and internet access. Open notification settings, enable
weather notifications and grant Android permission. This uses topic
`munora_weather_<lowercase_city_with_underscores>` (e.g. `munora_weather_manila`).
No user account or device-token upload endpoint is introduced.

Without the build define, local hourly checks remain the notification mode.
A build with push enabled replaces those local background checks. Web does not
initialize Firebase or subscribe to push.

The existing "Send test notification" button checks local Android display only.
It does NOT prove that Cloudflare, FCM authorization or background push works.
To verify FCM independently use Firebase Messaging's test-device workflow on a
controlled phone; do not publish its registration token or send tests to city
topics with other subscribers.

## Enable and validate scheduled monitoring

The owner enabled this schedule in the dashboard. The current checked-in config
preserves it so a Git-triggered deployment does not silently remove the schedule:

```json
"triggers": {"crons": ["* * * * *"]}
```

Logs are also enabled in the config. To deliberately pause monitoring, set
`crons` to `[]` and deploy; restore the expression to resume.

The cron runs each minute and checks 3–4 cities according to their slot. Each of
17 cities is checked every five minutes, not every minute. Expect up to five
minutes before a city's first check. This makes 4,896 city weather requests daily;
OAuth/FCM calls are additional. Incoming request quota alone is not sufficient to
prove free-plan feasibility.

Before broad use, inspect real Worker CPU time (including cold OAuth signing),
subrequests, cron duration, D1 usage and provider limits on the Free account. A
local dry-run and Node tests do not measure Workers Free CPU. If free limits are
exceeded, disable cron and optimize or reduce scope; do not upgrade automatically.

No error or quota failure is an all-clear. Logs emit only a sanitized city failure,
not secrets. Investigate with the dashboard and confirm configuration. FCM OAuth
failure and malformed/stale weather must produce no notifications.

## Delivery behavior

- Rain/storm: current estimate or all available hourly samples within the next six hours.
- Heat: temperature >=32 C or apparent temperature >=35 C.
- Wind: >=10 m/s.
- A newly active condition can notify immediately after a successful check.
- Same ongoing condition: reminders at most once per hour.
- Provider failures retain prior alert state and do not generate all-clear pushes.
- Before sending, persist a cooldown. If FCM times out, it may have accepted the
  message. Avoid an immediate duplicate; the next reminder may be up to an hour
  later. FCM acceptance is not proof of phone delivery.
- Topic messages have a one-hour TTL and a per-city collapse key.
- Notification tap opens Alerts for the message's city. Invalid or over-one-hour
  tap payloads are ignored. Foreground messages for another city are ignored.
- Opt-out removes subscriptions and clears local notifications. A queued OS/FCM
  message cannot always be recalled. If offline cleanup fails, settings show it
  as pending and retry on resume or via "Retry push connection".
- Forecast guidance is not an official PAGASA warning or a trained AI prediction.

## Phone acceptance checklist

1. Permission denied: no enabled subscription; retry permission intentionally.
2. Opt-in and selected city: verify subscription status and matching push city.
3. Foreground message: one visible local notification, not two.
4. Background/terminated app: verify FCM notification and tap city/Alerts routing.
5. Cold start tap: complete splash, then show the correct city Alerts.
6. Change city online: old topic removed before new topic is subscribed.
7. Change city offline, restart, reconnect: pending removal retried before subscribe.
8. Opt-out offline and online: pending cleanup visible; no new subscription created.
9. Observe a scheduled weather-triggered notification and one-hour repeat timing.
10. Record provider estimate time, Worker time, FCM acceptance and phone arrival.
11. Verify notification channels, icon, battery restrictions and force-stop limits.

Push is near real time, not guaranteed instant. Topic fanout prioritizes throughput;
Android normal-priority delivery can be delayed by Doze, connectivity and device
restrictions. No billing account is a goal, not a promise of unlimited capacity.
