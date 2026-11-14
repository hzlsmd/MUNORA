# System redundancy review — 14 November 2026

Reviewed application screens/services/models, backend monitoring/FCM, training interfaces, assets/dependencies, workflow triggers and current versus historical documentation. This is a source/build review, not a live production or device-delivery audit. PR #37 merged during this review; cleanup is proposed separately on its unchanged source baseline.

## Removed or consolidated

- Tips now has one category-filtered contextual checklist. Removed repeated featured/secondary forecast action cards and generic hydration/travel/outdoor/storm cards. Preserved their useful storm precautions in the single storm recommendation.
- The Tips AI card shows probability/model details without repeating action advice. Home retains its compact action copy. UV, model comparison, the selected activity plan and general outdoor-window summary remain independently useful views.
- One parent-owned category selection survives same-city refresh and resets when changing city. A regression starts with cool conditions, selects Heat, refreshes to hot conditions and verifies new advice plus selection retention.
- City names derive from the existing ordered Dart coordinate registry; no geographic values or model feature order changed.
- Open-Meteo code labels and validation share one Dart registry. Existing invalid-code and model tests remain relevant.
- Local and push modes share preference/job/channel/icon/notification identifiers and details construction; local `onlyAlertOnce=true` and push default false are preserved.
- FCM message construction reuses the backend topic helper.
- Deleted unused mock data and its exclusive WeatherAlert type, unused DemoNotice, empty ai_service, unused direct cupertino_icons dependency, and an undeclared Abyssinica font byte-identical to the retained declared font.
- CI runs on pull requests, master pushes and manual dispatch, avoiding two full sets of jobs for each PR commit. Standalone feature branches use manual dispatch or a PR.
- Historical audits/plans link to the current deployment-status document rather than presenting old architecture as authoritative.

## Intentional boundaries retained

- Frozen model cities/accepted codes/feature transforms remain separate from provider data validation. Training and exported weights/provenance were not changed.
- Dart and Worker city catalogs remain cross-runtime contracts. Python currently parses the Worker catalog; replacing it would require a separately tested data-contract migration.
- Forecast notification rules, activity-specific risk thresholds and model preparation thresholds describe different outcomes. They must not be merged merely because they contain similar numerical checks.
- Core weather, optional insights and model freshness/cancellation/cache policies serve different failure modes. Optional insight failures still cannot block basic weather.
- Local background scheduling and push subscription/delivery are alternative implementations that must support upgrades in both directions.
- Historical branches/releases and original design assets are preserved; removing old public APKs would break existing links.

## Verification

- The duplication regression failed before Tips consolidation. The same-city filter regression failed with selected=false before state was moved above the refreshed subtree.
- Provider code labels and all 17 ordered coordinate values compared equal to the previous source.
- Backend suite: 24 passed. Model suite: 7 passed. No retraining or live FCM send performed.
- Final verification: 138 Flutter tests passed, analysis clean, release web build/Wasm dry run passed. Browser regression passed at 390×844 and 1366×900 with six provider calls per scenario and no page errors. Physical Android acceptance remains pending.
