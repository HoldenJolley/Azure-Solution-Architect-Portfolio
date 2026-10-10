# ADR-007 — Front Door origin security

**Status:** Accepted for baseline

## Context
Clients must not bypass Front Door/WAF and call the App Service origin directly. Front Door Premium Private Link is stronger but adds cost and origin private-link approval complexity.

## Decision
For the baseline, keep the API App Service endpoint public but restrict the main site to the `AzureFrontDoor.Backend` service tag and require the specific Front Door profile `X-Azure-FDID` header. Workers default-deny inbound traffic.

For a hardened Premium deployment, evaluate Front Door Private Link to App Service and disable public origin access completely.

## Consequences
The baseline remains straightforward for GitHub-hosted CI while still preventing ordinary direct-origin access. The stricter private-origin pattern is documented as a production-hardening milestone rather than implied to be already enabled.
