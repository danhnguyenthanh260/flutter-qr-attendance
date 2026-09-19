# Task: issue-4-sheets-data

- Workspace: flutter-qr-attendance
- Scope: Implement GitHub issues #4 and #9 as one data/API foundation slice.
- Desired outcome: A testable Google Apps Script data layer and teacher API contract, plus a Flutter HTTP adapter that can replace the existing mock service when a configured endpoint is available.
- Repo: flutter-qr-attendance
- Branch: feat/person-4-issue-4-sheets-data
- Base: main at 5949871096759856547c039fec0b63c284bf91d7
- Status: Apps Script #4 and teacher API #9 source implemented locally. Flutter SDK 3.47.4/Dart 3.13.3 is installed in an isolated Windows tooling directory. Apps Script checks and six deterministic tests, Flutter test (14 tests), Flutter analyze, and `flutter build windows` all passed on 2026-09-19. The Release Windows executable launched and remained responsive for local UI testing.
- Constraints: No live Sheet, Apps Script deployment, teacher credential, Forms configuration, or paid service is authorized/configured in this task.
- Decisions pending: teacher authentication method; schedule source; close/grace policy; roster change and multi-session metric rules; Spreadsheet and deployment configuration.
- Artifacts: implementation-plan.md; repos/flutter-qr-attendance.md
- Completed: Apps Script schema/gateway/repository/API source, local fake-store tests, an opt-in Flutter HTTP adapter, Flutter contract tests, full Flutter test suite, and Flutter static analysis.
- Next: Feature branch is pushed and the local Windows app is running for UI testing. Do not open a PR, merge, or configure/deploy Google services without explicit direction.
