# Needs validation — MUNORA 98bbac8

No severity assigned; no production traffic or credential reuse.

## Global assistant quota denial still creates per-IP D1 state

Anonymous valid /ask requests from distinct provider client IPs allocate minute/day usage rows before an exhausted shared daily quota rejects them. A bounded offline workerd/D1 fixture observed three rejected dummy IP requests add six rows, with no weather or AI invocation. The daily rows become eligible for lazy deletion at UTC day expiry. The database binding is also used by notification scheduling; practical shared resource impact remains unestablished.

Trace:
- `backend/src/worker.mjs:102` (fetch /ask routing): The public /ask path enters handleAsk without application authentication.
- `backend/src/ask_munora.mjs:203` (handleAsk request acceptance and identity): A POST with application/json, a bounded exact valid body and allowlisted city reaches quota accounting; the client identity comes from cf-connecting-ip or the shared unknown fallback at line 213.
- `backend/src/ask_munora.mjs:87` (claimQuota ordered counters): The loop processes hashed per-IP minute and daily buckets before the shared global daily bucket.
- `backend/src/ask_munora.mjs:108` (claimQuota separate D1 UPSERTs): Fresh per-IP rows persist before an exhausted global bucket returns no row and produces HTTP 429; there is no encompassing rollback.

Blocker: The deployed aggregate /ask ingress limits, effective DB attachment and D1 resource allocation, existing shared workload headroom, and feasible diversity of authentic provider client IPs are not established. These facts determine whether the observed bounded row allocation can cause meaningful shared resource contention; neither client-IP spoofability nor availability loss was demonstrated.

Owner check: Without issuing audit traffic, the owner should inspect the effective Worker route and edge rules for aggregate /ask controls and trusted cf-connecting-ip normalization, confirm that assistant and notification handlers use the same deployed D1 database, and compare existing D1 allocation/headroom with feasible distinct-IP request volume before UTC expiry. Use existing metrics and configuration to decide whether retained rows and writes can materially affect notification scheduling or exceed resource budgets.

## Historical OpenWeatherMap credential remains readable; revocation is unverified

Reachable ancestor commit 1244f8c contains a literal OpenWeatherMap credential in the historical client weather service, passed as appid by both weather and forecast requests. A repository/history reader can recover it. Baseline 98bbac8 uses Open-Meteo by default and no longer embeds or uses that credential. If the provider still accepts it, the reader could exercise its provider-account scope or consume its quota; present validity and authority remain unknown. No credential value was disclosed or used.

Trace:
- `lib/services/weather_service.dart:5` (commit 1244f8c, WeatherService.apiKey; reachable ancestor of baseline 98bbac8): A repository/history reader can recover the nonempty literal credential from historical client source. Presence was checked with its value suppressed.
- `lib/services/weather_service.dart:14` (commit 1244f8c, getCurrentWeather; analogous getForecast use at line 32): Historical request construction passes the literal credential as appid to OpenWeatherMap. Current provider acceptance and resulting account authority were not established.

Blocker: Only the provider owner can establish whether the historical credential is revoked or expired and, if still valid, its remaining scope, quota, restrictions, and billing authority. Repository source and history do not establish these current provider-account facts.

Owner check: The provider owner should privately identify the historical credential in its credential inventory, inspect revocation/expiry records and current restrictions, and review usage since exposure. Confirm permanent revocation through provider-account records. Do not submit the credential to public endpoints or include its value in audit artifacts.
