# Direct Google Form QR

- User reports iPhone stopping on the Apps Script claim page and explicitly requires scan -> Google Form with no extra continue button.
- User confirms only Apps Script hosting exists. Do not introduce an external redirect host or deploy to an unrelated account/project.
- Verified source: `createClaimHtmlOutput` in `apps_script/src/07_student_attendance_service.js` invokes `window.top.location.replace` within HtmlService. Google documents that the iframe sandbox restricts top navigation and recommends user activation: https://developers.google.com/apps-script/guides/html/restrictions . No iPhone console trace available; observed screen is consistent with this restriction.
- A direct Forms QR avoids this page but Forms does not report the open/scan timestamp to the backend. It cannot preserve the current claim-before-QR-expiry + 120 seconds after claim contract without an external claim/redirect endpoint.
- Pending explicit user decision: allow validation at Forms submission time with a deadline measured from ticket issuance, or preserve the existing scan-time contract. Do not silently weaken the rule, reuse a single-use grant across students, change login/email verification, or claim deployed success.
- If approved: introduce an explicit direct-form flow mode, prefill a verifiable ticket, validate server-issued ticket/session + Google Forms timestamp + authenticated respondent email, deduplicate by response/session/email, retain legacy grant submissions in flight, and update closing/finalization deadlines. Choose and document the actual submission window before deployment. Keep the existing Form, Sheet and deployment URLs.
- Required tests: many distinct roster students using one displayed code; same-email repeat and trigger replay; forged/expired ticket; delayed trigger with valid original submit time; closing in-flight submissions and finalization; legacy grant compatibility; Form opens without intermediary HTML. An accepted real submission still needs an authorized test identity.
- No implementation or remote deployment changed in this task yet.

## Approved implementation
- User approved direct Form QR with 120 seconds from issuance; rotating display remains 30 seconds.
- Implemented shared direct authorization (Grants status `direct`, deterministic FORM_ ticket token), per-email/session deduplication, trusted Forms submitted_at validation, fixed persisted deadline, legacy grant compatibility and closing wait.
- Delayed valid Form triggers may update a session after finalization: deadline applies to submission time, not trigger execution. A finalized view is not a guarantee that Google has delivered all historical triggers.
- 24 Node tests cover existing flows plus direct shared code, duplicate/replay, missing/forged/expired token, outsider email, timestamp boundaries, delayed trigger after closing and interrupted writes.
- Deployment target verified remotely: teacher v14; student legacy v10. HEAD matches committed base. Only teacher deployment and project HEAD need updating; preserve student v10 and its authenticated access settings.

## Delivered status (supersedes pending notes above)
- Teacher deployment updated to v15; remote HEAD and version 15 read back equal to all 10 local Apps Script files. Teacher access unchanged; legacy student v10 unchanged.
- Syntax checks, 24 backend tests and git diff whitespace check pass.
- Live API probe found no active session; it did not create a session or submit attendance. Phone opening and accepted real roster submission remain unverified.
- Existing Windows app consumes the new form_url without a rebuild. See docs/direct-form-qr.md for the contract and compatible rollback procedure.

## Windows shortcut correction — 2026-09-26
- User reported the Windows build was old. Desktop `QR Attendance - Test.lnk` actually targeted the Debug executable in `flutter-qr-attendance-qr-ticket-build`, not the current worktree.
- Built current source 6cbf224 with private trial defines as release 1.2.1+20260926; Flutter build succeeded. Packaged at `build/trial-1.2.1`, preserving local roster-sources.
- Updated the existing Test shortcut and added `QR Attendance 1.2.1.lnk` to this release. Launched PID 10656 and verified its executable path.
- SHA256: 702AD4AE30B61B5900EDB0E3F61053A0A5126218053CE10B78E4BD7F30753764. Packaging/shortcut correction only; no additional feature completion or live attendance acceptance claimed.
