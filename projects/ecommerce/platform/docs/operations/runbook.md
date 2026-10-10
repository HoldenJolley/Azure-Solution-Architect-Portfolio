# Operations Runbook

## Deployment validation

1. Confirm deployment has no failed operations.
2. Record Front Door hostname from outputs.
3. Confirm direct API origin returns 403 after restrictions propagate.
4. Confirm Front Door `/health` succeeds after code deployment.
5. Validate managed-identity role assignments.
6. In prod, validate private DNS resolution/connectivity.
7. Verify Service Bus topic/subscriptions and Cosmos containers.
8. Verify Application Insights receives a test request.

## Dead-letter queue

1. Identify the affected subscription and message count.
2. Peek messages non-destructively.
3. Capture message ID, correlation ID, event type, delivery count, and dead-letter reason.
4. Fix the consumer/data problem.
5. Replay only after verifying consumer idempotency.
6. Verify final business state and record root cause.

Never blindly replay a payment event without verified payment idempotency.

## Inventory inconsistency

Stop automated corrective writes; reconstruct the SKU's reservations/orders using correlation IDs; reconcile against successful payment/order state; apply a controlled correction with an audit event; then add a regression test.

## Regional outage

Confirm Front Door origin health, verify traffic reaches the surviving region, confirm dependency connectivity, inspect queue backlog/payment/inventory failures, and re-enable the failed origin only after dependencies and health checks recover.

## Rollback

Until deployment slots are implemented, identify the last known-good artifact, redeploy it to the affected region, run smoke tests, and re-enable the Front Door origin only after health checks pass.
