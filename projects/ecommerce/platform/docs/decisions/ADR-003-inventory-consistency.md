# ADR-003 — Inventory reservation consistency

**Status:** Accepted

## Context
Two customers can attempt to purchase the same last unit concurrently. A cart must not permanently lock inventory, but checkout must prevent overselling.

## Decision
Do not reserve inventory when an item is added to a cart. At checkout, create a time-bounded reservation using optimistic concurrency/atomic transactional logic. Only one concurrent reservation for the last unit may succeed.

The recommended production Cosmos topology uses one authoritative write region with automatic failover. Active-active writes to the same inventory state are not part of the baseline.

## Consequences
The application must implement reservation expiry/release, ETag conflict handling, and the 100-client/one-item concurrency test. Payment failure releases inventory; payment success commits the reservation.
