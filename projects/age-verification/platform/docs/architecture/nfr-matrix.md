# Non-Functional Requirements Matrix

This matrix connects the age-assurance landing-zone design to the quality attributes it is intended to satisfy. It distinguishes **architectural intent** from **validated evidence** and from behavior that still requires a deployed workload.

| Quality attribute | Requirement / constraint | Design response | Current evidence | Remaining validation |
|---|---|---|---|---|
| Privacy | Verification imagery must not become a durable platform asset | Client-side envelope encryption; no image datastore; plaintext limited to client/inference memory; logs must exclude image-derived payloads | Privacy contract, diagrams, Bicep, and architecture docs are source-controlled | Deploy workloads and test logs, telemetry, crash paths, storage, and application behavior for accidental persistence |
| Confidentiality | Edge/gateway components should not require plaintext image access | AES-256-GCM payload encryption with RSA-OAEP-256 key wrapping; Front Door and gateway operate on ciphertext | Crypto contract and architecture are documented | Run interoperability and negative-path tests with actual gateway/inference implementations |
| Key protection | Private cryptographic material must remain in managed key infrastructure | Key Vault Premium / HSM-backed RSA keys; managed identity performs unwrap/sign operations | Key infrastructure and RBAC are compiler/control-plane modeled | Deploy and verify effective RBAC, key operations, rotation/version behavior, and denied unauthorized access |
| Network isolation | Public traffic must not directly reach inference/data-plane dependencies | Front Door Premium + WAF; Private Link to internal Container Apps; private endpoints/DNS for Key Vault, ACR, and Managed Redis | Foundation/workload templates compile; foundation What-If succeeds | Deploy and verify origin privacy, DNS resolution, private endpoint approvals, and blocked public paths |
| Replay resistance | Verification sessions must not be reusable beyond their intended short lifetime | Managed Redis stores opaque TTL-bound nonce/session state; fail closed if required replay state is unavailable | Architecture/ADR documented; Redis modeled in test/prod | Confirm target-region Managed Redis capacity, deploy, and test duplicate/replayed/expired requests |
| Availability | Replica failures should not automatically take down a healthy regional service | Multiple gateway/inference replicas and zone-redundant Container Apps production profile; Front Door global edge | Architecture and production parameters are modeled | Deploy and exercise gateway/inference replica failures plus readiness behavior |
| Fail-closed security | Uncertainty in security-critical dependencies must not silently approve a request | Key Vault unavailable → no verification; Redis unavailable → fail closed; unhealthy model → readiness failure / unavailable result | Failure behavior documented | Inject dependency failures after deployment and confirm responses/telemetry |
| Regional resilience | Baseline must be honest about regional failure rather than imply active-active behavior | Default stateful inference plane is single-region; multi-region is an explicit extension requiring coordinated key/session/model semantics | Limitation and DR design documented | Define business RTO, implement second stamp only if required, then test failover |
| Data minimization | External consumers should receive the minimum useful result | Raw age estimate is converted to approved/denied/indeterminate; signed short-lived attestation; no reusable face embedding by design | Contracts/privacy docs exist | Validate actual customer model integration and response payloads |
| Observability | Operators need reliability/security signals without leaking sensitive payloads | Application Insights + Log Analytics for metadata/health/latency; body/image logging prohibited | Monitoring resources/config are modeled | Verify telemetry fields and retention; test that bodies, images, tensors, embeddings, and raw age outputs do not enter logs |
| Model isolation | Platform security controls must not be confused with model suitability | Bring-your-own model contract isolates infrastructure responsibility from model fairness/accuracy/legal suitability | Boundary documented in ADRs/contracts | Customer must validate model accuracy, threshold behavior, fairness, accessibility, liveness, and legal suitability separately |
| Deployability | Private infrastructure and customer workloads need a deterministic bootstrap sequence | Foundation Bicep first, customer images second, workloads third, then Front Door Private Link approval | Foundation/workload compile; dev foundation What-If succeeds | Execute staged deployment and capture post-deploy evidence |
| Capacity portability | Regional service capacity can change independently of template quality | Dev cloud-preflight disables Managed Redis after live B0/B1 capacity failures while test/prod keep the intended production design | Live capacity issue is documented; Redis remains compiler validated | Confirm an acceptable tier/region before real deployment or document an explicitly reviewed alternative |
| Cost | Higher-assurance controls should be selected intentionally rather than hidden as “free” | Premium edge/registry/key services and optional confidential compute are documented architecture choices | Cost documentation exists | Estimate/measure actual monthly cost for the chosen deployment profile before production adoption |

## RTO/RPO stance

Verification images are intentionally nonpersistent, so there is no recovery objective for restoring stored image data. Service **RTO** remains a business requirement. The current single-region baseline must not be described as regionally resilient until a second regional stamp and the associated key/session/model semantics are designed and tested.

## Review questions

A reviewer should be able to challenge this matrix with questions such as:

- Exactly where can plaintext exist?
- What happens if Key Vault or Redis is unavailable?
- How is replay prevented across horizontally scaled gateway replicas?
- Which controls protect the platform, and which responsibilities remain with the customer-supplied model?
- What must change before a multi-region claim is credible?
- Which privacy claims still need runtime proof?
