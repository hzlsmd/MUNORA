# Ask MUNORA — accepted weather Q&A design

The owner chose a conversational weather assistant in Tips, accepted the app →
backend → AI explanation flow, and selected Cloudflare Workers AI. Existing
weather, deterministic recommendations, rain model, planner and notifications stay.
No paid plan or billing activation is authorized.

## Experience

Add one Ask MUNORA entry card in Tips, opening a keyboard-safe chat bottom sheet.
Offer umbrella, outdoor timing and heat explanation questions plus free text.
Display city and weather/source timestamps, verified supporting facts, and an
AI-generated explanation label. History stays in memory for this sheet only;
closing/clearing drops it. Loading, retry, service unavailable, quota, stale weather
and invalid response states never fabricate an answer. Preserve existing styling.

## Chosen approach and engineering decisions

Use the existing Cloudflare Worker with its AI binding, not keys in Flutter or a
new paid API. Native Android requests need no browser Origin. Browser access is
limited by configurable exact allowed origins; previews without AI/DB fail closed.
The server fetches and validates Open-Meteo data for the allowlisted selected city
rather than trusting arbitrary client weather strings. This supplies the same
provider used by the app, with explicit returned observation time if it refreshed.
Include supported experimental rain inference using the identical bundled numeric
artifact and parity-test its exported golden vectors. The rain model is separate
from the language model and never overrides forecast precautions.

A client-supplied weather blob is rejected (tampering, stale and prompt-injection
risk); an external API-key provider adds credentials/billing and was not selected.

## Wire contract v1

POST `/ask`, JSON ≤12 KiB:
`{schemaVersion:1,city,question,history:[{role:"user"|"assistant",content}]}`.
Question 1–600 characters; history at most 6 messages, each 1–600, total ≤2400.
No system messages, unknown fields, coordinates, arbitrary URLs or client facts.

Success JSON:
`{schemaVersion:1,city,answer,observedAt,generatedAt,forecastUntil,source:"Open-Meteo",model,facts:[{id,label,value}]}`.
Answer plain text ≤1800 characters. At most 6 verified fact entries; each id ≤80,
label ≤100, value ≤180 characters. Dates ISO UTC; observedAt at most 30 minutes
old or 5 minutes ahead, generatedAt recent, forecastUntil future. City must match.
The UI validates size, schema, city and dates before accepting an answer.

Errors are JSON `{schemaVersion:1,error:{code,message}}`, using HTTP 400/403/405/
413/429/502/503 and bounded, non-sensitive messages. Codes: invalid_request,
unsupported_city, unavailable, weather_unavailable, ai_unavailable, rate_limited,
invalid_ai_response. Retry-After accompanies limits.

## Backend safeguards and limits

Only fresh validated provider data; bounded HTTPS requests with no redirects.
Build a compact context of current conditions and at most 36 future hourly values.
Only fixed numeric/code-derived facts reach the system prompt. Treat the question
and history as untrusted; refuse unrelated tasks, live road/flood guarantees and
claims of official alerts. Do not expose secrets or accept tool/URL instructions.
Use `@cf/google/gemma-4-26b-a4b-it`, thinking disabled, bounded output (384 tokens),
and JSON answer plus verified fact IDs. Check the response shape, source IDs and
unsupported numeric claims. Grounding/checks reduce hallucinations; do not claim
all model text is infallible. No canned text is presented as successful AI output.

Use a separate D1 usage table, never notification state. Atomic per-IP minute/day
and global daily attempt limits: 2/minute, 10/day/IP, 60/day globally. Hash IP with
UTC day, never retain raw IP or chats; delete expired usage buckets. Global cap
is consumed last, before weather/AI calls. Missing AI/DB/schema fails closed.
Cloudflare Free's account-wide daily allowance is finite; usage limits do not
upgrade the account or guarantee capacity. No inference calls during ordinary CI.

## Deployment boundary

Prepare an AI binding and usage-table migration without changing notification cron
or secrets. Keep previews unconfigured. Deploy/migrate only after the source is
reviewable and the owner can approve the concrete live change if needed. An APK
build or mocked AI test is not proof that the live assistant is configured.
