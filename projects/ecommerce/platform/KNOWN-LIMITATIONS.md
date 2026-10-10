# Known Limitations and Production-Hardening Backlog

This package is intended to be deployable and portfolio-grade, but it deliberately stops short of claiming that a generic template is production-ready for every business. These are the remaining gaps that should be visible rather than hidden.

## Application code is not included yet

The Bicep provisions the hosting/data/messaging/security platform. `src/README.md` defines the contract for the API and workers. The backend binaries, database seed process, and end-to-end smoke tests are the next implementation layer.

## Messaging is not yet multi-region

The production-reference parameters deploy application compute in two regions but currently use one Azure Service Bus namespace. A regional outage affecting that namespace can interrupt asynchronous order processing even if Front Door successfully fails API traffic to the other App Service region.

Before a strict production claim, choose and test a Service Bus business-continuity design appropriate to the required RPO/RTO. Do not assume that two App Service regions automatically make messaging multi-region.

## Front Door-to-App Service uses public-origin restrictions, not Private Link

The API default endpoint remains enabled, but App Service access restrictions allow Azure Front Door backend traffic and validate the specific `X-Azure-FDID`. This keeps dev/CI deployment straightforward.

A stricter Premium topology can configure Front Door Private Link to each App Service origin and disable direct public origin access. That introduces a private-link connection approval lifecycle and should be added/tested as a separate hardening milestone.

## No Azure Firewall hub in the baseline

Each region has an application VNet containing an App Service integration subnet and a private-endpoint subnet. Azure Firewall/Bastion/hybrid gateways are intentionally excluded because they add material fixed lab cost and are not required for the backend to function.

If the portfolio scenario needs centralized egress inspection, hybrid access, or shared network services, add a regional hub-and-spoke extension and route tables deliberately rather than adding Firewall only for an architecture diagram.

## Diagnostic settings are not fully automated

Application Insights/Log Analytics are provisioned and applications receive the Application Insights connection string. Per-resource Azure diagnostic settings, WAF log routing, and final alert rules should be added after validating resource log categories in the target subscription/API versions.

## Customer identity is an integration boundary

The template creates a `userProfiles` container but does not create a customer identity tenant/provider. Authentication claims should supply the stable external subject ID used by application profiles. Administrative authorization must be separated from customer authorization.

## Payment provider is a boundary

No card data is stored. The payment worker must integrate with a sandbox/provider and use provider-side idempotency. Production payment/PCI scope depends on that provider and the final checkout implementation.

## Autoscaling is not configured yet

The App Service plans are fixed capacity in this baseline. Add autoscale rules only after establishing realistic CPU/request/latency/worker-backlog signals and testing scale behavior.

## Cosmos active-active writes are intentionally off in prod

The account is multi-region, but the recommended prod profile keeps a single write region with automatic failover. This simplifies the inventory invariant. Turning on `cosmosEnableMultipleWriteLocations` is an architecture experiment, not a free performance switch: the application must first define deterministic ownership/conflict behavior for concurrent writes to the same inventory logical partition.

## Deployment slots and private SCM are not configured

SCM/Kudu remains reachable so GitHub-hosted runners can deploy application packages later. A hardened production setup should use slots and, if the deployment endpoint is made private/restricted, a runner with appropriate private network access.
