# Reliability and Disaster Recovery

## Baseline

The production parameter set runs multiple gateway/inference replicas and enables a zone-redundant Container Apps environment. Managed Redis is high availability enabled. Front Door is globally distributed.

## Failure behavior

| Failure | Expected behavior |
|---|---|
| Gateway replica failure | ACA routes to healthy replica |
| Inference replica failure | internal ACA route retries/new request reaches healthy replica |
| Key Vault unavailable | fail closed; no verification |
| Redis unavailable | fail closed for new one-time sessions unless an explicitly approved stateless mode exists |
| Model unhealthy | `/ready` fails; verification denied/unavailable |
| Front Door/WAF outage | service unavailable; origin remains private |
| Region outage | baseline service unavailable until recovery/secondary deployment |

## Multi-region extension

A regulated/high-availability production deployment can deploy an independent second regional stamp with:

- separate Container Apps environment;
- synchronized approved model version;
- regional Key Vault strategy and public-key set;
- regional/geo session-state strategy;
- Front Door origin group failover;
- explicit attestation trust across regions.

Do not add a second region casually: cryptographic key/version and one-time-session semantics must remain deterministic.

## RTO/RPO

Image data has no RPO because it is intentionally nonpersistent. RTO applies to service availability/configuration. Define business RTO before selecting whether the secondary regional stamp is warm or active.
