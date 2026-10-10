# Cost Architecture

## Principle

The repository separates a low-cost development profile from the production reference profile. Architecture quality includes knowing when **not** to deploy an expensive service.

## Main cost drivers

- Azure Front Door Premium
- PremiumV3 App Service plans in multiple regions
- Service Bus Premium messaging units
- Cosmos DB provisioned throughput and multi-region replication
- Data Lake storage/transactions
- Log Analytics ingestion/retention
- Private endpoints
- Optional future Azure Firewall

## Dev profile

One region, Front Door Standard, Service Bus Standard, S1 App Service, LRS Data Lake, single-region Cosmos DB, no private endpoints, and WAF Detection mode.

## Production reference profile

Two application regions, Front Door Premium, managed WAF rules, Service Bus Premium, P1v3 App Service plans, private endpoints, multi-region Cosmos DB with one recommended write region, and GZRS Data Lake.

## Governance tasks before production

1. Create Azure Budget alerts.
2. Add owner/cost-center/lifecycle tags.
3. Right-size Cosmos throughput from measured RU usage.
4. Right-size App Service from load-test results.
5. Review Log Analytics retention/ingestion.
6. Reconsider always-on analytics compute.
7. Apply reservations/commitments only after utilization is understood.
