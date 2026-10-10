# Deployment Guide

## Prerequisites

- Azure subscription.
- Azure CLI and Bicep.
- Permission to create resource groups, role assignments, private endpoints, Front Door, Container Apps, ACR, Key Vault, and Redis.
- Docker/BuildKit or another OCI build system for customer images.

## 1. Validate

```powershell
./scripts/validate.ps1 -Environment dev -RunWhatIf
```

## 2. Deploy foundation

```powershell
./scripts/deploy-foundation.ps1 -Environment dev
```

Capture outputs for ACR and Key Vault.

## 3. Build/push customer workloads

Push gateway and inference images to the returned ACR. ACR is private; a build runner must have network access to its private endpoint, or use an approved Azure build approach that can reach the registry.

## 4. Deploy workloads

```powershell
./scripts/deploy-workloads.ps1 \
  -Environment dev \
  -GatewayImage '<acr>.azurecr.io/age-gateway:1.0.0' \
  -InferenceImage '<acr>.azurecr.io/age-inference:1.0.0'
```

## 5. Approve Front Door Private Link

```powershell
./scripts/approve-frontdoor-private-link.ps1 -Environment dev
```

Confirm the Front Door origin becomes healthy.

## 6. Validate privacy behavior

Run the tests in `docs/testing.md` before any production promotion.

## Production

- use immutable image tags/digests;
- WAF Prevention mode;
- minimum two replicas;
- protected GitHub environment;
- manual approval on infrastructure and model release;
- egress control extension where required;
- enable confidential compute only in a supported region and after validating capacity/cost.
