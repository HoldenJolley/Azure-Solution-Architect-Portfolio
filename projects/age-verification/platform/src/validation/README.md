# Temporary runtime validation workload

This directory contains a deliberately small synthetic workload used only to validate the age-assurance Azure architecture at runtime.

It is **not** an age-estimation model and must not be described as one. The inference container accepts an encrypted synthetic payload, unwraps the data key with the HSM-backed Key Vault key, decrypts only in memory, computes a deterministic validation result, signs the result with the HSM-backed attestation key, and discards plaintext. The gateway never receives plaintext.

The smoke test validates:

- Azure Front Door reaches the private Container Apps gateway through the approved private-link origin.
- The gateway reaches the internal inference service.
- A client can obtain the public encryption key through the service without receiving private key material.
- AES-256-GCM payload encryption and RSA-OAEP-256 key wrapping complete end to end.
- The inference managed identity can use Key Vault cryptographic operations without key material leaving Key Vault.
- The returned synthetic decision is HSM-signed.
- A repeated nonce is rejected by the single-replica dev validation gateway.
- The internal gateway is not directly reachable from the public GitHub runner.
- No image or request body is intentionally persisted or emitted to logs by the validation workload.

## Important boundary

The dev validation profile intentionally disables the distributed Redis session store and confidential-compute profile to keep the temporary exercise practical and cost-controlled. Replay rejection in this harness is therefore local to the single gateway replica and is not evidence of distributed replay protection. The test also provides no evidence about model accuracy, fairness, legal sufficiency, or production capacity.

## Registry bootstrap

The architecture keeps Azure Container Registry private. For this short-lived validation exercise, the GitHub workflow temporarily enables ACR public network access only long enough to authenticate with Entra ID and push the two synthetic validation images. The registry remains admin-disabled and anonymous pull remains disabled. The workflow then disables public network access again **before** the Container Apps workload Deployment Stack is created and verifies that the registry returned to the private state.

That bootstrap exception is part of the validation procedure, not the target production architecture.
