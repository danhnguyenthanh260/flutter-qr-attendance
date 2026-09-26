# Windows 1.4.2 / teacher API v20

## Delivered
- Bounded ContentService redirect state machine: distinguishes return-to-exec, loops, missing Location, login and untrusted targets. Return-to-exec reads restart at the configured endpoint once with a fresh nonce; returned execution URLs are not replayed. POST transport responses that lose confirmation through redirect/malformed content surface operation_unconfirmed, with no automatic POST replay.
- A trace ID per API operation links safe local HTTP metadata to Apps Script completion logs. Release logs include action, method, host, status, content type, bytes, elapsed time and build. URLs/query strings, response bodies, teacher credentials, QR tokens and student data are excluded. Rotation bounds local log files to approximately 2 MiB.
- Expired operations do not launch further redirect/retry requests. An already-sent request may still complete server-side; timeout is not cancellation of a mutation.
- Failed first calendar load is an error, not an empty schedule. Error code and local diagnostic path are visible. Failed refresh preserves previous calendar with timestamp.
- Successful weekly reads persist only class IDs and slots in the existing endpoint/account-scoped catalog cache. A restart can display a schedule snapshot up to seven days old when class metadata is also available; no roster, session or attendance rows are stored in this snapshot. Snapshot-only navigation cannot open attendance.
- Weekly startup no longer requests the default class slots separately; failed session verification can be retried even when cached classes exist.

## Verification
- 134 Flutter tests pass; 33 Apps Script tests pass. Analyzer clean and architecture boundary check passed.
- Added regressions for return-to-exec recovery and exhaustion, no POST replay, untrusted redirects, error-vs-empty UI, retained last-good calendar, cache scope/expiry and catalog-only contents.
- Existing deployment HEAD matched v19 before update. Teacher deployment updated to v20 with existing URL/access. Legacy student v10 unchanged.
- Before deployment, live reads reproduced timeout; one post-deployment read succeeded, followed by 20/20 successful serial weekly_overview reads. Six classes returned each time. Median 5116.5 ms; nearest-rank p95 10808 ms; maximum 11707 ms. This establishes this sampling window only, not a permanent platform guarantee or proof that nonce alone caused recovery.
- Windows build 1.4.2+20260926, APP_BUILD=1.4.2; canonical Desktop QR Attendance shortcut is updated, no additional shortcut.

## Remaining limits
- No live attendance mutation/Form submission in this verification; end-to-end acceptance with an authorized enrolled test identity is still pending.
- Native visual interaction not re-tested; widget regressions cover the changed states.
- Apps Script still has material latency. Global read/settlement locking was not removed without a consistent snapshot design.
- scripts.run OAuth migration remains a separate proposed prototype, not implemented or deployed. Requires common standard Google Cloud project and desktop OAuth client configuration. User was asked whether those exist; no credentials are embedded or inferred from clasp.
- Underlying reason for Google's intermittent return-to-exec remains unproven; do not describe this release as guaranteeing all network/platform failures are solved.

Bundle identity: executable SHA256 D18A931B23F41C1DFA0F7A2524475DE39C264ECA12A9BD78EDBDEA3F6163B15A; Dart AOT data/app.so SHA256 5739C5EDDB1FC0DD98291EA68EAC7C4987964D6823DD15E62B1059669A9570E1.
