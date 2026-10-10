# ADR-002 — Cosmos DB for operational commerce data

**Status:** Accepted

## Context
The platform needs horizontally scalable product/cart/order/inventory state, regional replication, optimistic concurrency, and Azure-native identity integration.

## Decision
Use Azure Cosmos DB for NoSQL for the operational commerce data model.

## Rationale
Cosmos DB supports global distribution, per-item ETags, transactional batch within a logical partition, managed-identity data-plane RBAC, and flexible document models suited to this reference platform.

## Consequences
Partition-key choices are architectural decisions. Cross-partition transactions are not available; inventory invariants must be designed around logical partition boundaries. RU consumption and multi-region replication must be cost-managed.
