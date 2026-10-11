# Key Management

Two Key Vault keys are created:

1. `payload-encryption` — RSA-HSM, used to unwrap per-request AES keys.
2. `decision-attestation` — RSA-HSM, used to sign short-lived decision attestations.

## Runtime access

Only the inference managed identity has Key Vault Crypto User at the vault scope. Application code authenticates using managed identity.

## Rotation

- Create a new key version.
- Advertise only the newest public encryption-key version to clients.
- Continue accepting the immediately previous version for no longer than the maximum session lifetime plus clock skew.
- Remove old versions from the application's allowlist.
- Rotate the attestation key with overlapping verifier trust/JWKS publication.

## Compromise response

If a key compromise is suspected:

1. stop issuing new sessions;
2. create/activate replacement key versions;
3. revoke acceptance of compromised versions;
4. invalidate outstanding sessions/attestations where technically possible;
5. preserve security logs;
6. perform privacy/security incident review.
