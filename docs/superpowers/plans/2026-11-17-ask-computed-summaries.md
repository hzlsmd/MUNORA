# Ask computed summaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give AI deterministic daily peak facts instead of requiring it to compare hourly rows.
**Architecture:** A pure summary helper consumes validated hourly records and server time, returns existing fact objects, and is invoked before model generation.
**Tech Stack:** Existing JavaScript Worker and Node test runner.
**Spec:** docs/superpowers/specs/2026-11-17-ask-computed-summaries-design.md

## Global Constraints
No dependencies or UI/API/quota changes; values <=180 characters; PHT calendar; only upcoming validated readings.

## Review Focus
- Midnight changes today/tomorrow grouping.
- No hours for a date produces no fabricated peak.
- Equal maxima choose earliest hour, not a continuous interval.
- Temperature and apparent temperature have independent peaks.
- Partial coverage and numeric rounding remain explicit and bounded.

### Task 1: Computed facts and model integration
Files: backend/src/assistant_context.mjs, backend/src/ask_munora.mjs, backend/test/ask_munora.test.mjs.
Interface: buildDailySummaryFacts(hourly, now) returns {id,label,value}[] from validated context.hourly.
- [x] Write tests for grouping, independent peaks, ties, midnight, empty coverage, rounding/bounds and prompt integration.
- [x] Run node --test backend/test/ask_munora.test.mjs and verify missing behavior fails.
- [x] Implement the helper and include facts ahead of raw hourly facts; prompt prefers daily summaries for daily maxima.
- [x] Run node --test backend/test/*.test.mjs, git diff --check and backend npm run dry-run.
- [x] Review diff and publish a PR; deployment and live inference remain separate verification.

## Execution evidence
- Four new regressions failed before implementation and passed afterwards.
- Final backend suite: 56/56 pass, including real local workerd/D1 tests.
- Wrangler 4.160.1 dry-run passes; git diff --check clean.
- Fresh reviewer found no blocking production issues. Initial suite exposed a test harness that stripped only single-line imports; the harness now strips multiline imports and embeds the real summary helper for Worker execution. Existing quota tests pass again.
- No production deployment or live model inference performed for this branch; prompt grounding is not semantic enforcement.
