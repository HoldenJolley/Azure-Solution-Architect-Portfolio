# ADR-008: Signed binary attestation

**Decision:** Externally disclose only a short-lived approved/denied result backed by an asymmetric signature.

**Rationale:** A raw browser boolean is forgeable, while exact model age/confidence is unnecessary data disclosure.

**Consequence:** Consumers must verify signature, audience, expiry, nonce/session binding, and key ID.
