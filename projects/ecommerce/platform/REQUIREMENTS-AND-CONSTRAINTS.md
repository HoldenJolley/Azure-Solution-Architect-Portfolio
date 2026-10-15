# Requirements and Constraints

This document is the architecture review entry point for the e-commerce reference platform. It captures the problem the design is solving, the constraints that shape the solution, the things intentionally left outside the current scope, and the conditions that should trigger a redesign. Detailed service-by-service decisions live in `docs/decisions/`.

## Architecture objective

Provide a deployable Azure foundation for a realistic event-driven commerce backend that demonstrates global ingress, regional compute, asynchronous workflows, distributed data, identity, private networking, observability, reliability, cost tradeoffs, and Infrastructure as Code without adding platform complexity solely for portfolio value.

## Functional requirements

The platform must support these application boundaries:

- customer-facing product, cart, checkout, and order APIs;
- inventory reservation, release, and commit processing;
- payment-provider integration with idempotent processing;
- shipping / fulfillment transitions;
- asynchronous analytics delivery to a Data Lake;
- health endpoints suitable for Azure Front Door origin health checks.

The infrastructure package provisions the Azure platform for those workloads. The application binaries and end-to-end commerce implementation are a separate implementation layer.

## Non-functional requirements

### Reliability

- Keep the customer-facing API independently recoverable from background processing.
- Support an optional two-region production application stack behind Azure Front Door.
- Use Cosmos DB multi-region replication with a single authoritative write region and automatic failover in the production reference profile.
- Make retry, dead-letter, idempotency, and poison-message behavior explicit for asynchronous workflows.
- Treat each stateful dependency as its own recovery domain instead of calling the entire system “multi-region” because compute exists in two regions.

### Consistency

- Inventory must have a clearly defined authoritative write boundary.
- Reservation state and idempotency must prevent normal retry behavior from producing duplicate business effects.
- Multi-master Cosmos writes are not enabled by default because conflict semantics for the inventory partition must be designed before enabling them.

### Security

- Azure Front Door is the intended public application ingress.
- Managed identity is the default service-to-service authentication mechanism.
- Application secrets must not be stored in Bicep parameter files.
- Production-oriented data services use private endpoints / private DNS when the production profile enables them.
- Cosmos local/key authentication, Service Bus local/SAS authentication, and Storage Shared Key access are disabled by the infrastructure package.
- Key Vault uses Azure RBAC.

### Operability

- Infrastructure must be reproducible through modular Bicep and environment-specific parameters.
- Dev, test, and production parameter sets must compile before deployment.
- Important failure paths must produce observable signals and have a documented runbook/test path.
- Analytics must remain outside the critical checkout path.

### Cost

- The dev profile should be affordable enough for routine validation and architecture iteration.
- The production reference is allowed to cost materially more because it models stronger security and resilience requirements.
- High-fixed-cost services such as Azure Firewall are excluded unless a real requirement justifies them.

## Current design constraints

### Application implementation is not bundled

The repository defines the infrastructure, configuration contract, architecture, deployment tooling, and operating model. It does not currently contain the completed commerce API/workers, data-seeding process, or end-to-end smoke tests.

### Messaging continuity is currently single-region

The production reference can run API/worker compute in two regions, but the baseline uses one Service Bus namespace. A Service Bus regional outage can therefore pause asynchronous order processing even when Front Door successfully fails customer API traffic to another region.

### Front Door origin hardening favors deployability in the baseline

The App Service API endpoint remains public but is restricted to Azure Front Door backend traffic and the expected `X-Azure-FDID` value. Front Door Private Link to App Service is a valid stronger topology, but it adds a private-link approval lifecycle and is intentionally treated as a separate hardening milestone.

### Customer identity is an external integration boundary

The infrastructure does not provision a customer identity provider. The application is expected to receive a stable external subject identifier from the selected identity system. Administrative authorization must remain separate from customer authorization.

### Payment is an external integration boundary

No card data is stored by this platform. The payment worker must integrate with an external payment provider and use provider-side idempotency. Final PCI scope depends on that implementation and provider.

### Autoscale is deferred until telemetry exists

App Service capacity is fixed in the baseline. Autoscale rules should be added only after realistic CPU, request, latency, and worker-backlog signals are measured and tested.

### GitHub-hosted deployment affects SCM exposure

SCM/Kudu remains reachable so a GitHub-hosted runner can deploy future application packages. A stricter production posture should use deployment slots and a runner that can reach a private/restricted deployment endpoint.

## Non-goals

This package does not attempt to:

- demonstrate Kubernetes administration for its own sake;
- make every dependency active-active by default;
- define the customer identity product;
- implement or store payment-card data;
- add a centralized Firewall/Bastion/hybrid hub without a requirement;
- claim production runtime readiness before application code and resilience tests exist.

## Decision rules and redesign triggers

| Trigger | Architecture response |
|---|---|
| Kubernetes-specific scheduling, service mesh, or platform capabilities become requirements | Reevaluate App Service vs. AKS rather than adopting AKS for résumé value alone. |
| Business RTO requires asynchronous processing to survive a regional Service Bus outage | Add and test an explicit Service Bus continuity / failover design. |
| Direct public App Service origin exposure is no longer acceptable | Move to Front Door Private Link for the origin and test the approval/deployment lifecycle. |
| Centralized egress inspection, hybrid connectivity, or shared network services are required | Introduce a deliberate hub-and-spoke design and evaluate Azure Firewall / routing requirements. |
| Measured production load shows fixed capacity is insufficient | Add autoscale rules based on validated signals and test scale behavior. |
| Multi-region concurrent inventory writes become a requirement | Define deterministic ownership/conflict handling before enabling Cosmos multi-write. |
| Deployment endpoints must be private | Use deployment slots plus a private/self-hosted runner with the required network path. |

## Architecture decisions

The detailed “why this instead of that” reasoning is recorded in `docs/decisions/`:

- `ADR-001-app-service-vs-aks.md`
- `ADR-002-cosmos-db.md`
- `ADR-003-inventory-consistency.md`
- `ADR-004-service-bus.md`
- `ADR-005-multi-region.md`
- `ADR-006-private-networking.md`
- `ADR-007-front-door-origin-security.md`
- `ADR-008-managed-identity.md`

Also review `KNOWN-LIMITATIONS.md` for the remaining production-hardening backlog.

## Validation boundary

Current evidence proves that the infrastructure compiles and can be evaluated by the live Azure control plane; it does not prove production runtime behavior.

- Dev, test, and production Bicep/parameter validation is green.
- GitHub Actions authenticates to Azure through short-lived OIDC federation.
- The dev architecture completes a live subscription-scope ARM What-If.
- The current What-If predicts the planned resource changes and reports identity-dependent role assignments that cannot be fully resolved before deployment-time principal IDs exist.
- The deployment job remains gated and has not been run.
- No e-commerce Azure resources have been deployed yet.

Runtime claims such as failover timing, idempotent redelivery, inventory-race behavior, payment failure handling, and DLQ operations require an actual deployed application and controlled resilience testing.
