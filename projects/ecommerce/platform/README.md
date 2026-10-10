# Azure E-Commerce Platform — Infrastructure & Architecture

A production-oriented Azure reference architecture for an event-driven e-commerce backend. This repository package focuses on Infrastructure as Code and the architecture/operations documentation needed to support the application implementation.

## What this deploys

- Azure Front Door Standard/Premium with WAF policy
- One or two regional App Service stacks: Commerce API plus inventory, payment, shipping, and analytics workers
- Azure Cosmos DB for NoSQL with products, carts, orders, userProfiles, inventory, reservations, and processedMessages containers
- Azure Service Bus topic and subscriptions
- Azure Data Lake Storage Gen2
- Azure Key Vault
- Application Insights + Log Analytics
- Regional VNets with App Service integration subnets
- Optional private endpoints and private DNS
- Managed identities and data-plane RBAC

## Environment profiles

| Capability | Dev | Prod reference |
|---|---|---|
| Regions | 1 | 2 |
| Front Door | Standard | Premium |
| WAF mode | Detection | Prevention |
| Managed WAF rule sets | No | DRS 2.2 + Bot 1.0 |
| Service Bus | Standard | Premium |
| Cosmos DB | Single region | Multi-region, single-write + automatic failover |
| Private endpoints | Off | On |
| App Service | S1 | P1v3 |
| Data Lake redundancy | LRS | GZRS |

The prod profile is intentionally more expensive. Deploy dev for routine development and use prod as the reference architecture or for controlled validation.

## Prerequisites

- Azure subscription
- Azure CLI and Bicep CLI
- PowerShell 7+
- Permission to create resource groups/resources and role assignments

## Validate and deploy

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
./scripts/deploy.ps1 -Environment dev
```

## Important application contract

The Bicep package provisions infrastructure and injects configuration through App Service settings. It does **not** yet include the .NET commerce API/worker binaries. See `src/README.md` for the expected application contract. The API must expose `/health` because Azure Front Door uses that path for health probes.

## Security model

- Front Door is the intended public application ingress.
- API App Service access restrictions allow the `AzureFrontDoor.Backend` service tag and validate the `X-Azure-FDID` header.
- Worker app main endpoints deny inbound traffic by default.
- Application identities use managed identities instead of connection-string secrets.
- Cosmos DB local/key auth, Service Bus local/SAS auth, and Storage Shared Key access are disabled.
- Key Vault uses Azure RBAC.
- The prod profile disables public access on data services and creates private endpoints.

SCM/Kudu remains publicly reachable in this first package so a GitHub-hosted runner can deploy code. A locked-down production deployment should use a private/self-hosted runner and restrict the SCM endpoint.

## Documentation

See `docs/architecture`, `docs/decisions`, `docs/testing.md`, `docs/operations/runbook.md`, `KNOWN-LIMITATIONS.md`, and `PROJECT-CHECKLIST.md` for the architectural reasoning and definition of done.
