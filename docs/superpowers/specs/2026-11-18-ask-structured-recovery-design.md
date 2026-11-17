# Ask MUNORA structured answers and recovery

Implement user-selected improvements 2–6. Version 2 requests use AI only to select forecastDate (today/tomorrow PHT), topic (rain/heat/overview/current/humidity/wind/uv/unsupported), and language (en/fil). Backend renders advice and explanation from verified daily facts and conservative preparedness rules. This deliberately trades unrestricted generated prose for enforceable numeric/date/peak grounding. Version 1 remains available for installed apps; new Flutter requests use version 2.

## Approaches
Selected: bounded model selection plus server-authored structured answers. Validating arbitrary prose cannot guarantee semantic associations between numbers, hours, and superlatives. Free prose plus regex checks is insufficient. Removing AI entirely would lose conversational intent selection, especially follow-ups and bilingual requests.

## Behavior
Response includes advice, explanation, forecastDate, cited facts, responseType (assistant/weather_summary), and optional fallbackReason; answer concatenates advice and explanation for history. Backend selects citations, never AI-supplied values. Relative explicit dates must match PHT. No hours means unavailable coverage, not fabricated peaks. English and Filipino templates cover weather advice without road/flood safety guarantees.

AI malformed/truncated/unsupported selections or inference errors produce a clearly labeled deterministic weather-data summary using fresh data, never fabricated AI prose. No fallback for unavailable/stale weather, quota denial, missing bindings or cancellation/deadline. One model attempt only. Fallback language/day derived conservatively from explicit question/history, otherwise overview for today. Diagnostic logs contain only event name and fixed rejection category; never questions/history/raw model output/credentials.

Current readings remain available even when no future hours remain today. Wind and UV receive independently computed daily peaks; future humidity requests explicitly acknowledge unavailable data rather than substituting current readings. Explicit current-time and obvious wind/UV/humidity requests override inconsistent model routing. Filipino answer prose and summary labels use fixed translations; supporting source facts keep their canonical units and text.

Flutter shows structured advice, explanation, forecast date and source/freshness; fallback explicitly says AI failed and offers manual retry of the same question. Supporting source facts are expandable to avoid repeating details. Existing layout, clear/cancel, session history bounds and city handling remain. Validate v2 metadata and keep existing size/freshness limits.

## Verification
RED/GREEN backend tests for typed fields, wrong/unsupported dates, extra fabricated claims, invalid JSON, truncation, safe logs, fallback with fresh evidence, stale/absent evidence and cancellation, midnight, ties, missing hours, English/Filipino and follow-ups. Flutter parsing and widget tests cover structured responses, bad metadata, fallback label, manual retry, narrow/large-text screens; run full backend and Flutter suites plus analysis/web build. Live quality remains a separate post-deployment check.
