# Cost-Optimized Azure Static Portfolio

This project is the hosting architecture for the Azure Solution Architect portfolio itself. Its primary requirement is **minimum recurring Azure cost** while retaining a professional deployment workflow, HTTPS, global delivery, custom-domain support, pull-request previews, and Infrastructure as Code.

## Design objective

The architecture intentionally uses the smallest practical Azure footprint:

```text
GitHub repository
      │
      │ GitHub Actions
      ▼
Azure Static Web Apps — Free
      │
      ├── globally distributed static content
      ├── managed HTTPS / TLS certificates
      ├── custom domain support
      └── pull-request preview environments
```

There is no App Service plan, VM, database, storage account, Function App, Front Door, Application Insights workspace, or Azure DNS zone in the baseline design.

## Expected Azure hosting cost

**$0/month while the site remains within Azure Static Web Apps Free-plan quotas.**

External costs such as domain registration are outside Azure and are not represented as $0.

## Why Static Web Apps Free

The current Free plan is intended for personal projects and includes global static-content distribution, GitHub integration, automatically renewing TLS certificates, custom domains, and preview environments. The Free plan currently includes 100 GB/month of bandwidth, up to 250 MB per environment, 500 MB total storage across environments, two custom domains, and three preview environments. It does not include an SLA, private endpoints, or IP restrictions.

See `docs/architecture/cost.md` for the decision thresholds that would justify upgrading to Standard.

## Deployment model

Infrastructure and content deployment are separated:

1. `infra/main.bicep` creates the Free-tier Static Web App.
2. GitHub Actions authenticates to Azure with OIDC.
3. The workflow retrieves the Static Web Apps deployment token at runtime rather than storing it permanently in GitHub.
4. A small `dist/` package is assembled containing only the public portfolio assets.
5. Pushes to `main` deploy production; pull requests use Static Web Apps preview environments.

## Validate

```powershell
./projects/resume/platform/scripts/validate.ps1
```

## Deploy infrastructure

```powershell
./projects/resume/platform/scripts/deploy-infra.ps1
```

The Static Web Apps deployment itself is performed by `.github/workflows/static-portfolio.yml`.

## Project documentation

- `docs/architecture/overview.md` — solution architecture
- `docs/architecture/cost.md` — cost model and upgrade thresholds
- `docs/architecture/security.md` — security baseline
- `docs/architecture/operations.md` — operations and recovery
- `docs/architecture/performance.md` — bandwidth and asset optimization
- `docs/decisions/` — architecture decision records
- `PROJECT-CHECKLIST.md` — definition of done

## Design principle

> Cost optimization is not “use the cheapest SKU everywhere.” It is choosing the least complex architecture that still satisfies the workload requirements, then defining clear signals for when the architecture should change.
