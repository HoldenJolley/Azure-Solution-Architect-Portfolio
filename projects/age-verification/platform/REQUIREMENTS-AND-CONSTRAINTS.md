# Requirements and Constraints

This document is the architecture review entry point for the privacy-preserving AI age-assurance landing zone. It captures the privacy invariant, hard technical constraints, non-goals, integration boundaries, and the conditions that should trigger a redesign. Detailed service-level decisions live in `docs/decisions/`.

## Architecture objective

Provide a reusable Azure execution boundary for age-assurance workloads where organizations bring their own gateway and inference containers while the platform supplies secure ingress, network isolation, cryptographic key management, short-lived anti-replay state, monitoring, and Infrastructure as Code.

The reusable artifact is the secure landing zone and integration contract, not a specific age-estimation model.

## Non-negotiable privacy invariant

The source verification image is never intentionally persisted by the platform.

Plaintext image bytes are permitted only in:

1. browser/device memory before encryption; and
2. inference-process memory after decryption and before immediate disposal.

The platform must not intentionally store plaintext images, ciphertext images, reusable face embeddings, inference tensors, session keys, or raw model outputs in application persistence or logs.

## Functional requirements

- The client strips unnecessary metadata and reduces the image before upload.
- The client encrypts the image locally with a fresh AES-256-GCM key.
- The one-time AES key is wrapped with the platform RSA public key using RSA-OAEP-256.
- Azure Front Door Premium + WAF is the public ingress boundary.
- The verification payload remains ciphertext through the edge and gateway.
- The gateway reaches a private Container Apps inference boundary.
- Only the inference process can unwrap the image key and hold plaintext image bytes.
- The external result is a short-lived signed approval / denial attestation rather than a raw age estimate.
- One-time session / nonce state is short-lived and used only to prevent replay.
- Customer-supplied gateway and inference images implement the documented contracts.

## Non-functional requirements

### Privacy

- Do not provision an image datastore.
- Do not log request bodies or image-derived sensitive artifacts.
- Keep externally disclosed data to the minimum required decision.
- Treat age assurance as distinct from identity verification.

### Security

- Keep origins private; the intended ingress path is Front Door to Container Apps over Private Link.
- Use managed identities and Azure RBAC instead of reusable service credentials where supported.
- Keep private cryptographic keys in Key Vault Premium / HSM-backed key material.
- Disable Redis access-key authentication in favor of Entra-based access.
- Fail closed when required security dependencies or model health are unavailable.

### Reliability

- Production profiles should run multiple gateway / inference replicas and use a zone-redundant Container Apps environment where supported by the selected profile.
- Redis unavailability blocks new one-time verification sessions unless a separately reviewed stateless design exists.
- Key Vault unavailability prevents decryption/signing and therefore verification.
- Model readiness failures must prevent successful verification rather than silently bypassing the check.

### Operability

- Foundation and workload infrastructure are split to avoid a bootstrap dependency on container images that do not yet exist.
- Dev, test, and production Bicep parameter sets must compile.
- Monitoring must capture operational status without recording verification images or sensitive request bodies.
- Model version and operational telemetry may be retained for audit/debug purposes according to the documented privacy contract.

## Current design constraints

### The AI model is customer-supplied

This repository does not contain a production age-estimation model and does not claim that an arbitrary customer model is accurate, unbiased, compliant, or legally sufficient proof of age. Model selection, thresholding, testing, fairness, accessibility, legal review, and jurisdiction-specific requirements remain separate responsibilities.

### Client code is part of the cryptographic protocol

Because encryption begins on the device, browser/mobile SDK code participates in the security protocol. Interoperability, versioning, key rotation, malformed-request handling, and client downgrade behavior require testing; TLS alone is not the only protection layer.

### Liveness is not provided by infrastructure

If the product requires anti-spoofing / liveness checks, those belong in the customer workload and model contract. The landing zone alone does not provide them.

### Customer code can violate the privacy invariant

The platform can remove storage services and constrain network/identity paths, but it cannot technically prevent malicious or defective customer code from writing plaintext to its own filesystem or exfiltrating it. Code review, container controls, egress design, contract tests, and operational governance are required.

### Managed Redis availability is subscription- and region-dependent

Live portfolio preflight found the intended low-tier Managed Redis capacity unavailable for the current subscription / target region, so the deterministic dev What-If profile temporarily disables the session store. Redis remains part of the production architecture and compiler-validated test/prod profiles. An actual deployment must confirm capacity or select a deliberately reviewed alternative tier/region.

### Confidential compute is optional

Container Apps confidential-compute support is region/profile dependent. The normal production profile uses dedicated workload profiles; a high-assurance deployment can move to an explicitly supported confidential-compute option when the requirement and regional availability justify it.

### The baseline stateful inference plane is single-region

The default design does not claim active-active multi-region verification. Adding a second regional stamp requires deterministic key/version handling, session-state semantics, model synchronization, routing, and attestation trust across regions.

### Workload ARM validation depends on the foundation

`workloads.bicep` references foundation-created resources and customer-supplied images. The live dev control-plane preflight therefore validates the foundation first; workload-level ARM validation is intentionally sequenced after the foundation exists and valid images are available.

### Some role assignments cannot be fully resolved by What-If

Managed-identity principal IDs are assigned during resource creation. Identity-dependent role assignments can therefore appear as unsupported during pre-deployment What-If even when their Bicep compiles correctly.

## Non-goals

This landing zone does not attempt to:

- prove a person's legal identity;
- retain verification images for future reuse;
- expose exact model age estimates to callers;
- bundle a production age-estimation model;
- make legal/compliance claims for a specific jurisdiction;
- guarantee model fairness or threshold accuracy;
- prevent all malicious behavior inside customer-controlled workload code;
- claim multi-region availability before the state/key/session semantics are explicitly designed and tested.

## Decision rules and redesign triggers

| Trigger | Architecture response |
|---|---|
| Product requires liveness / anti-spoofing | Add an explicitly governed liveness capability to the workload/model contract and test its privacy implications. |
| Product requires identity matching, not age assurance | Perform a new privacy/security review; do not quietly extend this architecture into biometric identity. |
| Business RTO requires regional survival | Add an independent second regional stamp and design key, model-version, session-state, routing, and attestation consistency before calling the service multi-region. |
| High-assurance policy requires confidential compute | Select a supported confidential workload profile/region and validate runtime compatibility before enabling it. |
| Managed Redis capacity is unavailable in the deployment target | Select a reviewed alternative tier/region or redesign anti-replay state; do not silently remove replay protection from production. |
| A customer model needs broader network/data access | Revisit the trust boundary and privacy contract before expanding egress or persistence. |
| Jurisdiction-specific requirements change what may be collected, retained, or disclosed | Re-run legal/privacy architecture review and update the data lifecycle rather than treating IaC as proof of compliance. |

## Architecture decisions

The detailed “why this instead of that” reasoning is recorded in `docs/decisions/`:

- `ADR-001-client-side-envelope-encryption.md`
- `ADR-002-no-image-persistence.md`
- `ADR-003-container-apps.md`
- `ADR-004-bring-your-own-model.md`
- `ADR-005-managed-redis-session-state.md`
- `ADR-006-front-door-private-link.md`
- `ADR-007-confidential-compute.md`
- `ADR-008-signed-binary-attestation.md`

Also review `PRIVACY.md`, `SECURITY.md`, and `KNOWN-LIMITATIONS.md` for the current control boundary and production decisions.

## Validation boundary

Current evidence validates the infrastructure package, not end-to-end age-assurance behavior.

- Foundation/workload Bicep and dev/test/prod parameters compile.
- GitHub Actions authenticates to Azure through short-lived OIDC federation.
- The dev foundation completes a live ARM What-If without creating resources.
- The dev preflight intentionally omits Managed Redis because of live capacity constraints in the current target context.
- Identity-dependent RBAC resources may remain unsupported in What-If until deployment-time principal IDs exist.
- Workload ARM validation requires foundation-created resources and customer-supplied images.
- No age-assurance Azure resources have been deployed yet.

Runtime validation still requires deployed customer images, Private Link approval, cryptographic interoperability tests, privacy/logging tests, replay tests, model health/failure tests, and controlled recovery exercises.
