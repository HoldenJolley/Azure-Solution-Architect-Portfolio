# Threat Model

## Assets

- user image;
- decrypted frame/tensor in memory;
- one-time AES key;
- Key Vault private keys;
- signed age-decision attestation;
- model artifact;
- session/replay state.

## Key threats and controls

| Threat | Primary controls |
|---|---|
| Network interception | TLS + client-side AES-GCM |
| Front Door/gateway compromise sees image | gateway handles ciphertext only |
| Payload tampering | AES-GCM authentication + AAD |
| Replay | short-lived session/nonce + atomic Redis consume |
| Direct origin bypass | ACA public access disabled + Front Door Private Link |
| Direct model access | internal-only inference ingress |
| Secret leakage | managed identities; Key Vault; no static app secrets |
| Private-key extraction | HSM-backed Key Vault key; nonexportable |
| Malicious/buggy logging | explicit no-body contract, telemetry review/tests |
| Disk persistence | application contract prohibits writes; no image datastore mounted |
| Exfiltration by model container | code/image supply-chain controls + recommended egress restriction extension |
| Forged approval | Key Vault-signed, audience/TTL/nonce-bound attestation |
| Adversarial/spoof image | liveness integration and model robustness testing |
| Threshold uncertainty | safety margin / fail-closed indeterminate policy |
| Model supply-chain compromise | signed/pinned images, scanning, provenance, release approval |

## Residual risk

Infrastructure cannot guarantee privacy if customer application code intentionally logs/exfiltrates data. Production assurance therefore requires code review, automated privacy tests, image provenance, and—where risk justifies it—network egress enforcement/confidential compute.
