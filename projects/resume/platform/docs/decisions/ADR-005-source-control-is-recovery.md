# ADR-005 — Source control is the recovery mechanism

**Status:** Accepted

## Decision
Treat GitHub as the source of truth and use Git revert/redeploy as the content recovery mechanism.

## Rationale
The deployed site contains no mutable state. Separate runtime backups would duplicate data already versioned in source control and add unnecessary cost/operations.
