# Performance checks — MUNORA, 17 November 2026

## What was measured

Final remediation source compiled offline to release web assets. Headless Chromium
used dummy Open-Meteo data, an isolated network namespace, context-level routing,
blocked service workers and a single-threaded fixture HTTP server. One fresh
browser context per viewport was sampled under128-process/2 GiB per-process data/
768 MiB scratch limits. This is a constrained smoke measurement, not a production
baseline, before/after speedup claim or Android-device benchmark.

| Viewport | Weather visible | Intentional branding wait | Home weather requests | Total after Forecast/Hourly/Tips |
|---|---:|---:|---:|---:|
|390×844 |7.85s |5.00s |1 |3 |
|1366×900 |8.72s |5.00s |1 |3 |

Both checks had zero page/console errors and zero unexpected destinations.
The branding delay is a source-defined timer after first frame, included in weather
visibility; subtracting it does not isolate any particular component's execution.
There is only one startup sample per size: no startup median/p95 is inferred.

The JSON's `frameIntervalMedianMs`/`frameIntervalP95Ms` fields are **idle rAF interval
samples after navigation**,60 intervals, not interaction jank or user FPS. Medians
were16.7 ms; p95 values66.7 ms / 16.8 ms. The mobile outlier includes headless software
rendering/scheduling and an animated scene; no native performance diagnosis follows.
JS heap samples were47.1 MB / 37.9 MB; they exclude WebAssembly/GPU/native allocations
and are neither peak total memory nor Android memory estimates.

Nine warmed Node24.22.1 batches, fixed72-hour fixture:

| Component | Median batch mean per call |
|---|---:|
| Validated context,43 facts |0.121 ms |
| Numeric rain inference |0.00243 ms |
| Request + answer validation |0.00147 ms |

Component timings exclude network, AI generation, storage/cloud latency and devices.
Model asset9449 bytes; fixture2541 bytes; end Node heap sample7.08 MB is not peak RSS.
Full result JSON and sandbox details are in `evidence/`.

## Fixes and follow-ups

- Chat retains at most12 paired exchanges: rendering and retained answer metadata
  no longer grow without a session bound. Eviction is visible and Clear resets it.
- Full global quota now denies before cleanup/hash/writes; SQL allocation guards
  handle exhaustion races. This reduces denied-request work but is not a WAF.
- Planner cache rejects oversized data before JSON decoding.
- The prior benchmark's deleted backend/fixture assumptions were replaced with
  current provider units, model-expanded field names and five Node fixture tests.
- Defer lazy120-hour rendering, saved-rain Future memoization, shared/foreground-only
  model timers and stale-view rebuild avoidance until dedicated layout/lifecycle
  regressions. Preserve current5 second branding policy pending a product choice.

## Reproduction

Use cached Flutter3.47.9/Dart3.13.7, Node24, Playwright and Chromium in an isolated
OS sandbox with no credentials/external network. Build web using
`flutter build web --no-pub --no-web-resources-cdn --no-wasm-dry-run`; serve its
output on loopback and run `node tools/browser_performance.cjs`.
`MUNORA_PREVIEW_URL` accepts only loopback HTTP. `MUNORA_PERF_SAMPLES` defaults3,
range1–5; the retained run used1. `MUNORA_AUDIT_OUTPUT` selects bounded scratch
output. Set `CHROMIUM_PATH` if the system wrapper requires unexposed host config.

Supervisor setup failures are not app failures: initial restricted uid mapping,
V8 virtual reservation, CA/dependency mounts, SQLite fixture naming, Chromium
wrapper config and threaded HTTP serving were corrected without weakening network
isolation or exposing credentials. The multi-model fixture schema mismatch was
covered by a failing test before correction. No generated result was substituted
for a passing final build/browser run.

## Still unmeasured

Release-signed Android cold/warm startup, scrolling/keyboard frame time, peak
memory, battery/background scheduling, OS notification delivery, real weather
latency and live AI response time. Test on representative low-memory hardware
before claiming phone readiness or setting native performance budgets.
