# Client-Side Encryption Protocol

## Goals

- Protect image confidentiality beyond the TLS termination point.
- Ensure the gateway and Front Door handle only ciphertext.
- Bind each encrypted payload to a short-lived one-time session.
- Detect ciphertext modification.

## Client sequence

1. Capture a frame in memory.
2. Render/re-encode the frame to strip EXIF and unnecessary metadata.
3. Resize to the smallest resolution accepted by the customer model; recommended maximum 512x512.
4. Generate a fresh random 256-bit AES key with a cryptographically secure RNG.
5. Generate a fresh 96-bit GCM IV.
6. Construct authenticated additional data (AAD) from protocol version, session ID, nonce, audience, and timestamp.
7. Encrypt image bytes using AES-256-GCM.
8. Wrap the AES key with the platform RSA public key using RSA-OAEP-256.
9. Immediately discard the plaintext frame and local AES key after request construction.
10. Send the envelope over HTTPS.

## Envelope

```json
{
  "version": 1,
  "sessionId": "opaque",
  "nonce": "base64url",
  "kid": "key-version-uri",
  "alg": "RSA-OAEP-256",
  "enc": "A256GCM",
  "iv": "base64url",
  "wrappedKey": "base64url",
  "ciphertext": "base64url",
  "aad": "base64url",
  "capturedAt": "2026-10-10T20:00:00Z"
}
```

## Inference sequence

1. Reject unsupported protocol/algorithm/version before crypto operations.
2. Validate session/nonce/timestamp and strict payload-size limits.
3. Ask Key Vault to unwrap the session key using the referenced allowed key version.
4. AES-GCM decrypt in process memory using the exact AAD.
5. Reject authentication-tag failure without model invocation.
6. Decode/preprocess in memory.
7. Invoke the customer model.
8. Reduce model output to the policy decision.
9. Zero/release plaintext, key, tensors, model output, and intermediary buffers as far as the runtime permits.
10. Sign the short-lived binary-decision attestation with Key Vault.

## Rotation

Clients fetch the active public key before beginning a session. `kid` pins the request to a specific key version, allowing safe overlapping key rotation. The server accepts only approved active/previous key versions during the rotation grace period.
