# Security Architecture

A public static portfolio has a small attack surface, but it still receives a security baseline.

## Controls

- HTTPS is supplied and certificates are automatically renewed by Azure Static Web Apps.
- `staticwebapp.config.json` defines browser security headers.
- Content Security Policy limits executable content to this site.
- framing is disabled with `frame-ancestors 'none'` / `X-Frame-Options: DENY`.
- MIME sniffing is disabled.
- browser permissions such as camera, microphone, and geolocation are disabled.
- CI/CD uses GitHub OIDC to Azure instead of a long-lived Azure service-principal password.
- production resource creation requires an explicit manual workflow dispatch from `main` after What-If validation.
- the Static Web Apps deployment token is retrieved at workflow runtime and masked rather than permanently stored as a GitHub deployment secret.
- only a curated `dist/` directory is deployed; Bicep, ADRs, workflows, and internal project documentation are not published as site content.

## Deployment identity

The current GitHub OIDC application is shared across the portfolio's Azure validation workflows and has subscription-level permissions because the larger reference architectures create resource groups and RBAC assignments. That is broader than the static site alone requires.

For a long-lived production hosting configuration, the least-privilege target is to separate the static-hosting deployment identity after bootstrap and scope it to `portfolio-prod-rg` (or an equivalent custom role/scope that grants only the operations the workflow actually needs). The current shared identity is therefore treated as a portfolio validation/bootstrap identity, not evidence that the static workload requires subscription-wide privilege.

## What is intentionally not added

A WAF, Front Door, private endpoint, and network isolation are not justified for a public static portfolio on the Free plan. Adding them would increase cost and complexity without materially improving the current risk posture.
