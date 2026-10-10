# Definition of Done

## Infrastructure

- [ ] Foundation Bicep builds without errors.
- [ ] Workload Bicep builds without errors.
- [ ] Azure `what-if` reviewed before production deployment.
- [ ] Front Door Premium is the only public ingress.
- [ ] Front Door Private Link to Container Apps is approved.
- [ ] Container Apps environment public network access is disabled.
- [ ] Inference app has internal ingress only.
- [ ] Key Vault public network access is disabled.
- [ ] ACR public network access is disabled.
- [ ] Managed Redis public network access is disabled.
- [ ] Private DNS resolves Key Vault, ACR, and Redis to private addresses.
- [ ] Managed identities are used for runtime Azure access.
- [ ] ACR admin account is disabled.
- [ ] Redis access-key authentication is disabled.

## Privacy

- [ ] Browser/device strips metadata before encryption.
- [ ] Image is AES-256-GCM encrypted before network transmission.
- [ ] Session key is wrapped with RSA-OAEP-256.
- [ ] Gateway never decrypts the image.
- [ ] Inference decrypts only in memory.
- [ ] No image bytes are written to disk, queue, blob, database, cache, trace, or logs.
- [ ] Request/response-body logging is disabled.
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
- [ ] Verification endpoint rate limit configured.
- [ ] Key rotation procedure tested.
- [ ] Container image provenance/scanning enabled.
- [ ] Dependency/SAST scanning enabled.
- [ ] Load, abuse, malformed-ciphertext, and oversized-request tests pass.
- [ ] Region outage and key-vault dependency scenarios documented/tested.
- [ ] Privacy incident runbook reviewed.
- [ ] Application telemetry reviewed for accidental sensitive fields.

## Governance

- [ ] Model-card / model-governance documentation exists.
- [ ] Threshold and uncertainty policy approved by product/legal stakeholders.
- [ ] Liveness strategy documented if the use case requires spoof resistance.
- [ ] Data-protection impact assessment completed where required.
- [ ] Retention statement matches deployed behavior.
