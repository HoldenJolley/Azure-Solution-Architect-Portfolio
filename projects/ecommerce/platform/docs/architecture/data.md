# Data Architecture

## Operational data — Azure Cosmos DB for NoSQL

The template creates a shared-throughput `commerce` database with containers for products, carts, orders, user profiles, inventory, reservations, and processed message IDs.

| Container | Partition key | Purpose |
|---|---|---|
| products | `/category` | Product catalog |
| carts | `/userId` | Active carts |
| orders | `/userId` | Order state |
| userProfiles | `/id` | Application profile keyed to external identity |
| inventory | `/sku` | Sellable/reserved/sold inventory |
| reservations | `/sku` | Checkout reservations |
| processedMessages | `/consumer` | Consumer idempotency state |

The default consistency level is Session. The production profile replicates Cosmos DB to both application regions but keeps a **single write region with automatic failover**. This keeps the inventory correctness model understandable. Multi-write remains opt-in and requires a separately designed conflict/ownership strategy.

## Inventory consistency boundary

Cart state does not reserve inventory. Reservation occurs at checkout. A last-item reservation must use an atomic conditional update or transaction; never implement independent read-check-write operations.

Recommended state model:

```text
Available -> Reserved -> Sold
              |
              +-> Released (failure/timeout)
```

Use ETags/optimistic concurrency and Cosmos transactional batch where operations share a logical partition. The acceptance criterion for inventory quantity 1 under 100 concurrent attempts is exactly one successful reservation and no negative inventory.

## Messaging

Service Bus topic: `commerce-events`

Subscriptions: `inventory`, `payment`, `shipping`, `analytics`.

Every event carries an event ID, event type/version, timestamp, correlation ID, order ID, and payload. Consumers must be idempotent; `processedMessages` supports that behavior.

## Analytical data

Data Lake Gen2 uses bronze/silver/gold layers. The analytics consumer writes immutable business events to bronze; curated reporting should use downstream datasets rather than querying operational Cosmos containers directly.
