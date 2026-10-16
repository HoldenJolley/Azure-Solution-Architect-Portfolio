# Azure E-Commerce Platform — Infrastructure & Architecture

A production-oriented Azure reference architecture for an event-driven e-commerce backend. This repository package focuses on Infrastructure as Code and the architecture/operations documentation needed to support the application implementation.

## Architecture review path

If you are reviewing this project as an architect or hiring manager, start here:

1. [`REQUIREMENTS-AND-CONSTRAINTS.md`](REQUIREMENTS-AND-CONSTRAINTS.md) — the problem, hard constraints, non-goals, and redesign triggers.
2. [`docs/architecture/nfr-matrix.md`](docs/architecture/nfr-matrix.md) — quality attributes, design responses, current evidence, and remaining runtime validation.
3. [`docs/architecture/diagrams.md`](docs/architecture/diagrams.md) — solution, checkout, network, event, worker-redelivery, and failure-mode diagrams.
4. [`docs/decisions/`](docs/decisions/) — ADRs explaining why each major service/pattern was selected over alternatives.
5. [`KNOWN-LIMITATIONS.md`](KNOWN-LIMITATIONS.md) — production-hardening gaps and intentionally deferred work.
6. [`docs/architecture/`](docs/architecture/) — deeper networking, data, reliability, security, observability, cost, and CI/CD design.
7. [`PROJECT-CHECKLIST.md`](PROJECT-CHECKLIST.md) — definition of done and evidence boundary.

The intended review sequence is **requirements → constraints → quality attributes → alternatives → decisions → tradeoffs → validation → remaining limitations**.

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

## Validation status

The repository now has both compiler-level and live Azure control-plane evidence:

- dev, test, and production Bicep/parameter validation is green;
- GitHub Actions authenticates to Azure with short-lived OIDC federation and no Azure client secret;
- the dev architecture completes a live subscription-scope Azure Resource Manager What-If successfully;
- the current What-If predicts 41 creates and reports 14 identity-dependent role assignments as unsupported because their resource IDs require managed-identity principal IDs created during deployment;
- the live deployment path is explicitly gated and prepared to use a subscription-scope Azure Deployment Stack with `action-on-unmanage=deleteAll`;
- teardown is a separate manual workflow with its own typed confirmation and cleanup evidence capture;
- the Deployment Stack has not yet been exercised.

No e-commerce resources have been deployed to Azure yet.

## Prerequisites

- Azure subscription
- Azure CLI and Bicep CLI
- PowerShell 7+
- Permission to create resource groups/resources and role assignments

## Validate and deploy

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
./scripts/deploy.ps1 -Environment dev -EvidenceDirectory ./evidence
```

The deployment script runs another ARM What-If and then creates/updates the fixed stack `ecommerce-dev-validation-stack`. It does not use a normal unmanaged ARM deployment for the live validation environment.

For GitHub Actions, deployment remains manual. Set `deploy=true` and enter `DEPLOY-ECOMMERCE-dev` when the `dev` live-validation run is intentionally being started.

After validation, use the separate **e-commerce validation destroy** workflow and enter `DESTROY-ECOMMERCE-dev`. The destroy script refuses to fall back to direct resource-group deletion if the expected Deployment Stack cannot be found.

See [`docs/testing.md`](docs/testing.md) for the live evidence checklist and the exact boundary of what a successful validation run proves.

## Important application contract

The Bicep package provisions infrastructure and injects configuration through App Service settings. It does **not** yet include the .NET commerce API/worker binaries. See `src/README.md` for the expected application contract. The API must expose `/health` because Azure Front Door uses that path for health probes.

A deliberately small validation workload will be added before the temporary live exercise so we can verify Front Door, direct-origin restrictions, managed-identity access to Cosmos DB and Service Bus, worker consumption, and telemetry without pretending to have implemented the entire production commerce application.

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

See `REQUIREMENTS-AND-CONSTRAINTS.md`, `docs/architecture/nfr-matrix.md`, `docs/architecture/diagrams.md`, `docs/architecture`, `docs/decisions`, `docs/testing.md`, `docs/operations/runbook.md`, `KNOWN-LIMITATIONS.md`, and `PROJECT-CHECKLIST.md` for the architectural reasoning and definition of done.
