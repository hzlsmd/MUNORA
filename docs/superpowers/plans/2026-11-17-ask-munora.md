# Ask MUNORA implementation plan

**Goal:** implement the accepted weather Q&A in Tips using Cloudflare Workers AI.
**Spec:** ../specs/2026-11-17-ask-munora-design.md
**Architecture:** Flutter session-only chat → bounded `/ask` → server-validated
Open-Meteo context + existing numeric rain model → Workers AI explanation.
**Tech:** existing Flutter/http/material_ui; Worker ES modules/D1/AI; no new app SDK.

Global constraints: retain current Tips/planner/notifications, free-only account,
no credentials in APK, no live inference during automated tests, finite quotas.
Review focus: context tampering/staleness, concurrent quota claims, invalid/model
output and timeouts, close/clear/late response races, small-screen keyboard layout.

## 1. Backend (independent module domain)
- [x] Add failing Node tests for request bounds/schema/city and missing bindings.
- [x] Add authoritative context + identical rain inference and golden parity tests.
- [x] Add guarded `/ask`, JSON model response/fact validation and atomic quota tests.
- [x] Exercise HTTP/body/CORS/error behavior in workerd with local bindings/stubs.
- [x] Prepare additive SQL migration and AI binding; preserve cron/secrets/previews.
- [x] Run full backend suite and review actual Wrangler packaging.

## 2. Flutter (independent module domain, same wire contract)
- [x] Add failing service tests for exact request, schema/city/time/size/error bounds.
- [x] Implement cancellable client and typed answers/session turns.
- [x] Add Ask entry and modal chat, suggested questions, loading/retry/clear/close.
- [x] Validate unchanged Tips/planner and narrow/large-text/keyboard layouts.
- [x] Run targeted tests, full Flutter suite, analysis and web build/browser flow.

## 3. Integration and rollout
- [x] Review backend and UI integration, no secrets or live request logging.
- [x] Update setup/status docs and publish reviewable PR with CI Android builds.
- [x] Clearly distinguish verified tests from live deployment/model/phone acceptance.
- [ ] Activate production migration/Worker and verify live generation once Cloudflare authentication works.
