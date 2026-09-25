# Architecture and UI/UX direction
- User asks to improve rough architecture and UI/UX.
- Read current AppShell, providers, theme/tokens and existing screen inventory; use harness frontend-experience-research.
- Concrete proposal: docs/ui-architecture-brief.md, including layout sketch, data gaps, component inventory, staged refactor and acceptance.
- User approved research direction. No application source changed in this phase.
- Existing QR acceptance remains separately pending a test account; do not equate visual redesign with completion of that flow.
- User approved research direction and named download (1).jpg as visual inspiration. Read actual local image; researched official Canvas, Moodle and Google Classroom documentation.
- Findings and remapping: docs/design/system-research.md. Generated and visually reviewed lecturer-retro-concept-v1.png plus original roster-empty illustration, copied into workspace. Concept deficiencies documented before code translation. No real student data in generated images.
- Current phase complete: research + visual exploration. Implementation source and running 1.1.1 release unchanged in this phase.
- Technical follow-up: docs/design/implementation-contract.md records verified dependencies, Material Icons decision, feature-first MVVM/Provider boundaries, component/state ownership, proposed lint/CI gates, and staged migration. These gates and refactors are not yet implemented.

## Implementation 1.2.0
- User authorized implementation after the technical contract.
- Feature-owned presentation/state, injected AttendanceRepository contract, extracted CatalogRepository and QrController, local roster view model, Material theme/icons and shared navigation/notice components implemented.
- Removed unused Cupertino icon dependency, unimplemented AI destination, fabricated admin identity/developer badges and hardcoded UI version. Generated illustration is intentionally not bundled.
- Local gates: strict analyze passed; 118 Flutter tests passed; 17 backend tests and syntax checks passed; import-boundary gate passed.
- Rendered gallery and production screens with synthetic fixtures, actual Segoe UI/Material font. Layout checks at 1024/1280/1366/1920 widths and 100/150% text scale passed. Native release verification pending packaging below.
- Earlier QR Form-to-Sheet acceptance remains separate; this refactor does not claim a new accepted live submission.

- Final native verification complete: trial-1.2.0-ui launched, restored existing session and displayed rotating server QR; corrected QR centering verified on the native window. Tab/Enter activated the return action. Prior 1.1.1 process closed without closing the server session.
- Final executable version 1.2.0+20260925, SHA256 4C59B7B4073DF5CCDDDFF3F8C37C545B700B5660B3BB956B8461026CF79F7EAD.
- Evidence: docs/design/verification-1.2.0.md. Trial is local; CI workflow configured, no remote CI execution claimed. Full source gate rerun after alignment fix: analyze clean, 118 Flutter tests, configured release built.
