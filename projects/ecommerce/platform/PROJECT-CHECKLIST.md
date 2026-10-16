# Project Definition of Done

Use this as the portfolio project's completion checklist. Items are checked only when the current repository evidence supports them; deployment/runtime items remain open until the infrastructure and application are actually exercised.

## Infrastructure

- [x] `dev` Bicep lints and builds.
- [x] `dev` Azure `what-if` reviewed successfully against the live subscription.
- [ ] `dev` deploys from a clean subscription/resource state.
- [x] `test` Bicep lints and builds.
- [x] `prod` Bicep lints and builds.
- [ ] `prod` Azure `what-if` reviewed.
- [x] Resource naming/tags are consistent in compiler and dev What-If output.
- [ ] All required providers/quotas are confirmed for an actual deployment target.
- [x] Temporary live deployment is modeled as a subscription-scope Azure Deployment Stack with `deleteAll` cleanup.
- [x] Live deployment is manual and requires an explicit typed confirmation.
- [x] Teardown is a separate manual workflow and refuses direct resource-group deletion when the expected stack is missing.
- [x] Deployment and cleanup workflows capture evidence artifacts.

## Application

- [ ] Minimal live-validation workload for health/readiness and Azure integration checks.
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

- [ ] No Azure resource keys in application settings at runtime.
- [ ] Managed identities verified against deployed Azure data services.
- [ ] Front Door verified as the intended public ingress.
- [ ] Direct origin blocked/restricted in a deployed environment.
- [ ] WAF policy tested.
- [ ] Prod data services verified through private endpoints.
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

- [x] GitHub OIDC configured with short-lived federation.
- [x] Infrastructure compiler and live dev What-If workflow passes.
- [ ] Infrastructure Deployment Stack job exercised.
- [ ] Application CI/CD workflow added.
- [ ] Live-validation evidence package captured.
- [ ] Deployment Stack teardown exercised and cleanup evidence captured.
- [ ] Architecture diagrams exported as presentation artifacts.
- [x] ADR set complete for the current reference architecture.
- [x] Cost trade-offs documented.
- [x] README includes validation/deploy guidance and explicit scope limitations.
- [x] Public portfolio case study describes the architecture and validation boundary.
