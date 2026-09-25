# QR recovery and live Sheet verification

- User authorized implementing QR recovery and testing against the existing test Sheet.
- Working clone: flutter-qr-attendance-qr-grants; branch feature/startup-navigation-roster.
- Direct connector read of Test_PRM392: Sessions has 3 records, 1 active; Attendance header only; FormResponses has 2 submissions rejected as email_not_in_roster. No successful live attendance established by those submissions.
- Preserve existing Form/Sheet and existing session. Await user-selected Google test email for a successful Form submission; meanwhile verify issuance/replay/expiry and test domain lifecycle with synthetic fixtures.
- Changes in progress: idempotent QR request IDs without schema migration, remove duplicate ticket scan, automatic bounded recovery after timeout, wall-clock expiry and prefetch, mutation timing logs.

## Verification and release
- Teacher deployment updated in place: v12 -> v13 -> v14, same URL, existing Form/Sheet/properties preserved. Remote manifest's existing webapp settings copied into source; no access expansion. Student claim deployment remains v10.
- 106 Flutter tests passed, analyze clean, backend syntax check and 17 tests passed. Includes retry after unknown mutation outcome, no overlapping QR calls, closing guards, same-ID one-ticket replay with unchanged expiry, and server-relative expiry under local clock skew.
- Live v14 probe: issue/replay/next successful, same ticket and expiry on replay; generation advances once for a new request. Direct Sheet read verified two appended tickets for three calls. Probe issuance round trips about 5.1/4.2/11.2 seconds. A separate probe encountered ContentService redirects ending in invalid_response; intermittent Google transport behavior remains, do not claim eliminated.
- Native release 1.1.1+20260926 opened at `build/trial-1.1.1-qr-recovery/flutter_qr_attendance.exe`. QR rotation observed over multiple cycles; logs show about 4.4-12.0 seconds per issue request in observed cycles. API timing includes mutation requests without keys/URLs/student data.
- Clock-skew finding: old model displayed >30 remaining seconds for a 30-second ticket. New response includes server_time; client subtracts full request elapsed time conservatively and clamps displayed lifetime. Server remains authority for claim acceptance.
- Chrome test: expired QR displayed `QR ticket has expired`; valid QR opened existing Test_PRM392 Google Form with prefilled grant. Direct Grants read verified one added grant with 120-second grace. No Form submitted in this turn.
- Live end-to-end accepted attendance remains pending user-selected Google test email: current signed-in account is absent from all 60 roster rows (10 in CLASS_001). Two old FormResponses show email_not_in_roster, Attendance empty. Do not add a real student or claim successful attendance without that step.
