# MUNORA Master Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the cumulative MUNORA development history into `master`, verify the resulting tree, and publish a current project audit and prioritized implementation plan.

**Architecture:** Preserve Git history with a two-parent merge commit whose first parent is the current `master` and second parent is `codex/weather-without-login`. The branch comparison indicates the master-side change since the common ancestor is only the existing PR #1 merge commit, whose tree is already represented by the feature branch ancestry; verify the tree and parent SHAs immediately before creating the merge commit. After integration, create documentation commits on `master` and run GitHub-hosted checks where available.

**Tech Stack:** GitHub REST Git database and Contents APIs; Flutter/Dart; Node.js 22; Firebase Functions source; GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-07-master-integration-design.md`

## Global Constraints

- Preserve master history and the recovery branch; no force push, reset, branch deletion, or history rewrite.
- No Firebase deployment, billing activation, paid service change, provider-key revocation, or live external load test.
- Keep the public-weather/no-login prototype model.
- Do not claim AI forecasting, official warnings, push notifications, native device validation, or cloud production readiness without evidence.
- Report inherited verification separately from checks newly run during this work.
- Stop if the current branch tips or merge-tree assumptions differ from the inspected SHAs.

## Review Focus

- The branch tip may move after inspection: re-fetch all refs and require exact expected SHAs before merge (Task 1).
- The existing master-only merge commit may create a merge-tree difference: verify the feature tree is an appropriate merge result; if not, stop rather than fabricate a tree (Task 1).
- GitHub Actions may be absent, pending, or failing for the target head: record exact workflow/run evidence and don't treat no run as a pass (Task 2).
- Prior audit measurements may refer to a different commit/environment: label them as inherited evidence, not fresh verification (Task 3).
- API/provider, Firebase, and Android signing/device constraints are not testable by source inspection alone: preserve as release gates (Tasks 2–4).

---

### Task 1: Verify refs and integrate cumulative branch

**Files:**
- No source files modified in this task.
- Git refs: `master`, `codex/weather-without-login`, recovery branch.

**Interfaces:**
- Inputs: expected master SHA `4af276d35dc99aedcfcc394ef77902f2d908c968`; expected feature SHA `0dff89abe0e570c45b188345b9de73d9fabb6f16`.
- Output: a two-parent merge commit with master as first parent and cumulative feature as second parent; update `master` only if its current SHA still matches the expected master SHA.

- [ ] Re-fetch master, feature, and recovery refs and verify the expected SHAs.
- [ ] Compare master to feature and verify the shared ancestor and file tree relationship.
- [ ] Fetch the feature commit tree SHA and verify that the resulting tree includes the PR #1 tree and all cumulative branch changes.
- [ ] Create a merge commit with parent order [master, feature], using the verified feature tree only if the merge is clean and equivalent.
- [ ] Update `refs/heads/master` with a non-forced ref update and expected old SHA.
- [ ] Re-fetch master and verify its new commit has the exact two parents and expected tree.

**Stop condition:** If a ref changed, merge tree differs, conflict is reported, or non-forced update rejects, stop and report; do not force or improvise.

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
