# API redirect investigation — 2026-09-26

Scope: investigate robust remediation; no production code, deployment, Sheet or attendance writes in this investigation. Workspace flutter-qr-attendance-qr-grants, HEAD c80f46b.

## Verified evidence
- Current teacher deployment v19, ANYONE_ANONYMOUS, USER_DEPLOYING (Apps Script API readback).
- Same Flutter service reproduces invalid_response and request_timeout.
- Captured chain: script.google.com /exec -> HTTP302 script.googleusercontent.com /macros/echo -> HTTP302 back to original deployment /exec. Bodies empty. This is a return to execution, not a forward content hop.
- Adding a fresh query nonce and Cache-Control:no-cache still failed. Python client with cookie jar/browser user agent timed out before first response; insufficient evidence to blame Flutter alone or cookies.
- Build diagnostics false. GET failure log omits code/details, view discards exception, empty state incorrectly appears after failure.
- UI startup concurrently requests weekly overview and startup data. Backend overview/active-session reads both acquire global mutation lock and finalize closing sessions. This is a code-confirmed latency contributor, not proof of the redirect cause.
- Why Google returns to exec remains unproven; need execution correlation and an independent network comparison. Earlier successful readback does not establish reliability.

## Remediation order
1. Always-on bounded sanitized error diagnostics: request ID, build/API version, action, duration, HTTP status/content type/bytes, redirect host and hop, classified failure; never credentials, full Location/query strings, QR/Form tokens or student rows. Link local log export from error UI; backend structured logs with same request ID.
2. Explicit redirect state machine: distinguish forward content redirect, return-to-exec, login/access redirect, invalid host, malformed body and timeout. Stop repeat reads of an unchanged redirect URL. Do not blindly replay a mutation when following a return-to-exec URL. Read retries bounded/backoff; writes use operation receipt/reconciliation and persisted idempotency keys before retry.
3. Correct load/error/empty/stale UI states. Persist validated weekly data, show last-updated and stale status. A failed first load is not an empty calendar. Require current server validation before opening attendance.
4. Reduce duplicate startup requests. Split settlement from full read-lock duration while preserving snapshot/version consistency and closing-session correctness; do not simply remove locks.
5. If ContentService return-to-exec persists, prototype Apps Script API scripts.run for teacher app. This eliminates ContentService response URL redirects without adding a separate host. Requires API executable deployment, common standard Google Cloud project, OAuth desktop client and scoped teacher authorization; existing clasp deployment token is not an app login solution. Keep Sheets/Form trigger and student direct Form flow. This is a proposal, not a verified replacement.

## Acceptance
- Regression tests: forward redirect, return-to-exec, loop, auth redirect, 429/5xx, slow response/cancellation, malformed JSON, redacted logs, offline cached view, recovery and one-write semantics.
- Live staged samples: 20 serial reads including cold start, ten tab switches with no redundant load, app restart with cache, a later repeat window and independent network comparison if transport failures persist. Record success rate and p50/p95, not only one success.
- Controlled authorized test session: start, QR, real enrolled test submission, result reconciliation, close and restart; repeated operation must not duplicate data.
- Do not declare a complete fix until client/server correlation locates failures and live acceptance passes. Apps Script platform/network availability cannot be guaranteed 100 percent.

Sources:
- https://developers.google.com/apps-script/guides/content#redirects
- https://developers.google.com/apps-script/guides/logging
- https://developers.google.com/apps-script/api/how-tos/execute
- https://developers.google.com/apps-script/guides/support/best-practices
