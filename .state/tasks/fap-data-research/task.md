# FAP/data research — 2026-09-26

User explicitly requested research, not implementation. Local worktree confirmed from prior session; no app/backend/Sheet writes or attendance actions.

Completed: re-read both original XML XLS (29/37 students, hashes match), live bounded Sheet reads, FAP extension source audit, current feature/API audit, GitHub open PR/issues read, safe GET sessions probe and primary UX/library research.

Findings and implementation boundary: docs/design/research-fap-data-2026-09-26.md. Main mismatch: Sheet has 6 old offerings/60 roster rows, not supplied classes; schedule tabs differ; latest direct Form response rejected email_not_in_roster; accepted Attendance empty. Live GET valid JSON in 11.875s, intermittent failure root cause not established. Existing direct-form task WIP preserved.

Next: user reviews research; implement only under subsequent authorization. No merge/deploy/build in research turn.
