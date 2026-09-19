# Implementation Plan

## Gate receipt

- Matched gate: implementation-planning. The approved task changes a shared data/API foundation across Flutter and Google Apps Script.
- Owner: flutter-qr-attendance, branch feat/person-4-issue-4-sheets-data.
- First artifacts: this plan and durable task state.
- Prohibited before verified local implementation: production data writes, Apps Script deployment, secret/configuration commits, PR, merge, or close of GitHub issues. The user has subsequently authorized a feature-branch push after local verification.

## Objective

Implement the #4 Sheets data layer and #9 teacher API contract without relying on real attendance data. Keep raw Form responses separate from valid attendance, normalize email identity, make retried writes idempotent, and expose typed response/error semantics to Flutter.

## Scope

- In scope: versioned Apps Script source, schema/config validation, data repositories, safe in-process fake store tests, web-app request routing, Flutter HTTP adapter and contract tests.
- Out of scope: configuring a live Sheet/Form, deploying Apps Script, choosing a final teacher identity provider, granting a user access, AI integration, student form submit processing, or changing other team-owned UI modules.

## Evidence and assumptions

- Confirmed: Flutter currently uses MockAttendanceService and has no Apps Script source or deployed endpoint.
- Confirmed: #4 is the only unblocked remaining issue; #9 depends on #4.
- Assumption for local code only: teacher API requests include a configured shared teacher key checked by Apps Script Script Properties. Missing configuration must fail closed.
- Decisions required for deployment: teacher authentication, schedule source, grace/close behavior, roster versioning rules, target spreadsheet/form/deployment identifiers.

## File manifest

- expected - resolve before edit: apps_script/appsscript.json, apps_script/src/*.gs, apps_script/test/*.js.
- confirmed: lib/data/services/attendance_service.dart.
- expected - resolve before edit: lib/data/services/google_apps_script_attendance_service.dart and its Flutter tests.

## Step order

1. Define JSON envelopes, error codes, sheet headers, and immutable IDs. Exit: contract covers class, slot, session, roster, raw response, attendance, attempt, and ticket state.
2. Implement Apps Script repositories and web API with explicit config/auth failure behavior. Exit: fake-store tests prove email normalization, idempotent writes, missing-roster errors, and authorization boundaries.
3. Implement a Flutter HTTP adapter behind AttendanceService. Exit: request/response mapping and non-2xx/error envelopes are unit tested.
4. Run focused tests, flutter test, and flutter analyze. Exit: completed on 2026-09-19: Apps Script check/test (6 tests), Flutter test (14 tests), and Flutter analyze (no issues). Windows build was attempted but is blocked by missing Visual Studio C++ components; live runtime verification remains explicitly pending.

## Data and API safety

- Use a canonical lowercase/trimmed email_key; never use display email as a uniqueness key.
- Store raw FormResponses independently from accepted Attendance records.
- Enforce one attendance per session_id plus email_key and one processing result per form_response_id.
- Use Apps Script locking around mutations and return deterministic conflict/validation errors.
- Require configured teacher authentication; do not use a default key or accept anonymous mutation requests.
- Read/write only the configured spreadsheet. Do not create or select a spreadsheet automatically.

## Validation plan

- Safe local JS tests for Apps Script domain logic using a fake sheet gateway.
- Safe Flutter unit tests with a fake HTTP client/server adapter.
- Repo-native Flutter test and analyze commands after dependency installation.
- No deployed Apps Script, Google Sheets, Google Forms, or live attendance test without separate configuration/approval.

## Rollback plan

- All changes stay on the feature branch until review.
- Revert the feature commits or delete the unmerged branch if the contract is rejected.
- No external data mutation or deployment is planned, so no operational rollback is required.

## Stop conditions

- Stop before any live Google mutation if the spreadsheet ID, deployment URL, or teacher auth choice is not explicitly provided.
- Stop if current source structure conflicts with the contract or another branch appears remotely.
- Stop if a test requires real credentials or cannot isolate its storage.
