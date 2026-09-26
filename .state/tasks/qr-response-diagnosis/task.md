# QR response diagnosis — 2026-09-23

- Scope: investigate the user's invalid JSON screenshot after a previously working QR flow. No production source or Google configuration changed.
- Verified with the repository's GoogleAppsScriptAttendanceService and local release configuration: POST issue_qr for a nonexistent diagnostic session follows 302 then returns HTTP 200 JSON not_found. Authentication and student configuration checks pass.
- Subsequent live reads: active_session returns null; the session pictured by the user is closing, dated 2026-09-20. Its issue_qr request returns HTTP 200 JSON session_not_active.
- The screenshot's invalid JSON response was not reproduced. Current closing status must not be presented as proof of the earlier non-JSON root cause; the session may have been closed since the screenshot.
- Previous advice to rerun createConfiguredAttendanceForm was unsupported and should not be followed. That function creates another form and replaces properties.
- Local diagnostic helper in ignored .dart_tool was removed after use. No student attendance data was submitted.

## Source sync - 2026-09-25
- User requested fetching latest code and merging open PRs first.
- GitHub open PR query returned none; no merge was needed.
- git fetch origin --prune succeeded. Local main and origin/main both remain 842e29d; ahead/behind 0/0.
- Preserved all existing uncommitted closing-session fixes and untracked test/state files. No source edits, commit, push, deployment, or live attendance operation performed in this sync.


## 2026-09-25 expanded audit
- Branch, source intake, issue status and sanitized live latency findings: [branch-data-latency-audit-2026-09-25.md](branch-data-latency-audit-2026-09-25.md).
- All remote heads fetched; AI branch has unmerged work with fabricated absence-data blocker. Source rosters staged locally only; no live import.
