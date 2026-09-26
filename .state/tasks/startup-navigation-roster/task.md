# Startup, navigation and roster preview

- Date: 2026-09-25. User authorized implementation, a configured Windows release and opening it for trial.
- Repo: D:/Coding_learning/flutter-qr-attendance-qr-grants; branch feature/startup-navigation-roster based on main d5c67ce. Existing closing-session source/test WIP explicitly preserved and validated with this build.
- Issues: #48 latency/navigation; #49 local parser/preview portion. No invented timetable/history or live roster import.
- Frontend brief: teacher needs navigation without losing loaded state and access to the supplied roster before attendance. Keep existing Flutter/Material shell, lazy IndexedStack pages, progress near affected data, explicit server verification before opening a session. Add local-only roster preview because current session-results flow cannot display a roster before a session exists. Reuse Material file action, dropdown, search and table; file_selector is native picker, xml parses actual SpreadsheetML, crypto namespaces the local catalog cache and identifies duplicate source files.
- Catalog cache contains class/slot data only, scoped by endpoint/account credentials, never authoritative attendance/session state. Reads of active session remain live; no POST replay after timeout.
- Verification: deterministic Flutter unit/widget tests, backend existing fake-gateway tests and syntax checks, Windows release build; no real student submission.
- Source XLS copies stay local beside trial release; do not commit PII. API configuration remains outside tracked files.

## Delivery receipt
- Configured Windows release 1.1.0+20260925 built and opened from `build/trial-1.1.0-20260925-r2/flutter_qr_attendance.exe`; native file-selector DLL and both source XLS files included locally.
- Analyze clean; 103 Flutter tests passed; backend syntax/check and 16 tests passed. Actual source parser: 29/37 rows, no structural identity errors. Existing closing-session WIP preserved in this source revision; no new Apps Script deployment.
- Final native sample from Dart main: frame 32 ms, classes 2940 ms, slots 5652 ms, session verification 5842 ms. One sample, not full launch benchmark or acceptance of all latency targets.
- History loaded successfully, about 14.9 s for first load of one group/3 sessions; retained after sidebar round trip with no additional read request. This initial fanout remains an optimization target; issue #48 stays open.
- Roster preview remains local only; schedule and attendance history cannot be inferred from roster files. No student submission or session lifecycle mutation used for testing. Issues #48/#49 remain open for full acceptance/scope.
