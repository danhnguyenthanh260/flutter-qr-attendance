# Roster management and historical attendance — 1.5.0

## Delivered behavior

- Class Data reads the current Sheet roster, including inactive membership. Search, add/edit, deactivate/reactivate, empty template export, complete roster export and preview-before-import are available.
- Import uses the selected class and matches MSSV, independently of filename. Omitted students remain unchanged. Original FAP imports remain available as a separate new-class flow. Excel XML exports use String cells, preserve Unicode/IDs, and include optional Active=true/false for round trips.
- Calendar, matrix and both attendance providers receive the shared workspace catalog. Workspace reads replace the in-memory catalog as well as disk snapshots. First opening Class Data reuses an already-loaded workspace; returning to visited tabs retains state.
- Attendance defaults to a student-by-lesson matrix, including historical session slots. Membership and accepted email are resolved against each session's roster. Unopened lessons, nonmembers, pending attendance and legacy uncertainty are separate states.
- New sessions persist roster_snapshot and roster_snapshot_kind=at_open. Result reads, matrix reads and Form processing use this snapshot. Stable roster IDs survive email/name/roll edits; deactivation never physically deletes rows.
- Authenticated class_roster/update_roster endpoints enforce optimistic revision checks, batch validation, unique roll/email (including inactive students), snapshot capacity, and a class-level open/closing-session guard. A validated roster batch uses one setValues operation under the existing script lock.
- A lost update response is reconciled by authenticated readback; the client never automatically replays the POST.

## Legacy history boundary

Pre-upgrade sessions do not contain the original roster. The first roster change requires explicit acknowledgement and freezes the current baseline before changing membership, tagged legacy_baseline. This is not reconstruction of historical truth. The matrix displays ? for unresolved absence; detailed results explain that missing attendance cannot establish absence for these sessions. Existing recorded presence remains visible.

Use the app for roster mutations. Direct manual Sheet edits bypass revision/locking/legacy-baseline safeguards. New-session snapshots still remain independent of later manual edits.

## Verification and delivery

- 184 Flutter tests and 40 backend tests passed; analyzer and architecture gate passed. Added tests cover export/import Unicode and inactive-state round trips, selected-class validation, preview cancellation/confirmation, atomic duplicate rejection, optimistic conflicts, membership freezing, legacy acknowledgement, nonmember rejection, historical email changes and uncertain-response reconciliation without replay.
- Final shared-catalog selection cleanup passed the full 184-test suite before the Windows rebuild. One additional matrix widget test passed at 1024px with 14 lessons; synthetic rendered layout inspected. Final analyzer/architecture gate passed.
- Windows release: 1.5.0+20260926. Final package: build/trial-1.5.0-release. Canonical existing QR Attendance.lnk targets that executable; no additional desktop shortcut. Final data/app.so SHA256: C6DF73A8BE27890976FA6ACA6A91F70B3C56F63B6DBB52B94D5B60B3A9EBC25D.
- Teacher deployment updated from v22 to v23 after verifying remote HEAD matched v22. Legacy student deployment stays v10. Snapshot columns are added lazily by the backend; existing sessions/attendance are not rewritten on deployment.
- Native initial 1.5.0 package displayed the real 39-student PRN roster and management controls. The user then took over navigation; no further native input, window termination or attendance mutation was performed. Final package also eliminates the redundant workspace request before first roster loading and clears a selected lesson when its class leaves the shared catalog.
- Google ContentService remains intermittent: first native workspace read timed out after 25 seconds; the redirect later returned HTML 404. Manual refresh succeeded (Apps Script 4.579 s + content delivery 0.576 s). A subsequent workspace read took 4.115 s; roster read succeeded but took about 16 s. Do not claim this release eliminates upstream latency/404s.
- Live roster edits and live student Form submissions were not used as QA. Writes were exercised on isolated test fixtures. Current class membership and user-controlled attendance sessions were left intact.
- Updated Hướng dẫn B:C rows 2,9,11,12,16,22,25,37 in the existing workbook, read back all 16 values, and visually checked the revised operation/import instructions. No sheet renames, deletions or sharing changes.
