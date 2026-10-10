# Testing Strategy

A deployable reference architecture needs tests for code and architectural behavior.

## IaC

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
```

Validate prod independently before a production-reference deployment.

## Unit tests

Cover cart validation/math, inventory state transitions, reservation expiration, order transitions, event serialization/versioning, and idempotency decisions.

## Integration tests

Validate managed-identity access to Cosmos DB, Service Bus publish/consume, Key Vault access, analytics writes to Data Lake, Front Door health, and direct-origin rejection.

## Last-item concurrency test

Precondition: one unit of a SKU. Send 100 concurrent reservation/checkout attempts.

Acceptance: exactly one succeeds, 99 fail as unavailable/conflict, inventory never becomes negative, and only one active/committed reservation exists.

## Idempotency

Deliver the same event/message repeatedly using the same `eventId`/`MessageId`. There must be one business side effect; duplicates are safely acknowledged and recorded as processed.

## Failure tests

- payment provider timeout/failure
- reservation expiration
- worker crash after side effect but before message completion
- poison event -> DLQ
- retry exhaustion
- Cosmos throttling/transient errors
- primary App Service origin failure
- analytics outage without commerce outage

## Observability acceptance

Given `correlationId`, reconstruct the checkout across API, Service Bus, workers, payment result, inventory, and final order state. Alert on sustained API failures/latency, DLQ messages, and abnormal backlog.

## Security tests

- direct origin blocked
- WAF test traffic detected/blocked per environment mode
- prod data-service public access blocked
- wrong managed identity denied
- no keys/passwords in application settings
- customer identity denied from admin operations
