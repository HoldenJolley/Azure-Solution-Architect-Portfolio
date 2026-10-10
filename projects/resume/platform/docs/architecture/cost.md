# Cost Architecture

## Primary objective

Keep recurring Azure cost as close to **$0/month** as practical while preserving a professional public website and automated deployment process.

## Baseline cost model

| Component | Selection | Expected Azure charge |
|---|---|---:|
| Static hosting | Azure Static Web Apps Free | $0 within Free quotas |
| Global distribution | Included with Static Web Apps Free | $0 |
| TLS certificate | Automatically managed by Static Web Apps | $0 |
| Preview environments | Included, up to Free-plan quota | $0 |
| DNS | Existing external registrar/DNS provider | No added Azure DNS charge |
| CI/CD | GitHub Actions | Subject to GitHub account quotas, not Azure hosting cost |
| Backend compute | None | $0 |
| Database | None | $0 |
| Azure monitoring workspace | None | $0 |

Domain registration is an external cost and is intentionally excluded from the Azure cost target.

## Current Free-plan guardrails

At the time this architecture was written, Azure Static Web Apps Free includes:

- 100 GB/month included bandwidth;
- 250 MB maximum storage for a single environment;
- 500 MB total storage across environments;
- three preview environments;
- two custom domains.

The Free tier does not provide bandwidth overage billing: workloads that need greater capacity should be deliberately upgraded rather than unexpectedly accruing overage charges.

## Services intentionally not deployed

### Azure Front Door
The site already receives globally distributed static content. Front Door would add cost without solving a current requirement.

### Azure DNS
The existing registrar/DNS provider can map the domain to Static Web Apps. Azure DNS would create a small but unnecessary recurring cost.

### Application Insights / Log Analytics
The site has no backend transaction flow requiring distributed tracing. GitHub deployment history and basic Azure resource health are sufficient for the workload.

### App Service / Functions
Static HTML, CSS, JavaScript, and the resume PDF need no server-side execution.

## Upgrade triggers

Move to Static Web Apps Standard or a different architecture only when one of these becomes true:

- bandwidth approaches or exceeds the Free-plan quota;
- more than two custom domains are required;
- more preview environments are required;
- an SLA becomes a business requirement;
- private endpoints or IP restrictions become requirements;
- a backend API needs Standard-only features;
- the site becomes revenue-producing or business-critical enough that paid support/availability is justified.

The upgrade decision should be requirement-driven, not resume-driven.
