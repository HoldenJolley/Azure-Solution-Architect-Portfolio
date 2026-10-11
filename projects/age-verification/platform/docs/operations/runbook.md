# Operations Runbook

## Verification failures

1. Check Front Door health/origin status.
2. Check gateway/inference readiness and replica count.
3. Check Key Vault crypto error metrics.
4. Check Redis connectivity/session failures.
5. Check model revision and recent deployment.
6. Do **not** enable request-body logging to troubleshoot.

## Suspected image persistence

1. Disable/route away verification traffic.
2. Preserve existing infrastructure/security logs.
3. Identify whether application logs, `/tmp`, external endpoints, crash dumps, or telemetry captured data.
4. Stop affected revisions.
5. Rotate cryptographic keys if compromise is plausible.
6. Perform privacy incident response and legal notification analysis.
7. Fix code/tests before restoring service.

## Key rotation

Follow `architecture/key-management.md`. Rotate through new versions, update published public key/JWKS, preserve a minimal overlap window, then remove the old version from application allowlists.

## Model rollback

Deploy the previous approved immutable inference image. Keep gateway protocol backwards compatible across a controlled model rollback window.
