# Privacy-Preserving AI Age Assurance Landing Zone

Production-oriented Azure landing zone for applications that need an AI age-assurance decision while minimizing exposure of the source image.

The platform assumes **the customer supplies its own gateway and inference container images**. The Azure layer provides secure ingress, client-side envelope-encryption support, isolated private inference, managed cryptographic keys, short-lived replay/session state, monitoring, network isolation, and deployment guardrails.

## Core privacy invariant

The source image is never intentionally persisted by the platform.

Plaintext image bytes are permitted only in:

1. browser/device memory before encryption; and
2. inference-process memory after decryption and before immediate disposal.

The platform does **not** provision Blob Storage, databases, queues, file shares, or other persistence for verification images.

## Reference flow

```text
Browser / mobile client
  -> strip metadata + resize
  -> generate one-time AES-256-GCM key
  -> encrypt image locally
  -> wrap AES key with platform RSA public key
  -> TLS
  -> Azure Front Door Premium + WAF
  -> Private Link
  -> private Azure Container Apps environment
  -> Gateway (ciphertext only)
  -> private Inference App
  -> Key Vault unwrap in memory
  -> customer age model
  -> map model output to approved/denied
  -> destroy plaintext buffers
  -> signed short-lived attestation
```

## What this repository deploys

- Azure Front Door Premium and WAF
- Private Link from Front Door to Azure Container Apps
- VNet-integrated, internal Container Apps workload-profile environment
- External-facing gateway app reachable only through Front Door Private Link
- Internal-only inference app
- Azure Key Vault with RSA encryption and attestation-signing keys
- Azure Container Registry Premium with public access disabled
- Azure Managed Redis for short-lived replay/session state, with access-key authentication disabled
- User-assigned managed identities and least-privilege RBAC
- Private endpoints and Private DNS for Key Vault, ACR, and Managed Redis
- Log Analytics and Application Insights
- Optional confidential-compute workload profile for supported regions
- Dev/test/prod parameter profiles
- GitHub Actions/OIDC validation workflow

## Deployment model

The deployment is intentionally split:

1. `infra/foundation.bicep` creates the secure landing zone and private platform dependencies.
2. Push your own gateway and inference images to the provisioned ACR.
3. `infra/workloads.bicep` deploys the applications and Front Door/WAF.

This avoids a bootstrap dependency where Container Apps references images that do not exist yet.

## Start here

```powershell
./scripts/validate.ps1 -Environment dev
./scripts/deploy-foundation.ps1 -Environment dev
```

Push your images to the ACR returned by the foundation deployment, then:

```powershell
./scripts/deploy-workloads.ps1 \
  -Environment dev \
  -GatewayImage '<acr>.azurecr.io/age-gateway:1.0.0' \
  -InferenceImage '<acr>.azurecr.io/age-inference:1.0.0'
```

After Front Door creates its private-link request:

```powershell
./scripts/approve-frontdoor-private-link.ps1 -Environment dev
```

## Security posture

See:

- [`PRIVACY.md`](PRIVACY.md)
- [`SECURITY.md`](SECURITY.md)
- [`docs/architecture/threat-model.md`](docs/architecture/threat-model.md)
- [`contracts/crypto-protocol.md`](contracts/crypto-protocol.md)
- [`contracts/model-contract.md`](contracts/model-contract.md)
- [`PROJECT-CHECKLIST.md`](PROJECT-CHECKLIST.md)

## Important limitation

This is an infrastructure landing zone and integration contract. It does **not** claim that a customer-supplied AI model is legally sufficient proof of age, unbiased, accurate around a statutory threshold, or compliant with a specific jurisdiction. Those are model/product/legal responsibilities that must be validated separately.
