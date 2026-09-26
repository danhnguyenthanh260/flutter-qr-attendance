# Direct Google Form QR — 2026-09-25

## Approved behavior

The displayed QR opens the existing Google Form directly, bypassing the Apps Script HTML claim page. Google sign-in may still be required by the existing verified-email Form settings.

The display rotates every 30 seconds. Each code permits submission for **120 seconds from issuance**, inclusive, using the timestamp supplied by Google Forms. This replaces the scan-time claim deadline for newly issued direct codes: Forms does not report when a student scanned or opened the link.

Each displayed ticket has a shared server-issued authorization in Grants (`status: direct`, token `FORM_<ticket_id>`). It is not consumed by the first student. Verified respondent email, roster membership, session/email deduplication and Form response replay protection still apply. Existing single-use claim/grant submissions remain supported. No Sheet header changes are required.

Closing waits for outstanding direct authorizations. A valid submission may be processed after finalization if Google delays its trigger; its original submission timestamp determines eligibility. Results can therefore update after closing. Forwarding a valid QR remains possible; this does not prove physical presence.

## Deployment and verification

- Teacher web app updated from v14 to **v15**, preserving its URL and access settings. Project HEAD and v15 source both read back equal to the 10 local Apps Script files.
- Legacy student deployment remains v10 with signed-in access. Existing Form and Sheet are retained.
- 24 Node tests pass; Apps Script syntax checks and whitespace checks pass. Coverage includes shared codes, duplicate/replay handling, expiry boundaries, late triggers, interrupted writes, rejected identities and legacy grants.
- Live teacher API check found no active session. No new attendance session or Form response was created by this verification. Direct Form opening on the user's phone and an accepted real roster submission remain to be verified.
- Existing Windows 1.2.0 reads the returned `form_url`; no Flutter rebuild is required. Open a session and scan a newly generated QR. An already opened legacy claim link does not change retroactively.

## Rollback

Do not revert all backend code to v14 while direct authorizations or delayed responses exist: the old processor/finalizer does not support them. Disable new direct issuance with `directForm: false` while retaining the new submission processor and closing logic, then publish that compatible version. Preserve the current Form, Sheet and legacy deployment.
