# ADR-001: Client-side envelope encryption

**Decision:** Encrypt the re-encoded image on the device using a fresh AES-256-GCM key and wrap that key with the platform RSA public key using RSA-OAEP-256.

**Rationale:** TLS protects transport links, but payload encryption keeps Front Door and the gateway outside the plaintext trust boundary.

**Consequence:** Client SDK/browser code becomes part of the cryptographic protocol and needs interoperability/version tests.
