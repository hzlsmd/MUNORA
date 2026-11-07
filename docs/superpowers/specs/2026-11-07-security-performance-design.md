# Security and performance audit scope

The user explicitly requested an entire-project security/performance audit,
all available risk information, an implementation plan, and execution without
another handoff. This authorizes focused reversible hardening and verification.
It does not authorize billing activation, provider-key revocation, Git history
rewriting, changing deployed Firebase rules, or implementing the still-proposed
ML/FCM/free-provider architecture.

Baseline: `47658457598b168688b8e19ee221364e63e4fcd0` on the existing draft feature
branch. Preserve the original dirty checkout; use a separate audit worktree.
Inspect Flutter, Node functions, platform configuration, dependencies, CI,
repository history, Firebase rules and documentation. Do not print secrets or
probe public services with load tests. Benchmarks use fixtures and report scope.

Harden weather boundaries with a 128 KiB response limit, at most 40 forecast
samples, bounded conditions and plausible finite measurements. Check timestamps,
city identity and chronological forecasts before caching/display. Live observations
may be at most 3 hours old with 5 minutes of future clock skew; offline data may
be at most 24 hours old. Keep the existing five-day/three-hour provider contract.

Reduce redundant client requests with per-city coalescing and a ten-minute fresh
cache, preserve explicit manual refresh, abort work on timeout/service disposal,
and retain data-generation protection. Bound backend abuse before database work,
fail closed by default, verify App Check before enabled backend database access,
add persisted refresh leases/cooldowns, and prevent older results replacing newer
ones. These controls do not guarantee zero server cost or token replay protection.

Use supported patched dependencies, fail closed for Android release signing,
restore required macOS outbound networking, bound demo chat resources, and cover
large-text layouts. Harden CI without adding user login or publishing credentials.
Deliver reproducible tests, performance measurements, prioritized findings and
explicit residual risks. No claim of formal certification, complete vulnerability
absence, trained AI, live notification support, or device performance is permitted.
