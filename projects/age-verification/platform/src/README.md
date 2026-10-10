# Application Responsibilities

Infrastructure is intentionally model-agnostic. Implement two customer-owned images:

## Gateway image

- never decrypt image;
- publish public-key metadata;
- issue/consume one-time sessions;
- validate encrypted envelope and request limits;
- forward ciphertext to inference privately;
- return signed binary result;
- set `no-store` response headers;
- body logging disabled.

## Inference image

- authenticate with managed identity;
- unwrap AES key in Key Vault;
- decrypt and preprocess entirely in memory;
- run customer AI model;
- derive approved/denied/indeterminate;
- immediately dispose sensitive buffers;
- sign decision attestation in Key Vault;
- never persist/log image, tensor, embedding, raw age, or session key.

See `contracts/` for the detailed interface.
