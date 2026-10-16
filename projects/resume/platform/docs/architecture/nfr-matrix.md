# Non-Functional Requirements Matrix

This matrix maps the portfolio-hosting workload to the quality attributes that actually matter for a public static site. It also makes clear where the Free-tier design is an accepted tradeoff rather than an enterprise availability claim.

| Quality attribute | Requirement / constraint | Design response | Current evidence | Remaining validation |
|---|---|---|---|---|
| Cost | Recurring Azure hosting should remain at or near $0 while the site stays within included quotas | Azure Static Web Apps Free; no App Service, Functions, Front Door, Azure DNS, database, storage account, or dedicated monitoring workspace | Cost model and ADRs documented; intended Free SKU passes ARM What-If | Measure actual Azure charges after deployment and monitor quota use |
| Availability | Personal portfolio should be publicly reachable, but enterprise SLA is not required | Static Web Apps Free provides managed static delivery; lack of SLA is explicitly accepted | Architecture documented | Deploy and observe service behavior; upgrade only if business-critical availability becomes a requirement |
| Performance | Static content should load quickly without dedicated paid edge infrastructure | Globally distributed Static Web Apps content; static HTML/CSS/JS; asset optimization guidance | Architecture/performance docs exist | Measure page weight, browser performance, and geographic behavior after deployment |
| Security | Public site should use a small attack surface and modern browser controls | Managed HTTPS/TLS; CSP, clickjacking protection, MIME-sniffing protection, restrictive permissions policy; no server-side runtime | Security config/docs are source-controlled | Validate response headers and TLS on the actual deployed/custom-domain endpoint |
| Deployment identity | CI/CD should not depend on a long-lived Azure client secret | GitHub Actions uses OIDC federation to Azure; deployment token is retrieved at runtime and masked | OIDC login succeeds in CI; workflow logic documented | Separate a long-lived least-privilege static-hosting deployment identity after bootstrap if production operation warrants it |
| Change safety | Infrastructure changes should be reviewable before creation | Bicep lint/build + production params + live ARM What-If; production deployment requires explicit manual dispatch from `main` | Compiler validation, OIDC, and What-If are green | Re-run immediately before production deployment and after material template changes |
| Recoverability | Site content/configuration must be recoverable without stateful backup infrastructure | GitHub is source of truth; recovery is revert + redeploy | Recovery model documented | Perform and record a controlled rollback/redeploy after deployment |
| Custom domain | `holdenjolley.com` should become the canonical public identity endpoint | Domain remains at external registrar/DNS provider and will map to Static Web Apps; managed certificate supplies TLS | Domain ownership is external; architecture supports custom domain | Configure DNS, validate ownership/certificate, apex/`www` behavior, redirects, canonical URLs, and sitemap after deployment |
| Maintainability | Hosting architecture should remain simpler than the workload | One resource group + one Static Web App; no unnecessary backend/data plane | Resource footprint passes ARM What-If | Revisit only when new requirements justify additional services |
| Observability | Operational tooling should be proportional to a stateless personal site | GitHub deployment history and Azure resource health are sufficient baseline; no dedicated Application Insights/Log Analytics stack | Decision documented | If runtime/business importance grows, define monitoring/SLO requirements before adding paid observability |
| Scalability | Normal portfolio traffic should fit Free-plan guardrails | Static hosting scales within platform quotas without application server management | Free-plan guardrails documented | Track bandwidth/storage/domain/preview usage and upgrade intentionally if limits approach |
| Privacy | Site should not request unnecessary browser capabilities or introduce personal-data processing infrastructure | No backend/database; browser permissions such as camera/microphone/geolocation disabled by policy | Security headers/config documented | Validate deployed headers and review any future analytics/contact integrations before adding them |

## Upgrade stance

The architecture should move beyond the Free baseline only when a requirement justifies it—for example an SLA, higher bandwidth, additional custom domains/preview environments, private endpoints/IP restrictions, backend API requirements, or business-critical/revenue-producing use.

## Review questions

A reviewer should be able to challenge this matrix with questions such as:

- Which requirement would justify paying for Front Door or App Service?
- What actually needs backup in a stateless source-controlled site?
- Which security controls can only be verified after the public endpoint exists?
- Why is external DNS acceptable here?
- At what point does the Free tier stop being the right architecture?
