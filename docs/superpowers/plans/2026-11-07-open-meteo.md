# Live weather implementation

User approved live weather without accounts or paid Firebase. Use Open-Meteo's
non-commercial forecast API directly; preserve the current Flutter UI, city
allowlist, bounded transport, coalescing, offline cache and manual refresh.

1. Add fixture regressions for default requests, units, WMO codes, UTC times,
   forecast bounds, malformed arrays, stale current data and cache isolation.
2. Normalize Open-Meteo responses into the existing validated weather contract.
   Keep explicit custom HTTPS endpoints for existing contract tests; the dormant
   Firebase implementation retains its deployment restrictions.
3. Show accurate provider/model-time attribution with a provider link. Keep
   provider-specific cache keys so older provider data cannot be misattributed.
4. Run Flutter tests/analysis/web build, inspect phone/desktop browser workflows,
   and try a small real-provider smoke request. Update setup, terms and privacy
   documentation; publish a reviewable PR without merging.

Free service is limited, non-commercial and has no availability guarantee. No
new notification/model feature or automatic billing activation is included.
Forecast daily ranges remain ranges of sampled temperatures, not daily extrema.

## Verification

- All four implementation steps completed. 30 Flutter tests pass, including
  default provider requests, aligned/truncated arrays, units, WMO codes, stale
  data, source-isolated cache, failed refresh and 320px/2x attribution layout.
- Flutter analysis is clean; release web build succeeds with no endpoint define.
- A real provider request returned valid UTF-8 data with expected units and
  browser CORS support. Live Chromium workflows on 390x844 and 1366x900 pass:
  Home, Forecast, city change, failed manual refresh and saved weather; zero
  JavaScript errors and two successful provider requests per viewport.
- Browser verification initially failed because the sandbox could not access
  the certificate trust database for the environment's TLS proxy. Imported the
  provided proxy CA and allowed Chromium access to that database; TLS verification
  stayed enabled. A captured-response browser check also passes.
- `node tools/check_open_meteo.cjs` runs the optional live smoke check against
  a local release-build server at port 8082. Requires Playwright/Chromium; use
  MUNORA_PREVIEW_URL or CHROMIUM_PATH to override local settings. Set
  MUNORA_WEATHER_FIXTURE to a recent captured provider JSON for fixture mode.
- Native Android build and attribution-link launching on a physical device are
  still unverified here. Run `flutter build apk --debug` in the configured
  Codespace and test on a device. Firebase remains dormant; no cloud deployment.
