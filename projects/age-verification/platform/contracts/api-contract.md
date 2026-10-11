# Gateway API Contract

The gateway is the public application interface behind Front Door. It must never decrypt the image.

## `GET /health`

Infrastructure health only. Never call the model with real user data.

## `GET /ready`

Returns readiness of dependencies without returning secrets.

## `GET /v1/crypto/public-key`

Returns the currently active payload-encryption public key metadata required by the client.

Example:

```json
{
  "kid": "https://<vault>.vault.azure.net/keys/payload-encryption/<version>",
  "alg": "RSA-OAEP-256",
  "kty": "RSA",
  "n": "base64url-modulus",
  "e": "AQAB",
  "expiresAt": "2026-10-10T21:00:00Z"
}
```

Never return private-key material.

## `POST /v1/session`

Creates a one-time short-lived verification session. Store only a random session ID/nonce hash and TTL in Redis.

Example response:

```json
{
  "sessionId": "opaque-random-value",
  "nonce": "base64url-random-nonce",
  "expiresInSeconds": 120
}
```

## `POST /v1/verify`

Accepts only the encrypted envelope defined in `crypto-protocol.md`.

The gateway validates size/content type/session/nonce, marks the one-time session as consumed atomically, and forwards ciphertext to the private inference app.

Successful response:

```json
{
  "approved": true,
  "attestation": "<signed compact token>"
}
```

The token must not contain estimated age, biometric data, image hashes, or identity data. TTL should be short and audience-bound.

## Response headers

Verification/session/public-key responses should include:

```http
Cache-Control: no-store, no-cache, max-age=0
Pragma: no-cache
Content-Security-Policy: default-src 'self'; frame-ancestors 'none'
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
```
