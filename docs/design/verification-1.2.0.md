# Windows 1.2.0 — implementation verification

Date: 2026-09-25. Branch: `feature/startup-navigation-roster`.

## Delivered

- Feature-first presentation folders with required constructor injection of the shared `AttendanceRepository` contract.
- `CatalogRepository` separates typed TTL/disk cache and concurrent-read coalescing from the Apps Script adapter. Existing request identity, HTTP handling and backend schema are retained.
- `QrController` separates rotation, server-derived expiry, recovery and late-response guards from class/session selection. A failed prefetch keeps an existing unexpired QR; expiry still hides it. Countdown selectors do not rebuild the QR painter, selection screen or shell.
- `RosterImportViewModel` separates local import state from rendering. Local roster sources remain local previews, not live Sheet imports.
- Warm neutral/teal Material theme, semantic navigation icons, responsive compact navigation, wrapping actions and class-slot controls. Removed unused Cupertino icons, developer labels, fabricated admin identity and inactive AI navigation.
- Strict analyzer settings and async/disposal lint rules; import-boundary check; GitHub Actions for format/analyze/tests/backend checks/Windows compilation. Workflow configured locally; no remote CI result claimed.

## Local evidence

| Check | Result |
|---|---|
| Dart format, lib/test/tool | Pass |
| Flutter analyze --fatal-infos | Pass |
| Architecture import check | Pass |
| Flutter test | 118 passed |
| Apps Script syntax checks | Pass |
| Apps Script Node tests | 17 passed |
| Configured Windows release | Built 1.2.0+20260925 |

Visual fixtures are synthetic. Rendered the interactive component gallery with actual Segoe UI and Material icon fonts, switched empty/error/loading states and exercised retry. Rendered teaching and QR views at 1024×768, 1280×720, 1366×768 and 1920×1080, both 100% and 150% text scaling; tests found no layout exceptions. Captures are local under `build/ui-review/`, not committed screenshots of user data.

Native Windows verification: restored the existing server session, opened the attendance tab, returned without catalog reload, displayed a real rotating QR, and used Tab/Enter to activate the return action. The attendance tab correctly reported no session on its selected day; the restored session is from a different day. No new attendance submission or session-close operation was performed. A native QR alignment discrepancy was corrected after initial review; the final configured build was reopened and its centered QR verified on Windows.

One observed launch (diagnostics PID 25848, before the final alignment-only correction): first frame 66 ms; classes ready 2,950 ms; slots ready 6,160 ms; active session verified 6,660 ms. First QR issue round trip was 10,558 ms, completing at 17,218 ms after launch. These are one-run observations, not a benchmark or a guaranteed latency. Apps Script latency remains an external bottleneck.

## Trial and limits

Local trial directory: `build/trial-1.2.0-ui/`. Launch `flutter_qr_attendance.exe` from that directory with its accompanying DLLs/data. Existing roster source files are copied locally from the previous trial, never committed. Build configuration remains in ignored `.dart_tool/trial-build-defines.json`.

Live QR → Google Form → accepted Sheet row remains a separate acceptance step requiring the authorized test account. The UI refactor and local tests do not prove a new accepted live submission. Generated artwork remains research material and is not loaded into the runtime. The backend adapter retains its established implementation; no redundant per-endpoint repository wrappers or state-library migration were introduced.

## Reproduce

```text
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos
dart run tool/check_architecture.dart
flutter test
cd apps_script
npm run check
npm test
```

For optional local screenshot capture, run `flutter test test/workspace_layout_test.dart test/component_gallery_test.dart --dart-define=CAPTURE_UI=true --dart-define=UI_ICON_FONT=<Flutter SDK>/bin/cache/artifacts/material_fonts/materialicons-regular.otf`. Set `UI_TEXT_FONT` to a local Segoe UI font when not using the Windows default. Normal CI tests do not depend on these font paths.

Final trial executable SHA256: `4C59B7B4073DF5CCDDDFF3F8C37C545B700B5660B3BB956B8461026CF79F7EAD`.
