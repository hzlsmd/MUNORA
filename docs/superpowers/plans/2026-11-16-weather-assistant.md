# Weather assistant implementation plan

**Goal:** Implement the user's requested functional improvements in the existing Flutter application.
**Architecture:** Extend existing services and local storage; keep actual ML inference distinct from rules.
**Spec:** ../specs/2026-11-16-weather-assistant-design.md

## Constraints and review focus

No fabricated measurements, exact-delivery promises or physical-device success claims.
Preserve existing edits and push/local behavior. Test denied permission, stale cache,
missing measurements, opt-out races and rapid location/connectivity changes.

## Tasks (implemented directly in this session)

- [ ] Establish Flutter tooling and run baseline tests; record external blockers.
- [ ] Notifications: add failing policy/platform tests, persist category and quiet-hour preferences,
  deduplicate unchanged events, create the channel, include advice, and verify delivery arguments.
- [ ] Weather/offline: add failing cache/connection tests, preserve bounded historical snapshots,
  expose connection state and synchronize on reconnect without duplicate requests.
- [ ] Guidance: test real weather rules, provide Home recommendations and persisted ML results
  with saved/expired labels and offline rule fallbacks.
- [ ] Visuals: test WMO/night mapping, replace fixed hero with bundled painted scenes and a crossfade.
- [ ] Run regression tests/analyzer/build where available, review diff, and document changes,
  measured results, toolchain limitations and physical Android acceptance steps.
