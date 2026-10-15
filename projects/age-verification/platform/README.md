# Privacy-Preserving AI Age Assurance Landing Zone

Production-oriented Azure landing zone for applications that need an AI age-assurance decision while minimizing exposure of the source image.

The platform assumes **the customer supplies its own gateway and inference container images**. The Azure layer provides secure ingress, client-side envelope-encryption support, isolated private inference, managed cryptographic keys, short-lived replay/session state, monitoring, network isolation, and deployment guardrails.

## Architecture review path

If you are reviewing this project as an architect or hiring manager, start here:

1. [`REQUIREMENTS-AND-CONSTRAINTS.md`](REQUIREMENTS-AND-CONSTRAINTS.md) — privacy invariant, hard constraints, non-goals, and redesign triggers.
2. [`docs/decisions/`](docs/decisions/) — ADRs explaining the major security/privacy/platform choices and their tradeoffs.
3. [`PRIVACY.md`](PRIVACY.md) and [`SECURITY.md`](SECURITY.md) — the data-handling and security contracts.
4. [`KNOWN-LIMITATIONS.md`](KNOWN-LIMITATIONS.md) — model, capacity, validation, and production-boundary limitations.
5. [`docs/architecture/`](docs/architecture/) — deeper trust-boundary, key-management, networking, observability, cost, and DR design.
6. [`PROJECT-CHECKLIST.md`](PROJECT-CHECKLIST.md) — definition of done and evidence boundary.

The intended review sequence is **requirements → trust boundaries → alternatives → decisions → tradeoffs → validation → remaining limitations**.

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

## Validation approach

The repository uses two validation layers:

1. Bicep lint/build and parameter compilation for the foundation and workload stages across dev, test, and prod.
2. A live Azure Resource Manager What-If of the dev foundation through GitHub Actions and secretless OIDC.

The dev cloud-preflight profile intentionally sets `deploySessionStore = false` and `useSessionStore = false`. Azure Managed Redis capacity is subscription- and region-dependent and both B0 and B1 returned live capacity/preflight failures during validation. Redis remains part of the production architecture and its Bicep is still lint/build validated; test/prod profiles retain the managed session-store design. This prevents a volatile capacity condition from turning the portfolio's non-deploying ARM preflight into a false signal about template quality.

Workload-level ARM validation is intentionally sequenced after foundation deployment because `workloads.bicep` references foundation-created resources and customer-supplied container images. No resources are created by the What-If workflow.

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

- [`REQUIREMENTS-AND-CONSTRAINTS.md`](REQUIREMENTS-AND-CONSTRAINTS.md)
- [`PRIVACY.md`](PRIVACY.md)
- [`SECURITY.md`](SECURITY.md)
- [`docs/architecture/threat-model.md`](docs/architecture/threat-model.md)
- [`contracts/crypto-protocol.md`](contracts/crypto-protocol.md)
- [`contracts/model-contract.md`](contracts/model-contract.md)
- [`KNOWN-LIMITATIONS.md`](KNOWN-LIMITATIONS.md)
- [`PROJECT-CHECKLIST.md`](PROJECT-CHECKLIST.md)

## Important limitation

This is an infrastructure landing zone and integration contract. It does **not** claim that a customer-supplied AI model is legally sufficient proof of age, unbiased, accurate around a statutory threshold, or compliant with a specific jurisdiction. Those are model/product/legal responsibilities that must be validated separately.
