# MUNORA Master Integration and Audit Design

Date: 7 November 2026
Repository: `hzlsmd/MUNORA`
Target: `master`
Selected approach: direct integration of the cumulative development branch, followed by verification and documentation.

## Intent

Bring the reviewed cumulative MUNORA work from `codex/weather-without-login` into `master`, then provide a current, evidence-based project audit and prioritized implementation plan. The goal is to make the primary branch reflect the latest integrated prototype while preserving history and making the remaining release blockers clear.

## Current repository facts

- `master` currently points to `4af276d35dc99aedcfcc394ef77902f2d908c968`.
- `codex/weather-without-login` currently points to `0dff89abe0e570c45b188345b9de73d9fabb6f16`, 15 commits ahead and 1 commit behind `master` by GitHub's compare result.
- The cumulative development branch contains the later security/performance work, Open-Meteo integration, rule-based weather tips, Codespaces Android SDK helper, and Gradle memory mitigation.
- PRs #2–#7 were merged into `codex/weather-without-login`, not into `master`. PR #1 is already in `master`.
- `recovery/master-before-integration-20261107` currently points to the same commit as `master`.
- Existing audit and plan documents on the development branch are useful evidence, but will be checked against the final integrated tree. Their reported test results will not be represented as newly rerun results.

## Goals

1. Preserve existing commit history and the recovery reference.
2. Integrate the cumulative development branch directly into `master` without force-pushing or rewriting history.
3. Review the merge diff and resolve only understood, safe conflicts.
4. Run available backend, Flutter, static-analysis, dependency, web-build, and CI verification.
5. Create `docs/COMPREHENSIVE_PROJECT_AUDIT.md` and `docs/IMPLEMENTATION_PLAN.md` on `master`.
6. Clearly separate verified facts, inherited test evidence, unverified assumptions, and owner/device-dependent release gates.

## Non-goals and prohibited actions

- No production deployment, Firebase rule deployment, billing activation, paid infrastructure change, or external load test.
- No provider-key revocation or Git history rewrite; these require separate owner actions.
- No branch deletion, force push, destructive reset, or overwriting of unrelated work.
- No claim that Alerts, push notifications, official hazard advisories, or trained AI forecasting are operational.
- No claim that Android/iOS native builds, release signing, physical-device behavior, real Firestore contention, cloud IAM, or provider availability have been verified unless evidence is actually obtained.

## Integration and verification approach

1. Re-read the current branch tips and recovery reference immediately before writing.
2. Inspect the cumulative branch's full diff against `master`, PR history, CI status, and relevant project configuration.
3. Use a normal merge commit with `master` as first parent and the cumulative branch as second parent, preserving both lines of history. Do not fast-forward or rewrite existing commits.
4. If GitHub reports conflicts, stop and inspect the conflicting files. Resolve only when the intended behavior is unambiguous; otherwise ask the owner.
5. Verify the merge commit and branch tips before running checks.
6. Run repository-supported tests and builds where tools permit. Record exact commands, environment, results, and unavailable checks. Do not fabricate local execution or treat old PR evidence as a fresh run.
7. Write the two requested documents using the integrated tree as the source of truth. Include severity, impact, evidence, remediation status, residual risk, priorities, dependencies, and owner actions.

## Security and release guardrails

- Historical OpenWeatherMap credential exposure remains an owner revocation task; removing a credential from current source does not invalidate it.
- The Firebase backend remains disabled / not approved for deployment until a separate reviewed Flutter App Check client integration and explicit owner cost approval exist.
- Open-Meteo usage is subject to its published non-commercial terms and service limits; confirm suitability before public/commercial release.
- Android release signing and native Android/iOS verification remain explicit gates until exercised in a suitable SDK/device environment.
- Weather tips are application-defined rule-based preparedness guidance, not official warnings or a trained predictive model.

## Documentation outputs

- `docs/COMPREHENSIVE_PROJECT_AUDIT.md`: architecture and data flow, scope/evidence, branch integration record, security/privacy/dependency/reliability/performance findings, test evidence, residual risks, severity and owner actions.
- `docs/IMPLEMENTATION_PLAN.md`: prioritized phases with concrete deliverables, dependencies, acceptance criteria, verification commands, and release gates.

## Decisions left to the implementer

Follow established repository conventions, prefer reversible and minimal changes, retain the existing no-login prototype behavior, and avoid adding dependencies unless a verified requirement justifies them.
