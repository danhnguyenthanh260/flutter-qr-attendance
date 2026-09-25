# UI engineering implementation contract

Status: implementation delivered locally for Windows 1.2.0, 2026-09-25. See `verification-1.2.0.md` for evidence and limits.

## Implemented architecture

- `app/app_shell.dart` composes the workspace and retains visited tabs. `app/widgets/workspace_navigation.dart` owns responsive navigation; the inactive AI placeholder is no longer a primary destination.
- `core/theme/` owns Material theme and semantic icon constants. Existing `core/constants/` contains shared color/type tokens. A ThemeExtension was unnecessary for these static tokens; no duplicate token system was added.
- `features/teaching`, `features/attendance`, `features/qr`, `features/roster_import` own their screens and state. Provider view models require constructor injection of `AttendanceRepository`; concrete backend selection remains at bootstrap.
- `data/repositories/attendance_repository.dart` is the typed contract. `CatalogRepository` owns typed memory/disk catalog cache, TTL and in-flight coalescing. The Google Apps Script adapter retains HTTP/envelope/request-ID behavior for compatibility; no pass-through repository per endpoint was added.
- `QrController` owns clock, timer, phases, prefetch, expiry, request exclusion and late-response guards. QR selectors separate countdown/error text from the QR painter and from the rest of the workspace.
- `RosterImportViewModel` owns local file selection/import/filter state; it does not publish roster data to Sheets. Native file access can move behind its own adapter if another source is added.
- `dev/component_gallery.dart` is a separate development entrypoint. Generated raster illustrations remain design artifacts and are not bundled in the release.
- Strict analyzer options, async/disposal lints, architecture import validation and GitHub Actions are configured. CI remote execution is not implied by local gate results.

## Original implementation specification

The sections below preserve the agreed design intent. The verified baseline describes the code before this refactor.

## Verified baseline

- Flutter Material 3, Provider/ChangeNotifier, http, qr_flutter. Material Icons are already available through uses-material-design. No CupertinoIcons references in lib/test; Cupertino localization does not require the cupertino_icons package.
- Session selection 584 lines, history 518, QR display 504, AppShell 368. File length is a navigation warning, not itself a reason to split unrelated abstractions.
- analysis_options.yaml includes flutter_lints but adds no project rules. No .github directory/Actions pipeline. Apps Script has syntax checks and Node tests, no ESLint configuration.
- Preserve lazy IndexedStack navigation, visibility-controlled attendance polling, catalog cache/read deduplication, and QR request identity/expiry/recovery behavior.

## Decisions

1. Keep Flutter Material Icons. Central const AppIcons exposes semantic names using static Icons constants; outlined icons by default, filled selected navigation where available. Sizes 20/24, accessible labels/tooltips, minimum 48 logical-pixel action targets. Do not use generated raster icons or dynamic codepoints. Remove unused cupertino_icons during implementation after analyze/build verification.
2. Keep Provider, ChangeNotifier and constructor injection. Use feature-first MVVM with repositories as the shared source of truth; services perform transport/storage. No simultaneous migration to another state library or generic use-case layer.
3. Keep business widgets within their feature. Promote a widget to shared UI only when its semantics are generic and actual reuse exists. Leaf components take immutable values and callbacks; they do not fetch HTTP, open files, or locate providers.
4. Build a ThemeData/ColorScheme/TextTheme and small ThemeExtension for spacing/status tokens. Prefer themed Material controls over wrappers for every widget. Use const constructors and Selector for narrow updates. QR countdown must not rebuild the roster or shell.

## Target layout and ownership

```text
lib/
  app/                 # bootstrap, dependency composition, shell/navigation
  core/
    theme/             # theme, typography, spacing, semantic colors, AppIcons
    ui/                # shared async state, status badge, page header
    network/           # HTTP envelope, timeout, typed error mapping
    storage/           # catalog/session persistence adapters
  data/
    models/            # shared class/session/attendance models; retain stable models first
    repositories/      # catalog, session, attendance; cache and request coordination
    services/          # Apps Script calls, parsing and storage integration
  features/
    teaching/          # class/slot selection screen, view model, feature widgets
    qr/                # presentation screen, lifecycle controller, timer/status widgets
    attendance/        # today/history screens, view models, table/filter/summary widgets
    roster_import/     # local import screen, view model, preview/validation widgets
test/                  # mirror feature/data boundaries, shared fixtures
```

Dependency direction: screen → view model/controller → repository → service/storage. Repositories never import presentation or Provider. Core must not import features. Features communicate through shared typed models/repositories, not each other's screen internals. Avoid introducing separate DTO/domain copies until an actual contract difference warrants mapping.

| Scope | Components | State owner |
|---|---|---|
| App | shell, navigation, connection indicator | composition root; shared repositories/session |
| Shared UI | page header, loading/empty/error content, status badge | values supplied by caller |
| Teaching | class selector, slot picker, session summary/actions | teaching view model |
| QR | QR canvas, countdown, recovery notice, close action | dedicated QR controller |
| Attendance | roster table/row, summary, filters, history date grouping | attendance view models; local filters |
| Import | file picker action, validation summary, preview table | import view model; never server roster by implication |

## State and lifecycle contracts

- Initial load, ready, refresh-in-progress, empty, and recoverable error are explicit data states. Retain visible data during refresh and show its freshness; never display cached attendance as a confirmed new write.
- Separate session lifecycle (idle/opening/active/closing/unconfirmed) from QR lifecycle (issuing/valid/refreshing/expired/recovering). Valid ticket can remain visible while next ticket is issuing, only until server-derived expiry. Keep epoch/in-flight guards and stable request IDs across unknown outcomes.
- Controller uses injectable clock/scheduler for tests. Presentation never generates tickets from build(). Hide/dispose and session-close transitions cancel appropriate timers and ignore stale responses.
- Catalog can use existing TTL cache; switching tabs must not reload an unchanged catalog. Attendance refresh follows visibility and freshness policy; manual refresh remains available.
- Do not invent schedule, roster, permissions, counters, or attendance results from screenshots. Class roster/schedule integration is a separate API contract task. Remove developer-name badges; identity/role must be verified or omitted. Version label must come from build metadata rather than a hardcoded string.

## Quality gates

Keep flutter_lints and stage additional analyzer/linter rules against the installed SDK: strict-casts, strict-inference, strict-raw-types; async/disposal checks such as unawaited_futures, discarded_futures, cancel_subscriptions and close_sinks; avoid_print and directives_ordering. Check which rules already come from flutter_lints before adding duplicates. Resolve findings rather than globally suppressing them. These settings are now enabled except discarded_futures, which remains deferred; see analysis_options.yaml.

PR pipeline to implement:

1. `dart format --output=none --set-exit-if-changed lib test`
2. `flutter analyze --fatal-infos`
3. `flutter test` with meaningful regression coverage for tab retention, refresh races, QR expiry/retry/close, and roster states.
4. Apps Script `npm run check` and `npm test`; add ESLint with explicit Apps Script globals as a scoped follow-up.
5. Windows release compilation on a Windows runner, with build-time configuration policy that does not require committing teacher credentials. An unconfigured compilation is not a live API acceptance test.
6. Lightweight import-boundary validation and review: analyzer alone does not enforce the layer dependency rules above.

Use a dev-only component gallery with typed synthetic fixtures for loading, error, empty, long names, and large rosters. Add targeted widget/golden checks for composed screens where useful, not snapshots for every button. Verify keyboard/focus/tooltips, 1024×768 through 1920×1080, and 125/150% text scaling. Record cold/warm startup, tab navigation and API timings separately; do not claim a fixed network latency from UI refactoring.

## Migration order

1. Establish theme/icons and component gallery; add formatting/analyze/test CI baseline without changing QR behavior.
2. Extract presentation widgets and rebuild shell/teaching layout; preserve navigation state and visibility polling.
3. Extract QR lifecycle controller with regression tests; incrementally move transport/cache coordination behind repositories. Keep existing service adapters until callers are migrated.
4. Refine attendance/import screens, verify accessibility and performance, then build a configured Windows trial. Live QR → Form → Sheet acceptance remains a separate test requiring the authorized test identity.

## Primary references

- https://docs.flutter.dev/app-architecture/guide
- https://docs.flutter.dev/app-architecture/recommendations
- https://api.flutter.dev/flutter/material/Icons-class.html
- https://dart.dev/tools/analysis
- https://dart.dev/tools/linter-rules
