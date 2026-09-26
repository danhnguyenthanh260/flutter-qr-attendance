# Weekly roster implementation — 2026-09-26

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
