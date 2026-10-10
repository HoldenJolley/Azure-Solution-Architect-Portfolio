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
- the Static Web Apps deployment token is retrieved at workflow runtime and masked rather than permanently stored as a GitHub deployment secret.
- only a curated `dist/` directory is deployed; Bicep, ADRs, workflows, and internal project documentation are not published as site content.

## Deployment identity

After the Static Web App is created, the GitHub OIDC service principal can be assigned Contributor only at the `portfolio-prod-rg` resource-group scope. The resource group contains only this portfolio resource, limiting the blast radius while allowing the workflow to retrieve the Static Web Apps deployment token.

## What is intentionally not added

A WAF, Front Door, private endpoint, and network isolation are not justified for a public static portfolio on the Free plan. Adding them would increase cost and complexity without materially improving the current risk posture.
