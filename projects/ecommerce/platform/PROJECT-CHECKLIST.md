# Project Definition of Done

Use this as the portfolio project's completion checklist.

## Infrastructure

- [ ] `dev` Bicep lints and builds.
- [ ] `dev` Azure `what-if` reviewed.
- [ ] `dev` deploys from a clean subscription/resource state.
- [ ] `prod` Bicep lints and builds.
- [ ] `prod` Azure `what-if` reviewed.
- [ ] Resource naming/tags are consistent.
- [ ] All required providers are registered.

## Application

- [ ] Health/readiness endpoints.
- [ ] Catalog.
- [ ] Customer profile/auth integration.
- [ ] Cart.
- [ ] Inventory reservation.
- [ ] Checkout/order state machine.
- [ ] Payment sandbox integration.
- [ ] Shipping simulation/integration.
- [ ] Analytics event consumer.

## Distributed systems

- [ ] Atomic last-item reservation.
- [ ] Reservation expiration/release.
- [ ] Versioned event envelope.
- [ ] Idempotent consumers.
- [ ] Retry/backoff.
- [ ] DLQ inspection and replay procedure.
- [ ] No double-charge on duplicate payment event.

## Security

- [ ] No Azure resource keys in application settings.
- [ ] Managed identities used for Azure data services.
- [ ] Front Door is the intended public ingress.
- [ ] Direct origin blocked/restricted.
- [ ] WAF policy tested.
- [ ] Prod data services use private endpoints.
- [ ] Customer/admin authorization tested.
- [ ] No cardholder data stored.

## Operations

- [ ] Correlation IDs flow across API and workers.
- [ ] Application Insights receives traces/metrics/logs.
- [ ] Alerts for API failure/latency.
- [ ] Alerts for Service Bus backlog/DLQ.
- [ ] Runbook tested.
- [ ] Dashboard/workbook screenshots prepared for portfolio.

## Resilience

- [ ] Payment outage test.
- [ ] Worker crash/redelivery test.
- [ ] Poison message/DLQ test.
- [ ] 100-user/one-item concurrency test.
- [ ] Primary-origin failure test.
- [ ] Secondary-region test for prod reference.
- [ ] RTO/RPO assumptions documented and validated where possible.

## Delivery and documentation

- [ ] GitHub OIDC configured.
- [ ] Infrastructure workflow passes.
- [ ] Application CI/CD workflow added.
- [ ] Architecture diagrams exported.
- [ ] ADRs complete.
- [ ] Cost trade-offs documented.
- [ ] README includes deploy/use/destroy instructions.
- [ ] Portfolio case study links to repository and architecture diagrams.
