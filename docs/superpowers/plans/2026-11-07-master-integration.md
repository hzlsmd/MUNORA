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
- Inputs at plan creation: master SHA `f364d0a9a02a26f66eb5837978b13ec1133b6f56`; feature SHA `0dff89abe0e570c45b188345b9de73d9fabb6f16`; recovery SHA `4af276d35dc99aedcfcc394ef77902f2d908c968`.
- Output: a GitHub merge commit with master as first parent and cumulative feature as second parent.

- [ ] Re-fetch master, feature, and recovery refs and verify the expected SHAs.
- [ ] Compare master to feature and inspect changed paths plus the current PR history.
- [ ] Confirm the recovery ref is unchanged and master still contains the approved design/plan documents.
- [ ] Create a pull request from `codex/weather-without-login` to `master` as the direct merge mechanism.
- [ ] Fetch the created PR and verify exact base/head SHAs, mergeable state, and expected changes. Stop if conflicts or unexpected file changes appear.
- [ ] Merge with GitHub's `merge` method and expected head SHA.
- [ ] Re-fetch master and verify the merge commit's parents, tree, and preserved recovery ref.

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

- [ ] Inspect workflow runs associated with the merge commit and report their status.
- [ ] Run only checks supported by the available GitHub environment; if no execution shell is available, do not imply the commands ran.
- [ ] Record exact run IDs, statuses, environment, and any unavailable checks.
- [ ] Reconcile prior PR test reports with the final tree and mark them as historical evidence.

### Task 3: Create comprehensive audit

**Files:**
- Create: `docs/COMPREHENSIVE_PROJECT_AUDIT.md`
- Sources: integrated code, CI evidence, `docs/audit/2026-11-07-security-performance.md`, `docs/audit/RELEASE_CHECKLIST.md`, `docs/audit/implementation-ledger.md`, current setup and recommendation docs.

- [ ] Map app architecture, external services, data flow, trust boundaries and prototype status from the integrated source.
- [ ] Document branch/PR integration record and audit scope/evidence limits.
- [ ] List findings by severity with trigger, impact, source path, mitigation, residual risk and owner action.
- [ ] Cover secrets/history, API privacy, backend default-off/App Check, Firestore rules, dependencies/CI, input validation, cache/freshness, reliability, accessibility, build/signing and performance.
- [ ] Separate verified current facts, inherited test evidence, and unverified production/device assumptions.
- [ ] Verify every referenced file/path and avoid claims not supported by evidence.

### Task 4: Create prioritized implementation plan

**Files:**
- Create: `docs/IMPLEMENTATION_PLAN.md`

- [ ] Prioritize owner security actions and release blockers before optional enhancements.
- [ ] Define phases, deliverables, dependencies, acceptance criteria, verification commands and completion gates.
- [ ] Include historical key revocation, App Check client integration/backend policy, Android signing/native builds, Open-Meteo terms/limits, authoritative alerts, push notifications, and actual AI-model research as separate scoped milestones.
- [ ] Preserve the distinction between deterministic rule-based tips and trained prediction.
- [ ] Verify plan tasks are actionable and linked to findings in the audit.

### Task 5: Final review and report

**Files:**
- Review: merge commit, audit and implementation plan.

- [ ] Re-fetch master and verify both documents exist at the final head.
- [ ] Verify merge parents and preserved recovery ref.
- [ ] Check document links, paths, commit history and available CI status.
- [ ] Report exactly what was merged, created, and tested; list unresolved gates without overstating completion.
