# ADR-004 — Service Bus for asynchronous commerce workflows

**Status:** Accepted

## Context
Payment, inventory, shipping, and analytics should not be tightly coupled synchronous calls, and workers must tolerate transient failures/redelivery.

## Decision
Use an Azure Service Bus topic (`commerce-events`) with independent subscriptions for inventory, payment, shipping, and analytics.

## Rationale
Service Bus provides durable messaging, topics/subscriptions, peek-lock processing, retries, duplicate detection, and dead-letter queues. Consumers are still required to be idempotent because at-least-once delivery can produce duplicate processing attempts.

## Consequences
Every event must have a stable ID/version/correlation ID. Workers implement idempotency and DLQ handling. The baseline does not claim cross-region messaging continuity; that remains a separate DR decision.
