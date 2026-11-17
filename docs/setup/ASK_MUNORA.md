# Ask MUNORA setup and verification

Ask MUNORA is a conversational weather explanation feature in Tips. It uses
Cloudflare Workers AI; it does not replace Open-Meteo forecasts, the experimental
rain model, existing deterministic recommendations or the activity planner.

## Data flow

The chat sends only the selected NCR city, the current question and a bounded
recent conversation to `POST /ask`. The server accepts 17 allowlisted cities,
fetches fresh Open-Meteo weather itself and validates units, timestamps, codes
and hourly arrays. It creates verified facts for current conditions and up to 36
future forecast hours. Supported experimental rain probability is computed with
the same committed numeric artifact as Flutter; exported golden vectors test
feature/probability parity. Mean sea-level pressure is used, not surface pressure.

Cloudflare's `@cf/google/gemma-4-26b-a4b-it` explains those facts. It receives no
Firebase secret or client API key. Responses must have bounded plain text and
valid fact IDs; unsupported numeric claims and malformed/truncated outputs are
rejected. These checks reduce hallucination; they cannot prove every sentence
correct. Users can inspect the supplied facts and observation time. Questions
outside weather, official emergency-alert claims and road/flood safety guarantees
are outside this feature's scope.

The server has one bounded inference attempt per request; it does not retry
inference automatically. A timeout/close stops accepting a response, but the
provider may finish an inference already started. No substitute or prerecorded
answer is presented as a successful AI response.

## Privacy and quotas

- Chat history stays in the open sheet's memory. Clear/close drops it; it is not
  written to SharedPreferences or the server's database.
- Questions, selected city, history and verified weather context are sent to the
  AI service to answer. Do not claim that no external processing occurs.
- The additive D1 table stores only attempt buckets, counts and expiration times.
  Daily hashes replace raw IP addresses. Hashing is pseudonymization, not a claim
  of irreversible anonymity. Request/answer bodies are not logged by this code.
- Atomic limits are 2 attempts/minute/IP, 10/day/IP and 60/day across the app.
  Shared networks share IP limits. Failed weather/provider attempts can consume
  quota. Limits reset on UTC boundaries; the response includes Retry-After.
- Cloudflare currently documents 10,000 free Neurons/day across the account;
  model availability and account-wide usage can still exhaust that allocation.
  The application limits are not a guarantee of unlimited free service. No paid
  plan or billing change is part of this implementation.

## Production configuration

Do not treat a test APK or mocked AI test as evidence of a live assistant.
The Worker requires an `AI` Workers AI binding and the existing `DB` D1 binding.
Keep the existing notification schedule, variables and FCM secret intact.

On the correct account (`d47c9ddabf3322c910aec7a165616679`), review the additive SQL
and apply it to the existing `munora-weather` database **before** publishing the
new Worker:

```sh
cd backend
npm ci
node --test test/*.test.mjs
npx wrangler d1 execute munora-weather --remote --file=ask_munora_schema.sql
npm run deploy
```

This creates only `ask_munora_usage` and its expiry index; it does not alter or
clear notification state. It needs an authenticated account with the necessary
Worker/D1 permissions. Do not paste credentials into chat or source. Preserve
all existing server secrets. If an automatic Git deployment runs before the
migration, Ask MUNORA fails closed instead of bypassing its request limits.

Native Android sends no Origin header. For a browser build, configure
`ASK_ALLOWED_ORIGINS` with exact comma-separated HTTPS origins you own. Local
browser testing may explicitly allow `http://127.0.0.1:8083` on a development
Worker. Do not grant blanket browser origins or copy production secrets/DB into
branch previews. Previews without AI/DB remain unavailable for `/ask`; their
`/health` response does not prove inference or database access.

The app's default endpoint is
`https://munora-weather.hazelsomido0.workers.dev/ask`. A trusted build can override
it with `--dart-define=ASK_MUNORA_URL=https://your-worker.example/ask`; no AI secret
belongs in that define or the APK.

## Acceptance

1. Verify the target account remains on the intended free plan; do not activate
   paid billing to pass a test. Check AI availability and remaining account quota.
2. Deploy the reviewed migration/Worker; confirm the existing `/health` and cron
   monitoring still work. Avoid exposing FCM test-send or admin routes.
3. Ask one real weather question. Check that model generation succeeds, fact IDs
   resolve, dates/city match and returned weather is fresh. Record this separately
   from stubbed CI results, including the deployed Worker source/version.
4. Try missing/invalid input, an unsupported city, quota exhaustion in an isolated
   local test, provider timeout and malformed output; never bypass a quota to test.
5. Install a new APK. Open Tips → Ask MUNORA, use a suggestion, ask a follow-up,
   clear/close/reopen and change city. Check small screens, large text, keyboard,
   no network and refresh. No request should be sent just by visiting Tips.
6. Verify existing Tips filters, saved routines, AI rain card, local/push
   notifications and Home/Forecast behavior are unchanged.

Automated tests replace the provider/AI at the network boundary to avoid consuming
real quotas or distributing test data as app weather. Successful live generation
and physical-device acceptance must be reported separately.

## Documentation checked

- https://developers.cloudflare.com/workers-ai/get-started/workers-wrangler/
- https://developers.cloudflare.com/workers-ai/models/gemma-4-26b-a4b-it/
- https://developers.cloudflare.com/workers-ai/features/json-mode/
- https://developers.cloudflare.com/workers-ai/platform/pricing/

## Verification status (17 November 2026)

Local backend tests use mocked AI outputs, including actual workerd/D1 semantics;
they do not prove live model availability. Flutter regression tests, static analysis,
web compilation and Wrangler packaging are checked separately. Cloudflare connector
authentication repeatedly requested reauthentication, so no production migration,
Worker deployment, paid-plan change or live inference was performed in this session.
The route must be activated using the steps above before installing the new app for
live assistant testing. Existing released APKs do not contain this feature.
