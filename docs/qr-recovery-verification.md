# QR recovery verification — 2026-09-25

The 1.1.1 trial fixes a desktop recovery dead end: a failed QR request previously set offline and stopped all timer work. It now retries after five timer ticks, prevents overlapping calls, prefetches near expiry, hides expired tickets and uses readable error text. Teacher API v14 accepts a random `request_id`; retries of the same request return the persisted ticket without extending its expiry. One TicketStates scan replaces two, and buffered writes are flushed before releasing the script lock. Existing session/claim/grace rules remain enforced.

QR responses include `server_time`. The desktop derives a conservative local expiry by subtracting full request elapsed time from the remaining server lifetime. This addresses an observed clock skew that previously showed more than 30 seconds remaining for a 30-second ticket. Diagnostics log action, duration and error code, without QR payloads or credentials.

## Evidence

- Analyze clean; 106 Flutter and 17 backend tests passed. Tests cover replay, expiry, clock skew, automatic recovery, overlapping calls, close/late-response guards and domain submission/deduplication/grace behavior.
- Live teacher API replay returned the same ticket and expiry. Direct Test_PRM392 Sheet reads confirmed two tickets for three calls; the new request advanced generation by one.
- Chrome rejected an expired ticket and opened the existing Google Form for a valid ticket. Grants readback confirmed a new grant with 120-second grace.
- Windows 1.1.1 release displayed rotating QR codes over multiple cycles; observed issue requests took roughly 4.4–12 seconds. This is a limited sample, not a latency guarantee.

## Remaining acceptance

No new Form was submitted in this test. Existing FormResponses contain two email_not_in_roster rejections; Attendance is empty. The signed-in test account is absent from the roster, so an approved test email must be mapped before proving a successful submission. Then verify FormResponses, Attendance and desktop results agree; submit a duplicate; exercise closing/grace in a dedicated test session. These live steps are not replaced by the passing unit tests.

A separate probe still encountered intermittent ContentService redirects ending in invalid_response. Same-ID recovery handles uncertain issuance without adding another ticket, but Google transport latency is not proven eliminated. Pending request IDs survive retries within the process only; restart does not resume an unresolved issuance ID. There is no claim of complete live end-to-end acceptance yet.
