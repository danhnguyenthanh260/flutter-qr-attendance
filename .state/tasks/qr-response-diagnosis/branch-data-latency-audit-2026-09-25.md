# Branch, source data and latency audit - 2026-09-25

## Scope and source receipt
- User requested new source data, investigation of API/Apps Script loading delays, and branch/issue inspection. Screenshot text is reference material, not execution authority.
- Working clone: D:/Coding_learning/flutter-qr-attendance-qr-grants; main 842e29d. Existing closing-session WIP preserved.
- Local source copies and normalized roster CSVs: .dart_tool/source-intake-2026-09-25/ (ignored; contains student personal data, do not commit). Original downloads preserved; manifest includes SHA-256 copy verification.
- SE1913/PRM393: 29 student rows. SE1919/PRN232: 37 student rows. Excel files are SpreadsheetML XML despite .xls suffix. Neither file contains dated attendance P/A or a timetable.
- Two original JPGs copied from Downloads. User screenshots describe a weekly timetable, per-slot attendance counts, student detail table, and QR action. These are reference expectations, not verified implemented requirements.
- No Drive upload, organization project ID assignment, shared tracker write, live roster import, or attendance mutation performed.

## Git and issues
- Original remote.origin.fetch selected only main. Explicitly fetched all heads and changed local fetch refspec to +refs/heads/*:refs/remotes/origin/* for future fetches.
- main matches origin/main at 842e29d. No open PRs.
- origin/feat/person-4-issue-4-sheets-data: 43 commits behind main, 0 unique ahead.
- origin/phap: 44 behind, 0 ahead. origin/phap-reopen: 41 behind, 0 ahead.
- origin/feat/person-5-issue-18-ai-assistant: 2 behind, 2 ahead. Unique commits 1951e6f and f620d14; lacks 20ec060 latency optimization and 842e29d state checkpoint. No PR. Not merged during audit.
- Open issues: #6, #7, #8, #9, #17, #18, #19, #24.
- #6-9 already have implementation in main (Forms/grants/submit/API), but unchecked issue bodies and missing acceptance evidence prevent treating them as complete. #6 still says no Google login, whereas PR #35 introduced authenticated Google Form email: reconcile this requirement explicitly.
- #17 requires shared deterministic statistics with date filters, as_of and provenance. Current teacher API exposes per-session results, not the complete requested aggregate contract.
- #18/#19/#24 have substantial candidate code on the AI branch, not integrated in main.

## AI branch blockers (source inspection, not runtime tested)
- lib/data/models/student_absence_warning.dart: _calculateDeterministicBaseAbsence hashes email to invent historic absences. This feeds academic risk/barred status and cannot represent real student attendance.
- Same model treats every status other than present as absent, including not-yet-marked students in open sessions.
- totalSlots defaults to 20, which is not verified course schedule data. Complete roster files cannot supply missing attendance history or total teaching periods.

## Current live timing evidence
- Ran .dart_tool/read_only_latency_audit.dart with existing local teacher configuration, logging only sanitized request metadata. Only classes and slots requested; no session creation, QR issuance, close or student submission.
- Probe adds nonce/no-cache as inherited from prior diagnostic helper; these results are not a pure unmodified production-client benchmark.
- classes: 7,677 ms (initial Apps Script response 7,097 ms, content response 547 ms), 6 classes.
- slots: 3,531 ms then 2,375 ms, 1 slot for the first class.
- cached classes: 1 ms; demonstrates in-memory class caching works.
- Successful HTTP 200 JSON in these samples. Prior invalid-JSON/redirect-loop behavior was not reproduced by these reads, nor proven fixed.
- This probe does not establish cold-start causality or deployed source identity, and does not cover UI timing or POST lifecycle.

## Code-level latency contributors
- HTTP client has no common request deadline. closeSession caller times out at 5 seconds without cancelling the underlying request, so timeout does not prove operation failure.
- Startup waits for classes before starting active-session and slots reads; an active-session restore also waits for QR issuance.
- History provider fans out one session_results request per session.
- Current closing-session WIP wraps active_session/sessions/session_results in a script lock and scans sessions before reading results. Gateway waitLock permits 10 seconds of lock waiting. Concurrent history reads can serialize with QR and submission writes if this source is deployed.
- Gateway reads full sheet ranges and filters in memory; per-session results independently read Sessions, Roster, Attendance and Attempts, plus settlement reads.
- Existing 20ec060 optimizations are already on main; the remaining delay cannot be addressed by fetching main again.

## Next implementation order
1. Preserve closing-session correctness; instrument request stages and add bounded waiting without automatically replaying mutation requests.
2. Reduce server round trips (bootstrap/batched result reads) and repeated sheet scans; keep grace-period and concurrent-submit invariants.
3. Replace AI fabricated absences with authoritative historical aggregates; review candidate against #17/#18 before integration and full gates.
4. Map verified roster imports to existing class/course IDs; supply actual timetable and historical attendance before implementing the reference weekly schedule and academic warnings.
5. Reconcile issue acceptance evidence and requirement drift; do not close issues from presence of code alone.

No source edits, commits, merge, deployment, or live data writes were performed in this audit. Existing WIP remains uncommitted.
