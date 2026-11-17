# MUNORA security/performance remediation design

User request: audit the entire project, provide risks and an implementation plan,
then proceed using Superpowers. This explicitly authorizes execution after planning;
no additional design/implementation approval loop is introduced.

Scope: audit baseline98bbac8, Flutter/Worker/notification/model/platform/CI/tooling.
Separate evidence-backed leads from hardening, source facts from live assurance,
and local component timings from native release performance. Audit artifacts live
outside source first and sanitized report copies travel with this change.

Approaches considered: sweeping dependency/framework/UI rewrites introduce unrelated
risk; report-only work would leave the requested execution unfinished. Use targeted
source fixes with red-to-green regressions and retain explicit owner/platform gaps.
This is the implementer's choice under the user's instruction to proceed.

Requirements: no production probing, real credentials, paid AI, cloud changes,
history rewriting, provider-key reuse, release publication or UI redesign. Keep
city/weather/data/model/notification contracts, existing styling, retries,
cancellation and accessibility. Use cached dependencies in a bounded offline OS
sandbox; fixtures never replace production data. Do not imply zero vulnerabilities.

Deliverables: allocation guard for exhausted global quota including races;12-pair
chat retention; corrupt planner-cache size/type bounds; dependency automation for
current backend; fixture-based current-API performance harness. Preserve complete
52-unit audit/validation limits. Defer large rendering/timer/startup changes and
owner credential/IAM/release/device checks explicitly.
