# Project Definition of Done

## Infrastructure

- [x] Static Web Apps Free selected explicitly in Bicep.
- [x] No paid compute resource is required.
- [x] No Azure database or storage account is required.
- [x] No Azure DNS dependency in the baseline.
- [x] No paid CDN / Front Door dependency in the baseline.
- [x] Resource tags identify the free-tier-first cost profile.

## Deployment

- [x] Infrastructure is reproducible through Bicep.
- [x] Bicep lint/build automation is included.
- [x] GitHub OIDC is the Azure authentication pattern.
- [x] Static Web Apps deployment token is retrieved at runtime.
- [x] Only curated public files are copied into the deploy artifact.
- [x] Pull requests can use preview environments.
- [x] Production deploys from `main`.

## Security

- [x] HTTPS/TLS is provided by Static Web Apps.
- [x] Security headers are defined in `staticwebapp.config.json`.
- [x] CSP restricts executable content.
- [x] Clickjacking protections are enabled.
- [x] Unneeded browser permissions are disabled.

## Cost

- [x] Baseline Azure hosting target is documented as $0/month within Free-plan quotas.
- [x] External domain-registration cost is clearly separated from Azure spend.
- [x] Free-plan quotas are documented.
- [x] Upgrade triggers are documented.
- [x] Services intentionally omitted for cost reasons are documented.

## Operations

- [x] Rollback process is documented.
- [x] Token-compromise procedure is documented.
- [x] Custom-domain approach is documented.
- [x] Source control is established as the content recovery mechanism.
