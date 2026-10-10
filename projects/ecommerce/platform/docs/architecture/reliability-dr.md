# Reliability and Disaster Recovery

## Reliability goals

The reference architecture separates stateless compute recovery from stateful-service continuity. Deploying App Service twice does not automatically make every dependency multi-region.

## Failure behavior

| Failure | Expected behavior |
|---|---|
| Primary API origin unhealthy | Front Door routes to healthy secondary origin in the production reference profile |
| Worker process crashes | Locked message becomes available for redelivery; consumer must be idempotent |
| Poison message | Retry limit is reached and message moves to the DLQ |
| Payment provider unavailable | Retry/backoff according to policy; order remains non-complete and inventory is eventually released |
| Reservation expires | Inventory returns to sellable state |
| Cosmos write region unavailable | Cosmos account failover promotes the configured secondary region |
| Analytics unavailable | Commerce workflow continues; analytics can catch up from retained events/messages |
| Service Bus regional outage | Async processing can pause; current baseline requires a future business-continuity enhancement |

## RPO/RTO framing

Targets must be business-defined, then validated by tests. Initial portfolio targets can be documented as objectives rather than guarantees:

- Stateless API: minutes or less once Front Door marks an origin unhealthy.
- Operational Cosmos data: target low RPO using multi-region replication and automatic failover; validate observed behavior.
- Async messages: baseline depends on the single Service Bus namespace; do not claim regional messaging RTO until a tested continuity design is implemented.
- Analytics: higher RTO/RPO is acceptable because it is not on the checkout critical path.

## Required resilience exercises

1. Disable/unhealthy the primary API origin and verify Front Door routes to the secondary.
2. Crash a worker after a side effect but before message completion; prove idempotent redelivery.
3. Inject a poison event and verify DLQ behavior and runbook handling.
4. Simulate payment timeout/failure and prove reserved inventory is released.
5. Run the 100-client/one-item inventory race test.
6. Exercise Cosmos regional failover in a controlled environment and record observed recovery.

## Backups and recovery

Use native service protection appropriate to final requirements, but do not confuse backup with high availability. Recovery documentation must state who triggers recovery, what data can be lost, how integrity is verified, and how traffic is restored.
