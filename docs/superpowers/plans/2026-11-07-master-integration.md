# MUNORA Master Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the cumulative MUNORA development history into `master`, verify the resulting tree, and publish a current project audit and prioritized implementation plan.

**Architecture:** Preserve history by merging `codex/weather-without-login` into `master` with a normal merge commit. Use a short-lived pull request solely as GitHub's merge mechanism, then merge it immediately after validating its exact head/base SHAs and conflict status; do not create an intermediate integration branch. The current master includes the approved design and plan documentation commits, so GitHub must construct the combined tree rather than reusing the feature tree alone. After integration, add the requested audit and implementation documents.

**Tech Stack:** GitHub REST Pull Requests/Contents APIs; Flutter/Dart; Node.js 22; Firebase Functions source; GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-07-master-integration-design.md`

## Global Constraints

- Preserve master history and the recovery branch; no force push, reset, branch deletion, or history rewrite.
- No Firebase deployment, billing activation, paid service change, provider-key revocation, or live external load test.
- Keep the public-weather/no-login prototype model.
- Do not claim AI forecasting, official warnings, push notifications, native device validation, or cloud production readiness without evidence.
- Report inherited verification separately from checks newly run during this work.
- Stop if the current branch tips or mergeability differs from the inspected SHAs.

## Review Focus

- The branch tip may move after inspection: re-fetch all refs and require exact expected SHAs before merge (Task 1).
- Master gained the design and plan documentation commits after the original branch comparison: rely on GitHub's real merge calculation and stop on conflicts rather than substituting a tree (Task 1).
- GitHub Actions may be absent, pending, or failing for the merge head: record exact workflow/run evidence and don't treat no run as a pass (Task 2).
- Prior audit measurements may refer to a different commit/environment: label them as inherited evidence, not fresh verification (Task 3).
- API/provider, Firebase, and Android signing/device constraints are not testable by source inspection alone: preserve as release gates (Tasks 2–4).

---

### Task 1: Verify refs and integrate cumulative branch

**Files:**
- Git refs: `master`, `codex/weather-without-login`, recovery branch.
- Pull request: temporary direct merge from cumulative feature branch to master.

**Interfaces:**
- Inputs at plan creation: master SHA `f364d0a9a02a26f66eb5837978b13ec1133b6f56` (subsequently advanced to `804613c5bf2067ed55bcbdf60b169942a120c5db` by approved plan documentation commits); feature SHA `0dff89abe0e570c45b188345b9de73d9fabb6f16`; recovery SHA `4af276d35dc99aedcfcc394ef77902f2d908c968`.
- Output: a GitHub merge commit with master as first parent and cumulative feature as second parent.

- [x] Re-fetch master, feature, and recovery refs and verify the expected SHAs.
- [x] Compare master to feature and inspect changed paths plus the current PR history.
- [x] Confirm the recovery ref is unchanged and master still contains the approved design/plan documents.
- [x] Create PR #8 from `codex/weather-without-login` to `master` as the direct merge mechanism.
- [x] Fetch PR #8; verify base SHA `804613c...`, head SHA `0dff89a...`, mergeability and 64-file diff. No conflict was reported.
- [x] Merge PR #8 using GitHub's normal merge method with expected head SHA `0dff89abe0e570c45b188345b9de73d9fabb6f16`.
- [x] Verify merge commit `914f27e...` has first parent `804613c...`, second parent `0dff89a...`; recovery ref remains `4af276d...`.

**Stop condition:** If a ref changed, PR reports conflicts, the diff is unexpected, or merge rejects, stop and report; do not force or improvise.

### Task 2: Verify integrated source and automation evidence

**Files:**
- Read: `.github/workflows/checks.yml`, `pubspec.yaml`, `functions/package.json`, Flutter and backend tests, Android build config, Firestore rules and documentation.
- No code modifications unless a verified defect is separately documented and authorized.

**Interfaces:**
- Verification commands from repository root:
  - `npm --prefix functions ci --ignore-scripts`
  - `npm --prefix functions test`
  - `npm --prefix functions audit --audit-level=moderate`
  - `flutter pub get`
  - `flutter test`
  - `flutter analyze`
  - `flutter build web --no-web-resources-cdn`

- [x] Inspect workflow-run lookup and combined status for merge commit `914f27e...`; both returned no records.
- [x] No local execution shell/worktree was available in this GitHub-only session; Flutter/Node/build commands were not run and are explicitly marked unverified.
- [x] Record exact SHA and empty workflow/status results; local runtime, native SDK and device checks remain unavailable.
- [x] Reconcile inherited audit/PR reports and label them as historical evidence, not fresh merge-SHA verification.

### Task 3: Create comprehensive audit

**Files:**
- Create: `docs/COMPREHENSIVE_PROJECT_AUDIT.md`
- Sources: integrated code, CI evidence, `docs/audit/2026-11-07-security-performance.md`, `docs/audit/RELEASE_CHECKLIST.md`, `docs/audit/implementation-ledger.md`, current setup and recommendation docs.

- [x] Map app architecture, providers, data flow, trust boundaries and prototype status from current source.
- [x] Document branch/PR integration record and audit scope/evidence limits.
- [x] List findings by severity with impact, mitigation, residual risk and owner action.
- [x] Cover secrets/history, API privacy, backend/App Check, Firestore, dependencies/CI, validation, cache/freshness, reliability, accessibility, signing and performance.
- [x] Separate current-source facts, inherited test evidence, and unverified production/device assumptions.
- [x] Cross-check document references and keep claims within inspected evidence.

### Task 4: Create prioritized implementation plan

**Files:**
- Create: `docs/IMPLEMENTATION_PLAN.md`

- [x] Prioritize owner security actions and release blockers before optional enhancements.
- [ ] Define phases, deliverables, dependencies, acceptance criteria, verification commands and completion gates.
- [x] Include historical key revocation, App Check/backend policy, Android signing, Open-Meteo terms, authoritative alerts, push and model research as separate milestones.
- [x] Preserve the distinction between deterministic rule-based tips and trained prediction.
- [x] Verify phases, acceptance criteria and links to audit findings.

### Task 5: Final review and report

**Files:**
- Review: merge commit, audit and implementation plan.

- [x] Re-fetch master and verify both requested documents exist.
- [x] Verify both merge parents and unchanged recovery ref.
- [x] Check document paths/references, commit history and available CI/status metadata.
- [x] Record merged work, created documents, unrun checks and unresolved gates.


## Execution record

- PR #8: https://github.com/hzlsmd/MUNORA/pull/8
- Merge commit: `914f27e6c11301b180f1e7e8b450b5893b6742fb`
- Final master after requested docs: `326ed8ae1e6e32a2b3df154965267522ed8ebac6`
- Requested audit: `docs/COMPREHENSIVE_PROJECT_AUDIT.md`
- Requested implementation plan: `docs/IMPLEMENTATION_PLAN.md`
- CI lookup for merge commit: no workflow-run records and no combined status records returned. This is not a pass.
- Local Node/Flutter commands and native Android/iOS checks: not run in this session because no local execution environment was available.
- Final review: self-review (no subagent tool). The integration and documentation are complete; test/device/cloud gates remain explicitly open.
