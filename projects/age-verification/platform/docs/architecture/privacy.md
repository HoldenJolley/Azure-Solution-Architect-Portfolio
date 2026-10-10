# Privacy Architecture

## Data inventory

| Data | Storage | Retention | Purpose |
|---|---|---:|---|
| Plaintext image | None | request lifetime | AI inference only |
| Ciphertext image | None | request lifetime | transport only |
| AES session key | None | request lifetime | payload decryption |
| RSA private key | Key Vault/HSM | key lifecycle | unwrap/sign |
| Session/nonce hash | Managed Redis | ~2 minutes | anti-replay |
| Binary decision | caller/token | short TTL | age gate |
| Model version | telemetry | operational retention | audit/debug |
| Latency/status | telemetry | operational retention | reliability |

## Privacy engineering controls

- Metadata stripping before upload.
- Resolution reduction before upload.
- No exact-age response.
- No reusable face embedding.
- No image storage account.
- Body logging prohibited.
- Short-lived session state.
- No cacheable verification response.
- Separate model-governance responsibility.

## Verification vs identity

The architecture performs age assurance. It does not identify the person and should not add identity matching unless the product requirement genuinely needs it and a new privacy review is completed.
