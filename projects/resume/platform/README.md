# Cost-Optimized Azure Static Portfolio

This project is the hosting architecture for the Azure Solution Architect portfolio itself. Its primary requirement is **minimum recurring Azure cost** while retaining a professional deployment workflow, HTTPS, global delivery, custom-domain support, pull-request previews, and Infrastructure as Code.

## Architecture review path

If you are reviewing this project as an architect or hiring manager, start here:

1. [`REQUIREMENTS-AND-CONSTRAINTS.md`](REQUIREMENTS-AND-CONSTRAINTS.md) — workload characteristics, hard constraints, non-goals, and redesign triggers.
2. [`docs/architecture/nfr-matrix.md`](docs/architecture/nfr-matrix.md) — cost, availability, security, performance, recovery, domain/TLS, and validation quality attributes.
3. [`docs/architecture/diagrams.md`](docs/architecture/diagrams.md) — public request path, secretless Azure delivery, publication, change control, recovery, and intentionally omitted services.
4. [`docs/decisions/`](docs/decisions/) — ADRs explaining why the baseline uses Static Web Apps Free and deliberately omits other Azure services.
5. [`KNOWN-LIMITATIONS.md`](KNOWN-LIMITATIONS.md) — Free-tier limits, bootstrap caveats, evidence gaps, and upgrade triggers.
6. [`docs/architecture/`](docs/architecture/) — deeper cost, security, operations, performance, and solution-design details.
7. [`PROJECT-CHECKLIST.md`](PROJECT-CHECKLIST.md) — definition of done and deployment/runtime evidence boundary.

The intended review sequence is **requirements → constraints → quality attributes → alternatives → decisions → tradeoffs → validation → remaining limitations**.

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

## Validation status

The infrastructure has been validated without creating Azure resources:

- Bicep lint/build and production parameter compilation are green.
- GitHub Actions authenticates to Azure through short-lived OIDC federation.
- A live subscription-scope Azure Resource Manager What-If resolves the intended footprint to exactly one resource group and one Free-tier Static Web App.
- No production deployment has been executed yet.

## Deployment model

Infrastructure validation, preview publishing, and production deployment are deliberately separated:

1. Pull requests and pushes to `main` run Bicep validation and Azure Resource Manager What-If.
2. A pull request publishes a Static Web Apps preview only **after** the production Static Web App exists; before the initial deployment, the preview job detects that the resource is absent and skips safely.
3. Production deployment is a manually approved `workflow_dispatch` from `main` with `deploy=true`.
4. After What-If succeeds, the production job deploys/updates `infra/main.bicep`, retrieves the Static Web Apps deployment token at runtime, assembles a curated `dist/` package, and publishes the site.
5. The deployment token is masked and is not stored as a long-lived GitHub deployment secret.

This means merging code alone does not create Azure resources.

## Validate

Local compiler validation:

```powershell
./projects/resume/platform/scripts/validate.ps1
```

Live Azure What-If after Azure CLI authentication:

```powershell
./projects/resume/platform/scripts/validate.ps1 -RunWhatIf
```

## Deploy infrastructure manually

The helper script can be used directly when an authenticated operator explicitly chooses to create/update the infrastructure:

```powershell
./projects/resume/platform/scripts/deploy-infra.ps1
```

The normal production path is the manually gated deployment job in `.github/workflows/static-portfolio.yml`.

## Project documentation

- `REQUIREMENTS-AND-CONSTRAINTS.md` — architecture requirements, constraints, non-goals, and redesign triggers
- `KNOWN-LIMITATIONS.md` — accepted limitations and upgrade triggers
- `docs/architecture/overview.md` — solution architecture
- `docs/architecture/nfr-matrix.md` — non-functional requirements and validation status
- `docs/architecture/diagrams.md` — source-controlled architecture diagrams
- `docs/architecture/cost.md` — cost model and upgrade thresholds
- `docs/architecture/security.md` — security baseline
- `docs/architecture/operations.md` — operations and recovery
- `docs/architecture/performance.md` — bandwidth and asset optimization
- `docs/decisions/` — architecture decision records
- `PROJECT-CHECKLIST.md` — definition of done

## Design principle

> Cost optimization is not “use the cheapest SKU everywhere.” It is choosing the least complex architecture that still satisfies the workload requirements, then defining clear signals for when the architecture should change.
