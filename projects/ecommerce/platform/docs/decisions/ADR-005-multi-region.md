# ADR-005 — Multi-region compute with explicit stateful-service continuity

**Status:** Accepted

## Context
The production reference should demonstrate regional resilience without pretending every dependency becomes active-active automatically.

## Decision
Deploy App Service/API workers in two regions behind Azure Front Door. Replicate Cosmos DB across both regions using a single authoritative write region with automatic failover. Treat Service Bus regional continuity as a separate backlog item rather than hiding it behind the multi-region label.

## Consequences
Front Door can route around an unhealthy API origin. Cosmos can fail over its write region. Async processing can still pause during a Service Bus regional outage until a tested messaging-continuity design is added. RPO/RTO statements must reflect each dependency separately.
