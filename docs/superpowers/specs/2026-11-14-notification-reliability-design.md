# Notification reliability fixes

The user approved the four recommendations from the repository audit: retry
confirmed push rejections, reconcile notification mode at startup, preserve safe
failure diagnostics, and correct deployment documentation.

Keep the existing Cloudflare/D1/FCM and Flutter/Workmanager architecture. Preserve
the one-hour reservation after uncertain timeouts; an accepted send may have been
delivered. For explicit transient FCM rejections (429 or 5xx), restore previous
alert history and use the existing lease as a persisted retry delay of at least
five minutes, respecting Retry-After. Fence restoration by the lease owner and
expiry so an older invocation cannot overwrite a newer reservation. No immediate
in-invocation retries or new database migration are needed.

At Android startup and resume, reconcile the stored opt-in with the build mode.
Local builds register the periodic job with keep semantics when opted in, and
cancel it when opted out. Complete legacy push cleanup as a separate operation;
an offline push cleanup must not prevent restoring local checks. Never request
notification permission at startup. Push builds retain their existing local-job
cancellation and subscription reconciliation.

Use allowlisted stage/category/status diagnostics; never log upstream bodies,
request headers, URLs, credentials, raw exception messages or stacks. Preserve
the failed stage for database, weather, OAuth and FCM boundaries.

Approach: targeted changes to existing services rather than a new delivery queue
or notification framework. A durable queue would broaden the deployment and
migration scope; unconditional retries would risk duplicate delivery.

Document implemented behavior separately from owner-reported deployment and
verified CI/device results. Live deployment, real phone acceptance and historical
credential revocation cannot be established by repository tests. No production
deployment, merge, billing change, live topic send or credential change is part
of this implementation. Preserve experimental AI and forecast disclosures.
