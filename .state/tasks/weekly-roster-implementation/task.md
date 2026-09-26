# Weekly roster implementation — 2026-09-26

Latest audit: user flagged Attendance and Class Data lagging the calendar flow. Source review confirms local-file-only roster preview, no export/CRUD, frozen per-tab catalog, import-conflict restriction, and historical session results coupled to current active roster. Integrated repair requirements and acceptance recorded in docs/design/roster-management-audit-2026-09-26.md. Implemented and released as Windows 1.5.0 / teacher v23; see docs/design/verification-1.5.0.md for evidence and legacy-history/network limits. No live roster mutation used for QA.

User approved implementation after FAP/data research. Workspace: flutter-qr-attendance-qr-grants, branch feature/startup-navigation-roster.

Merged origin/main bcd85b3 via 022c1a8; resolved provider/view path conflicts preserving feature architecture and session verification. Incoming navigation tests ported and validated.

Implemented weekly class-filtered calendar, lesson drilldown/date guard, weekly matrix, authenticated overview API, additive idempotent roster import with confirmation and optional identity columns, API error classification/read-only retry, per-request Sheet caching and session-name mapping fix.

Teacher deployment v17 (student legacy v10 unchanged). 125 Flutter tests, 30 Node tests, architecture check pass. Windows 1.3.0 built; native calendar and 37-row local roster preview observed. Two source files hash-verified in bundle. No live import/attendance submission performed. Existing session preserved.

Evidence, performance caveats and remaining requirements: docs/design/verification-1.3.0.md. Release packaging and final checks tracked there; do not claim full FAP parity or accepted live attendance.

## User correction implemented — 1.4.0
- User rejected class-filter-first flow. Replaced with all-class weekly schedule → clicked lesson roster → attendance/QR; removed old session form. Separate WeeklyScheduleGrid and LessonAttendanceView components; exact lesson selection cancels stale slot requests.
- Authenticated weekly_overview endpoint deployed teacher v18, student v10 unchanged. No live roster imports or submissions.
- 126 Flutter / 31 backend tests, clean analyzer/format/architecture. Test explicitly validates two simultaneous classes, no selector, correct roster/session and retained calendar.
- Built and launched trial-1.4.0, desktop shortcut renamed accordingly. Native all-class calendar observed; user began interacting, so stopped automation. Source evidence and known limits: docs/design/verification-1.4.0.md.

## 1.4.1 — date policy and test schedules
- Added six canonical ClassSlots rows A8:H13 to Test_PRM392: Sep26 x3, Sep27 x2, Sep28 x1; API readback verified. No attendance/session writes.
- Vietnam calendar policy: today/future allowed; past start and QR issuance rejected server-side. Historical results, receipt replay and closing remain available. Future UI confirmation; explicit close-current-session action in roster.
- Teacher v19 deployed, legacy student v10 unchanged. 33 Node tests, 127 Flutter tests; analyzer clean. Windows build 1.4.1+20260926. No accepted live Form submission tested.

## Redirect investigation follow-up
Live return-to-exec 302 reproduced; nonce does not fix. Deployment v19 access verified. No production mutations. Research and acceptance plan: docs/design/redirect-remediation-research-2026-09-26.md. Root cause inside Google delivery remains unproven; do not claim fixed.

## 1.4.2 — bounded redirect recovery and diagnostics
- Implemented request tracing, safe release HTTP logs, typed redirect errors, read-only bounded retry and no POST replay; weekly snapshot/error UI; omit redundant default-slot startup request.
- Teacher v20 (legacy v10 unchanged); Windows 1.4.2. 134 Flutter / 33 Node tests, analyzer and architecture pass. Live 20/20 reads succeeded, median 5116.5 ms, nearest-rank p95 10808 ms.
- OAuth/scripts.run prototype and real attendance E2E remain pending. Evidence and limitations: docs/design/verification-1.4.2.md.

## Real class test data — 26/09/2026
- User authorized SE1919/PRN232 roster and corrected their test email. Imported all 37 students into isolated IMPORTED_SE1919_PRN232_FALL2026. Only the explicitly identified user row uses their confirmed test email; original source XLS/CSV unchanged and Sheet cell note records override. No personal addresses or roster contents committed.
- Initial import response was operation_unconfirmed; direct Sheet readback confirmed 37 unique emails, all rows active, class active before any retry. Import was not resent.
- Added test ClassSlots rows 14–15: Sep26 and Sep27 slot3 13:54–15:24, explicitly noted as test schedule. Existing sample classes/session untouched. Windows1.4.2 remains current; data change requires no rebuild.

## Hide sample classes and release old blocker
User explicitly requested cleanup after opening the sample PRM392 lesson. Set Classes F2:F7 false (only six sample classes); imported SE1919 remains active. Closed old Sep20 CLASS_001 session through close API and settlement read, verified Sessions row6 status closed in Sheet. Existing records preserved. No new attendance session/submission created.

## 1.4.4 — native response-loss diagnosis and reconciliation
- Added one workspace read and paired schedule cache; refresh drops hidden sample classes and snapshot cells no longer display false 0/0. Release per-process diagnostics verified in actual Windows binaries.
- Native 1.4.3 showed real roster but user-triggered start lost ContentService response (302 then delayed 404 HTML). Readback confirmed active session. Added matching class/date/slot reconciliation and authenticated read-only QR receipt recovery, with no automatic POST replay or lifetime extension.
- Teacher v22 deployed after HEAD checks, legacy v10 untouched. 139 Flutter / 35 backend tests pass; analyzer and architecture check clean.
- Built and opened Windows 1.4.4, updated the single canonical shortcut. Native workspace loaded in 4.147 seconds, restored today's SE1919 slot3 session; actual QR displayed after successful issue_qr JSON. User took over native navigation while agent observed. Session left open for user testing; agent did not submit student Form.
- Evidence and limits: docs/design/verification-1.4.4.md. Live receipt fallback not forcibly triggered; unit tests cover it. Google delivery remains outside app control; accepted Form submission still pending.

## PRM roster and expanded test calendar — 26/09/2026
- User requested PRM data plus past/today/future test dates. Hash-verified original SE1913 PRM393 XLS against source manifest, reused its 29-row normalized roster, with 29 unique rolls/emails. No identity substitution: the user's SE193274 identity is absent from this source class.
- Updated Test_PRM392 atomically: Classes A9:H9 (IMPORTED_SE1913_PRM393_FALL2026), Roster A99:J127, ClassSlots A16:H41. Imported source names/emails/member codes unchanged; added source/test notes. Kept all existing records and active session intact.
- Both imported classes now have 14 test lessons each: Sep19,21,23,24,25,26,27,28,29,30 and Oct1,3,5,10. PRM slot2 09:39–11:09; PRN slot3 13:54–15:24. Added 26 lessons, preserving two existing PRN lessons. For Sep26 baseline each class has 5 past, 1 today, 8 future dates. These are synthetic test schedules, not official schedules or fabricated attendance results.
- Every written cell re-read and compared to intended values; date formatting and notes verified. Live workspace API returned PRM 29 students/14 slots and PRN 37 students/14 slots; active session still present. Google-rendered ClassSlots dates inspected. Existing narrow backend-sheet column widths retained.
- Data-only update: no deployment/build required. Refresh the app calendar. Past dates remain view-only; today's/future dates follow existing attendance policy. User test email remains authorized only in PRN roster.

## Additional test members — 26/09/2026
User explicitly supplied two test identities and requested membership in every class. Added four nonduplicate rows to Test_PRM392 Roster A128:J131 across both active imported classes; preserved supplied email/roll/member/name exactly and noted test-only membership. Six disabled sample classes left disabled. All written values read back and compared; live workspace API confirms PRM393 31 students and PRN232 39 students, 14 slots each, existing active session preserved. No attendance submission or code/build change. Personal identities remain only in Sheet, not this public state record.

## Windows 1.4.5 and Sheet organization
Built latest main-derived code (4658889) as Windows 1.4.5+20260926; 177 Flutter tests, 35 backend tests, analyzer and architecture passed. Canonical desktop shortcut updated and app launched. This build does not implement proposed roster management/export features. Added Hướng dẫn A1:C37, verified every value and Google-rendered layout. Visible tabs now Hướng dẫn, Classes, Roster, ClassSlots; 16 system/legacy tabs hidden only, no renames/deletes or data changes. Live workspace read confirms PRM31/PRN39 students, 14 lessons each, existing active session preserved. Teacher deployment unchanged at v22.


## Roster management — Windows 1.5.0
Implemented live roster CRUD with soft deactivation/reactivation, template/full-roster XML export, selected-class import diff, optimistic revisions and no automatic POST replay. Shared catalog propagation and student-by-lesson attendance matrix use session roster snapshots. New sessions persist original membership; legacy sessions require explicit baseline acknowledgement and display uncertain absence. Block class roster edits while an attendance session is open/closing. Original new-class import cannot bypass update safeguards for an active existing class.

184 Flutter / 40 backend tests passed; analyzer and architecture clean. Teacher v23 deployed, student v10 unchanged. Final Windows package build/trial-1.5.0-release; canonical shortcut updated. Native real PRN roster (39) observed. User took over app navigation, so no further native input or forced close. Final package removes one redundant workspace request; its widget test/analyzer passed. Hướng dẫn updated and read back. Google ContentService timeout/404 persists intermittently; native manual refresh succeeded in about5.2s. No claim of resolved upstream delivery or live roster-write/Form end-to-end verification.
