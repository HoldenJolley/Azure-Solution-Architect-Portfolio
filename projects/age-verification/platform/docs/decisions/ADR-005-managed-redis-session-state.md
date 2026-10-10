# ADR-005: Azure Managed Redis for ephemeral session state

**Decision:** Use Azure Managed Redis with TLS, Private Link, Entra authentication, access keys disabled, and TTL-only one-time session/nonce records.

**Rationale:** Horizontal gateway replicas need atomic anti-replay state without creating a durable user/image database. Azure Cache for Redis is retiring, so the new Managed Redis service is used.

**Consequence:** Redis availability becomes part of verification availability; default behavior fails closed if it is unavailable.
