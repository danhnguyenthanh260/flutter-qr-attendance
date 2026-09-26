# Source data and performance documentation update

- Date: 2026-09-25.
- User scope: correct the performance assessment to include observed >=30s startup and repeated loading during navigation; update issues and authoritative project documentation from new sources.
- Repo: danhnguyenthanh260/flutter-qr-attendance. Base main 842e29d; isolated branch feature/source-data-performance-docs in D:/Coding_learning/flutter-qr-attendance-docs-audit.
- Deliverables: README index; docs/source-data-and-scope.md; docs/contracts.md; docs/ai-reporting-requirements.md; docs/performance-and-navigation.md; evidence-based issue-body updates and two scoped follow-up issues.
- Original working clone closing-session WIP remains untouched. No application code, deployment, Form, Sheet, attendance or AI-provider calls changed.
- Repository live visibility is public. Raw roster/CSV/images containing student data remain local. Source copies and SHA-256 manifest are in original working clone .dart_tool/source-intake-2026-09-25; originals remain in user Downloads.
- Original/updated issue bodies and metadata snapshots are local in original clone .dart_tool/issue-update-2026-09-25; re-read before each write and verify body/metadata after it. Preserve existing issue states, owners, labels and project status.
- Validation: documentation diff/links/source facts; no source tests required for documentation-only changes. Native UI startup has not been timed by this update; >=30s is explicitly user-reported.

## Delivery receipt

- Published documentation commit 6f4ec33 to origin/main and read back README plus all four documents from GitHub: content matched local sources.
- Updated bodies for #3, #6, #7, #8, #9, #16, #17, #18, #19, #24; readback matched after CRLF normalization. Original title/state/labels/assignees/milestone/project membership and status preserved. Existing incomplete checkboxes were not marked complete.
- Created #48 (startup/navigation latency) and #49 (roster intake and timetable specification). Both added to project 4 with Todo/P1; primary role person 1 and person 4 respectively. Ready means investigation/parser/preview can start, not authorization for live import or proof that missing schedule data exists.
- No milestones exist in the repository; no individual assignee invented. Existing project metadata can still be stale: this update does not claim a full board reconciliation or completed feature acceptance.
- Synced documentation into original main checkout while preserving pre-existing source/test WIP and local audit state.
