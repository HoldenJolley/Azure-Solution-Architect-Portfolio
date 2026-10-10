# ADR-007: Optional confidential compute

**Decision:** Make ACA confidential compute an opt-in workload profile, not the default.

**Rationale:** It strengthens protection of data in use but current regional availability is limited.

**Consequence:** Standard deployments rely on platform/process isolation plus payload encryption; high-assurance deployments select a supported DC-series region/profile.
