# Known Limitations and Upgrade Triggers

This portfolio-hosting architecture is intentionally small. The following limitations are accepted because the workload is a personal static site; they are not hidden behind enterprise-sounding language.

## The Free tier has no SLA

Azure Static Web Apps Free is suitable for this portfolio, but it does not provide an enterprise service-level agreement. If the site becomes business-critical, the hosting requirement should be revisited.

## Free-plan quotas bound the design

The architecture assumes the site remains within the current Static Web Apps Free limits documented in `docs/architecture/cost.md`, including bandwidth, storage, custom-domain, and preview-environment guardrails.

If sustained usage approaches those limits, upgrade deliberately rather than treating the Free tier as an unlimited hosting platform.

## No private endpoint or IP restriction baseline

The Free architecture does not provide the private-networking controls that a more sensitive application might require. This is acceptable because the portfolio is intentionally public static content.

If private endpoints or IP restrictions become requirements, move to an appropriate paid tier / architecture instead of layering compensating complexity onto the Free design.

## No dedicated WAF or Front Door

Static Web Apps already provides the content-delivery capabilities the workload currently needs. A separate paid edge layer would add cost without satisfying an unmet requirement.

Reevaluate this only if the risk model or application behavior changes enough to require dedicated edge-policy capabilities.

## DNS depends on the external provider

The custom domain is managed through the existing external registrar / DNS provider. Azure DNS is intentionally not provisioned.

A DNS-provider outage or misconfiguration is therefore outside the Azure resource footprint and should be considered during the domain cutover / recovery process.

## No backend telemetry stack

There is no Application Insights or Log Analytics workspace in the baseline because the site has no backend transaction flow or service dependency graph.

GitHub deployment history, Static Web Apps resource health, and browser-visible behavior are the primary operational signals. If the site gains a backend, the observability requirement must be revisited.

## Recovery assumes source control is authoritative

There is no mutable application state to back up. Recovery is Git revert / redeploy from the repository.

That is appropriate only while the site remains static. Any future mutable backend data would require a separate backup / recovery design.

## Initial PR previews cannot publish before bootstrap

The preview workflow checks whether the production Static Web App exists. Before the first infrastructure deployment it safely skips preview content upload.

After the Static Web App exists, pull-request preview behavior should be tested as runtime evidence rather than assumed from configuration alone.

## Runtime behavior is not yet verified

The current evidence is compiler + Azure control-plane validation only. The first actual deployment still needs to prove:

- Static Web Apps content publishing;
- `holdenjolley.com` and optional `www` DNS mapping;
- managed HTTPS certificate issuance/renewal behavior;
- security-header behavior in the deployed environment;
- preview-environment creation;
- real mobile/browser rendering and performance;
- rollback/redeploy procedure;
- bandwidth/storage behavior within the Free tier.

No production deployment has been executed yet.

## Deployment identity is broader than the static workload requires

The current GitHub OIDC application is shared with the broader portfolio validation workflows and has subscription-level permissions required by the larger architecture projects.

After bootstrap, the long-lived least-privilege target is a dedicated static-hosting identity scoped to `portfolio-prod-rg` (or an equivalent narrowly scoped role/scope).

## Upgrade triggers

Revisit the baseline when any of these becomes true:

- bandwidth approaches/exceeds Free-plan allowance;
- storage or preview-environment limits become restrictive;
- more custom domains are required than the Free plan supports;
- an SLA becomes a business requirement;
- private endpoints or IP restrictions are required;
- a backend API/server runtime is added;
- the site becomes revenue-producing or business-critical;
- dedicated monitoring/support becomes justified;
- the shared bootstrap identity can be replaced by a dedicated least-privilege deployment identity.
