# Requirements and Constraints

This document is the architecture review entry point for the cost-optimized portfolio hosting project. It captures the workload characteristics, cost and operational constraints, non-goals, and the conditions that should trigger a different hosting design. Detailed “why this instead of that” decisions live in `docs/decisions/`.

## Architecture objective

Host the public Azure Solution Architect portfolio with the smallest practical Azure footprint while retaining a professional delivery workflow, managed HTTPS, custom-domain support, global static delivery, preview environments, Infrastructure as Code, and secretless Azure authentication.

The primary cost objective is **approximately $0/month in Azure hosting charges while the workload remains within Azure Static Web Apps Free-plan quotas**. Domain registration remains an external cost and is not counted as $0 Azure spend.

## Workload characteristics

The site is:

- public and internet-facing;
- static HTML, CSS, JavaScript, and a PDF resume;
- read-heavy;
- globally accessed;
- stateless at runtime;
- not business-critical;
- not dependent on a server-side API or database.

Those characteristics are architectural constraints: they make traditional always-on compute unnecessary.

## Functional requirements

- Serve the portfolio over HTTPS.
- Support the canonical `holdenjolley.com` custom domain when DNS is cut over.
- Support `www` as an additional friendly hostname if configured.
- Publish static portfolio content and the generated resume PDF.
- Support GitHub-based CI/CD.
- Support pull-request preview environments after the Static Web Apps resource exists.
- Keep Infrastructure as Code and internal architecture documentation out of the public web artifact.

## Non-functional requirements

### Cost

- Prefer the Free Static Web Apps tier while its quotas satisfy the workload.
- Do not add paid Azure services merely to make the architecture look more complex.
- Keep domain registration / registrar cost separate from Azure hosting cost.

### Security

- Use managed HTTPS / TLS.
- Apply browser security headers through `staticwebapp.config.json`.
- Use GitHub OIDC for Azure control-plane authentication instead of a reusable Azure client secret.
- Retrieve the Static Web Apps deployment token only at deployment runtime and mask it.
- Require explicit manual production deployment after What-If validation.
- Publish only a curated `dist/` artifact.

### Operability

- GitHub remains the source of truth.
- Revert + redeploy is the primary recovery model because the site has no mutable runtime state.
- A normal push/merge must not automatically create production Azure infrastructure.
- Production infrastructure creation/update is an explicit manually gated action.

### Performance

- Favor static assets and browser-native behavior over server execution.
- Keep the site within Static Web Apps storage/bandwidth guardrails.
- Treat a sustained quota or performance requirement as a redesign signal rather than hiding it behind the Free tier.

## Current design constraints

### Free tier has no SLA

Azure Static Web Apps Free is appropriate for a personal portfolio, but it is not an enterprise availability tier. The site must not be presented as having an SLA it does not have.

### Free-plan quotas are real architectural limits

The design assumes the workload remains within the Free-plan bandwidth, storage, custom-domain, and preview-environment limits documented in `docs/architecture/cost.md`. If the portfolio materially outgrows those limits, the architecture should be deliberately upgraded.

### DNS remains external

The existing registrar / DNS provider remains authoritative for the domain. Azure DNS is intentionally not added because it would create a recurring Azure resource without solving a current requirement.

### No backend exists by design

There is no Function App, App Service API, VM, database, or mutable storage layer in the baseline. Adding one would change the workload and should trigger a new architecture review.

### No dedicated application-observability stack

The baseline does not provision Application Insights or Log Analytics because there is no backend transaction flow, dependency graph, or server runtime to justify that cost/complexity. Deployment history and Azure resource health are sufficient for the current workload.

### Current portfolio OIDC identity is broader than the static site needs

The GitHub OIDC application is shared with larger portfolio validation workflows and currently has subscription-level permissions required by those projects. For long-lived static hosting, the least-privilege target is a dedicated deployment identity scoped to the portfolio resource group (or an equivalent narrowly scoped role) after bootstrap.

### Preview deployment depends on the production Static Web App existing first

Before the initial resource deployment, pull-request preview jobs safely detect that the Static Web App does not yet exist and skip content upload. This is expected bootstrap behavior, not a deployment failure.

## Non-goals

The baseline does not attempt to provide:

- an enterprise SLA;
- a backend application platform;
- a database or mutable content store;
- private endpoints / IP restrictions on the Free tier;
- a dedicated WAF / Front Door layer;
- Azure DNS hosting;
- dedicated Application Insights / Log Analytics;
- a paid service merely to demonstrate another Azure product.

## Decision rules and redesign triggers

| Trigger | Architecture response |
|---|---|
| Bandwidth approaches/exceeds Free-plan allowance | Move to a paid tier or different hosting architecture after reviewing actual traffic and cost. |
| Storage or preview-environment limits become restrictive | Upgrade deliberately rather than working around the Free limits. |
| More custom domains are required than the Free plan supports | Reevaluate the Static Web Apps tier / hosting choice. |
| An SLA becomes a business requirement | Move away from the current personal-project availability assumption and select a paid architecture with the required support/availability characteristics. |
| Private endpoints or IP restrictions become requirements | Move to a tier/architecture that supports the needed network controls. |
| A backend API or server-side runtime becomes necessary | Treat it as a new workload requirement and design the backend explicitly rather than bolting compute onto the static-site baseline. |
| The site becomes revenue-producing or business-critical | Revisit availability, monitoring, support, recovery, and security requirements as a production service. |
| Long-lived static hosting no longer needs subscription-level bootstrap permissions | Separate the static-site deployment identity and scope it to least privilege. |

## Architecture decisions

The detailed “why this instead of that” reasoning is recorded in `docs/decisions/`:

- `ADR-001-static-web-apps-free.md`
- `ADR-002-no-front-door.md`
- `ADR-003-external-dns.md`
- `ADR-004-no-observability-stack.md`
- `ADR-005-source-control-is-recovery.md`

Also review `docs/architecture/cost.md`, `docs/architecture/security.md`, and `KNOWN-LIMITATIONS.md` for the operating guardrails and current evidence boundary.

## Validation boundary

Current evidence proves the infrastructure definition and Azure control-plane evaluation, not the deployed runtime.

- Bicep lint/build and production parameter compilation are green.
- GitHub Actions authenticates to Azure through short-lived OIDC federation.
- A live subscription-scope ARM What-If resolves the intended footprint to one resource group and one Free-tier Static Web App.
- Production deployment remains manually gated and has not been run.
- The custom domain, managed certificate, preview environment, and real runtime performance remain unverified until the first deployment and DNS cutover occur.

No Azure resources for the portfolio hosting workload have been deployed yet.
