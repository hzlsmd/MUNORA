# Redundancy cleanup

User requests a whole-system review and removal of redundancy. Build on merged PR #37 and propose the cleanup separately.

Findings: Tips repeats action advice across the AI outlook, checklist, featured forecast card and filtered cards. Keep one contextual checklist with category filters, explicit sources/reasons/windows, and separate general flood/emergency guidance. Keep the numerical AI card, model comparison, UV guidance, personalized planner and outdoor-window summary because they serve different purposes; suppress the AI card's repeated action copy on Tips while retaining it on Home. Remove the former generic hydration/travel/outdoor/storm cards whose actions are already covered by the checklist and planner. Preserve detailed storm precautions in the single storm action.

Code/build cleanup: keep one Dart city-coordinate registry and derive city names from it; share provider weather-code labels across normalization/validation; keep one notification configuration for local and push delivery while preserving mode-specific onlyAlertOnce behavior; reuse the backend topic helper; remove proven-unreferenced demo data/model/widget, empty AI service, unused direct icon dependency and byte-identical undeclared font. Run Checks on PR changes and master pushes, with manual dispatch for standalone branches, to avoid duplicate heavy jobs on each PR commit. Keep distinct cache freshness, hazard thresholds and cross-runtime city/model contracts; do not rewrite training or immutable artifacts.

Validation: regression tests for one advice area and category filtering; all Flutter tests/analyze/web/browser checks; backend/model tests; workflow and dependency validation. Do not delete historical branches, audits or design assets without demonstrated redundancy.

Review correction: filter controls are rendered by the checklist, while their single state is owned by AIScreen above the weather-refresh keyed subtree. Same-city refresh preserves selection; changing city resets All.
