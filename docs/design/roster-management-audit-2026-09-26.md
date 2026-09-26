# Attendance and class-data workflow audit

Implementation follow-up: delivered in 1.5.0; see [verification-1.5.0.md](verification-1.5.0.md). The findings below describe the pre-change state.

Scope: source inspection of current main-derived checkout after user requested review of Attendance and Class Data tabs, export templates, and student maintenance. This is an implementation brief, not a claim these features shipped.

## Verified gaps

- Class Data renders RosterPreviewView: local/bundled XML SpreadsheetML file preview with initial import. It does not fetch the current class roster for management. Users can therefore see original file contents instead of subsequent Sheet additions.
- The picker accepts xls/xml and the parser requires SpreadsheetML. Import destination is inferred from a strict original filename pattern. No sample download, roster export, per-student add/edit/deactivate/reactivate, or import-difference review is exposed.
- Backend importRoster rejects existing roster differences (including additional test members absent from the original file). This protects against accidental replacement but is not an update workflow.
- Attendance retains separate today/history providers. Both populate their class lists at initialization through the cached catalog; normal result/history refresh does not refresh those lists. The calendar's workspace refresh does not propagate class selection/catalog revisions into these providers.
- History is a session browser, not the student-by-lesson matrix shown in the user's reference. A planned lesson without a session must not be presented as an absence.
- getSessionResults returns getRoster(session.class_id), which filters current active membership. Adding, removing, or changing an email can alter historical display/counts. Soft deletion alone does not solve this: historical membership must be preserved explicitly.

## Required integrated implementation

1. Shared class catalog/revision invalidation across calendar, attendance and class management. Preserve selection by class ID where valid; clear deleted/hidden selections. Explicit refresh must refresh catalog and relevant data, without reloading all tabs on every navigation.
2. Class Data defaults to live classes and live roster, with source/last-updated status, search, active/inactive filter and counts. Local file preview becomes an import workflow, not the primary data source.
3. Download a documented editable template and export current roster in the same round-trip format, preserving Unicode and string student IDs. Select class/course/term explicitly, not solely by filename. Validate required headers, email, duplicate roll numbers and email conflicts; escape spreadsheet formula content.
4. Add/edit student dialog with stable identity; deactivate membership instead of hard deleting attendance-linked records; show inactive members and allow reactivation. Clearly explain the effect of email changes on future Form matching.
5. Import preview categorizes unchanged/add/update/conflict records. Omitted rows do not silently remove students; bulk deactivation is a separate explicit confirmed operation. Require server revision checking, lock-protected writes and response-loss reconciliation before reporting success.
6. Preserve session roster identity before mutable roster management is enabled. Define a transparent migration/fallback for existing sessions, whose original membership cannot be inferred with certainty from current roster alone. Do not fabricate historical enrollment. Decide and display how changes affect an already-open session; protect in-flight Forms and finalized records.
7. Attendance uses the same class/lesson identities as the calendar, provides student-by-lesson P/A/pending/not-opened matrix and retains per-session detail. Export includes class/course/date/slot and distinguishes planned, open, closing and finalized states. Absence denominators include only eligible finalized lessons.

## Acceptance

- Add/edit/deactivate/reactivate one fixture student; all three tabs converge after successful save/refresh without restart or duplicate students.
- Export then import preserves identities and Vietnamese names; missing/duplicate columns or conflicting emails block writes with row-specific feedback.
- Concurrent changes and timeout after server commit cannot silently overwrite data or duplicate operations.
- Previously finalized session results remain unchanged after roster maintenance; students newly added to a class are not marked absent for lessons before membership.
- Past/current/future planned slots and two imported classes render consistently; planned or future lessons do not count as absences.
- Verify native Windows UI and live read-only class/roster results after build. Use isolated fixtures for destructive or identity-changing tests; preserve the user's current test session and student records.
