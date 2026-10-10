# Architecture Overview

## Objective

Provide a deployable Azure foundation for a realistic e-commerce backend that demonstrates Azure Solution Architect competencies: global ingress, multi-region design, asynchronous messaging, distributed data, identity, private networking, observability, analytics, reliability, cost trade-offs, and Infrastructure as Code.

## Logical flow

```text
Client
  |
  v
Azure Front Door + WAF
  |
  +-------------------------+
  |                         |
  v                         v
Primary App Service      Secondary App Service
API + workers            API + workers
  |                         |
  +------------+------------+
               |
       +-------+--------+----------------+
       |                |                |
       v                v                v
   Cosmos DB        Service Bus      Key Vault
       |                |
       |                +--> Inventory Worker
       |                +--> Payment Worker
       |                +--> Shipping Worker
       |                +--> Analytics Worker --> Data Lake
       |
       +--> product/cart/order/inventory/reservation state

Telemetry --> Application Insights --> Log Analytics
```

## Resource organization

- `rg-ecommerce-<env>-global`: Front Door, WAF, Cosmos DB, Service Bus, Data Lake, Key Vault, Log Analytics, Application Insights, and private DNS when enabled.
- `rg-ecommerce-<env>-eus2`: primary VNet, App Service plan, API/workers, and regional private endpoints.
- `rg-ecommerce-<env>-wus2`: optional secondary-region equivalent.

## Application boundaries

- API: products, carts, checkout, and order retrieval.
- Inventory worker: reservation, release, and commit transitions.
- Payment worker: payment-provider interaction and idempotency.
- Shipping worker: fulfillment transitions.
- Analytics worker: copies business events to the Data Lake.

## Design principles

1. No application secrets in Bicep parameter files.
2. Managed identity is the default service-to-service authentication method.
3. Business workflows are asynchronous after checkout acceptance where practical.
4. Inventory reservation is an explicit consistency boundary.
5. Analytics is isolated from operational stores.
6. Dev optimizes for cost; prod reference optimizes for security/resilience.
7. Infrastructure is reproducible from source control.
8. Important failure paths require observable signals and runbooks.
