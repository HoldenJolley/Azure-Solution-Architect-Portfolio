# Implementation Roadmap

## 1. Infrastructure baseline
Deploy dev, validate Front Door/App Service, managed identities, RBAC, Cosmos containers, and Service Bus subscriptions.

## 2. Catalog and health API
Implement `/health`, `/ready`, and product reads using managed identity to Cosmos DB.

## 3. Cart and customer profile
Implement cart/profile persistence plus customer authentication and a separate admin authorization boundary.

## 4. Inventory and checkout
Implement atomic reservation, reservation expiry/release, and the order state machine. Pass the 100-client/one-item concurrency test.

## 5. Event-driven workers
Publish versioned events; implement inventory, payment, and shipping consumers; prove idempotency, retry, and DLQ behavior.

## 6. Observability
Add distributed tracing/correlation, dashboards, alerts, and operational queries.

## 7. Analytics
Write immutable commerce events to Data Lake bronze and produce sample silver/gold datasets without coupling analytics availability to checkout.

## 8. Production-reference validation
Deploy prod in a controlled subscription; validate private DNS/endpoints, two-region Front Door behavior, failure scenarios, and observed recovery characteristics.

## 9. Optional enterprise extensions
Hub/spoke + Firewall, Front Door Private Link, API Management, customer identity tenant, production payment integration, Service Bus regional continuity, Azure Policy, Defender, and Sentinel should be added only when their requirements are explicit.
