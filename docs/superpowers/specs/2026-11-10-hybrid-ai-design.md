# Hybrid AI recommendations

Approved in chat: Gemini free tier, Cloudflare Workers Free, deterministic hazards plus personalized AI text. Capstone use; no paid service or billing activation.

## Behavior
The Tips activity planner keeps its existing assessment and precautions. After checking a complete, fresh plan, users may explicitly request an AI recommendation. Share only the city, activity, window, validated weather values and hazard enums. Explain that these inputs go to Google through the recommendation service. No names, GPS, feedback or stored routine is transmitted. AI text is supplementary and labelled AI-generated; it never replaces the rule assessment or alters alert/notification logic.

## Architecture
A Flutter HTTP service calls POST /recommendations on a configurable HTTPS Worker. A Worker validates bounded structured inputs, recomputes selected-window hazards/status, calls Gemini generateContent with a JSON schema, validates bounded output, and returns context-bound, expiring advice. API key exists only as a Worker secret. A configurable model must be verified as free-tier eligible in the user's Google account. A global Durable Object reserves a small daily request budget atomically and enforces per-client limits. Worker Cache API reuses valid recommendations. Failure, quota exhaustion, invalid output, changed plans and stale data leave rule-based tips available. No automatic AI polling or AI background notifications.

## Hazard coverage
Preserve provider hourly condition readings separately from the existing 40 display samples. Rules and notifications use full readings, including the current forecast hour. Legacy caches with sampled-only readings must not be reused for new Open-Meteo requests.

## Approaches
AI-only advice was rejected in favor of hybrid rules plus AI. OpenAI paid API does not fit the free-only constraint. Gemini and a Worker on free plans were approved; account eligibility and quotas remain external prerequisites.

## Validation and setup
Add unit, widget and Worker tests covering success, malformed/oversized requests and responses, stale timestamps, plan changes during requests, missing configuration, quotas and outages. Run analysis, full Flutter tests, web build and browser smoke if SDK setup succeeds. Document exact secret/deploy/build commands, privacy limitations of provider free tiers, free quota behavior and model selection. No deployment or billable resource creation is part of local implementation.
