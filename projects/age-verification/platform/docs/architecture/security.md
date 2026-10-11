# Security Architecture

## Layered controls

### Edge

- Front Door Premium only public endpoint.
- WAF managed rules.
- Path-specific verification rate limiting.
- HTTPS redirect / HTTPS origin forwarding.
- Front Door caching not configured for verification traffic.

### Origin

- Private Container Apps environment.
- Front Door Private Link origin.
- No direct public network access to environment.
- Inference endpoint internal only.
- Environment peer mTLS and peer traffic encryption enabled.

### Identity

- User-assigned managed identities.
- No ACR admin account.
- No Redis access keys.
- Inference identity gets Key Vault Crypto User; gateway does not.

### Keys

- Key Vault Premium.
- HSM-backed RSA keys.
- Purge protection and 90-day soft delete.
- Public network access disabled.
- Versioned key IDs support rotation.

### Data

- Client-side AES-256-GCM.
- RSA-OAEP-256 wrapping.
- TLS in addition to payload encryption.
- No platform image storage.

## Fail-closed behavior

Verification must deny or return a non-success state when:

- session expired/replayed;
- payload exceeds limit;
- crypto authentication fails;
- key reference is invalid;
- model is unavailable;
- image quality/uncertainty is outside policy;
- attestation signing fails.
