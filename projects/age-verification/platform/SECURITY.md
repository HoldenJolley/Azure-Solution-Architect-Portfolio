# Security Policy

## Security objectives

1. Prevent public access to the workload origin and platform data services.
2. Keep the image encrypted beyond TLS until it reaches the inference trust boundary.
3. Use managed identities rather than application secrets.
4. Keep cryptographic private keys in Azure Key Vault.
5. Prevent replay of verification requests with short-lived session state.
6. Avoid image/body capture in telemetry.
7. Keep inference private and inaccessible from the Internet.
8. Make production changes through reviewed Infrastructure as Code.

## Cryptography

- Transport: HTTPS/TLS only.
- Payload: AES-256-GCM generated per verification session.
- Key wrapping: RSA-OAEP-256 public-key wrapping.
- Attestation: asymmetric signing key in Key Vault; exact algorithm is application-contract controlled.
- Session material must expire and must never be written to durable application storage.

## Identities

Separate user-assigned managed identities are provisioned for:

- gateway runtime;
- inference runtime;
- ACR image pull.

Only the inference identity receives Key Vault cryptographic permissions. Gateway and inference identities receive Redis access for short-lived session/replay state.

## Vulnerability management

Customer images should be pinned by digest or immutable version tag in production. Container-image scanning, dependency scanning, SAST, and model artifact provenance should be part of the application CI pipeline.

## Incident response

If image persistence is suspected, treat it as a privacy incident. Immediately disable verification traffic, preserve infrastructure/security logs without collecting new image bodies, identify the persistence path, rotate affected keys where appropriate, and follow the organization's privacy/breach process.
