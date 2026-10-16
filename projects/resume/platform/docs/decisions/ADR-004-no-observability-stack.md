# ADR-004 — Do not deploy a paid observability stack

**Status:** Accepted

## Decision
Do not provision Application Insights or Log Analytics for the baseline portfolio.

## Rationale
The site has no backend application transactions, dependency calls, or server-side code. Deployment history and basic resource health are sufficient. Adding telemetry ingestion would create complexity and potential cost without actionable application signals.
