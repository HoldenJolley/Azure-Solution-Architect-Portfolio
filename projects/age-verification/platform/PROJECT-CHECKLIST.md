# Definition of Done

Items are checked only when the current repository and Azure validation evidence support them. Deployment/runtime controls stay open until the landing zone and customer workloads are actually exercised.

## Infrastructure and cloud validation

- [x] Foundation Bicep lints/builds without errors.
- [x] Workload Bicep lints/builds without errors.
- [x] Dev/test/prod foundation and workload parameter files compile.
- [x] GitHub OIDC authenticates to Azure without a client secret.
- [x] Dev foundation Azure Resource Manager `what-if` reviewed successfully.
- [x] Dev What-If resolves the foundation with only deployment-time managed-identity RBAC IDs remaining unsupported.
- [x] Azure Managed Redis B0/B1 capacity limitation discovered and documented through live preflight.
- [ ] Production foundation `what-if` reviewed before production deployment.
- [ ] Foundation deployed from a clean target state.
- [ ] Workload-level ARM validation completed after foundation deployment and image publication.
- [ ] Front Door Private Link to Container Apps approved and verified.
- [ ] Container Apps environment public network access verified disabled after deployment.
- [ ] Inference app internal-only ingress verified after deployment.
- [ ] Key Vault public network access verified disabled after deployment.
- [ ] ACR public network access verified disabled after deployment.
- [ ] Managed Redis public network access verified disabled in a target region with capacity.
- [ ] Private DNS resolution verified for Key Vault, ACR, and Redis.
- [ ] Managed identities verified for runtime Azure access.
- [ ] ACR admin account verified disabled.
- [ ] Redis access-key authentication verified disabled.

## Privacy

- [ ] Browser/device strips metadata before encryption.
- [ ] Image is AES-256-GCM encrypted before network transmission.
- [ ] Session key is wrapped with RSA-OAEP-256.
- [ ] Gateway never decrypts the image.
- [ ] Inference decrypts only in memory.
- [ ] No image bytes are written to disk, queue, blob, database, cache, trace, or logs.
- [ ] Request/response-body logging is disabled in deployed workloads.
- [ ] Verification responses include `Cache-Control: no-store`.
- [ ] Raw estimated age is discarded after deriving policy decision.
- [ ] Redis session keys expire automatically.
- [ ] Replay test passes.

## Application contract

- [ ] `GET /v1/crypto/public-key` returns only the active public key metadata.
- [ ] `POST /v1/session` issues a short-lived one-time session.
- [ ] `POST /v1/verify` accepts only the encrypted envelope.
- [ ] Inference model implements `/health`, `/ready`, and the model contract.
- [ ] Health endpoints never exercise or log real verification data.
- [ ] Signed attestation can be independently verified.
- [ ] Attestation contains no biometric data or estimated age.

## Security and resilience

- [ ] WAF managed rules enabled in Prevention mode for production.
- [ ] Verification endpoint rate limit tested.
- [ ] Key rotation procedure tested.
- [ ] Container image provenance/scanning enabled.
- [ ] Dependency/SAST scanning enabled.
- [ ] Load, abuse, malformed-ciphertext, and oversized-request tests pass.
- [ ] Region outage and key-vault dependency scenarios tested.
- [ ] Privacy incident runbook reviewed in an operational exercise.
- [ ] Application telemetry reviewed for accidental sensitive fields.

## Governance

- [ ] Model-card / model-governance documentation exists for the customer-supplied model.
- [ ] Threshold and uncertainty policy approved by product/legal stakeholders.
- [ ] Liveness strategy documented if the use case requires spoof resistance.
- [ ] Data-protection impact assessment completed where required.
- [ ] Retention statement verified against deployed workload behavior.
