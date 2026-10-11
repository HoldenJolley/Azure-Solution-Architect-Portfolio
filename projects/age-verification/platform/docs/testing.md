# Test Strategy

## Privacy tests

1. Upload a known marker image and prove no marker/image bytes appear in Log Analytics/Application Insights.
2. Search container logs for base64 fragments/ciphertext field names.
3. Inspect Redis keys and prove only opaque session/nonce state exists with TTL.
4. Verify no storage/file-share resources are provisioned for verification data.
5. Restart replicas and confirm no verification image is recoverable.
6. Force exceptions at each pipeline step and confirm request buffers are not serialized to logs.

## Crypto/security tests

- altered GCM ciphertext is rejected;
- altered AAD is rejected;
- unknown/retired `kid` is rejected;
- expired session rejected;
- reused nonce/session rejected atomically;
- oversized request rejected before model invocation;
- malformed base64/JSON rejected;
- direct ACA origin is unreachable from Internet;
- direct inference app is unreachable externally;
- Key Vault/ACR/Redis public endpoints are disabled;
- gateway identity cannot unwrap/sign with Key Vault;
- inference identity can perform only intended crypto operations.

## Model tests

- threshold boundary performance;
- image-quality failure behavior;
- demographic/fairness evaluation;
- spoof/photo/screen attack behavior;
- adversarial/invalid-image behavior;
- deterministic model version reporting;
- fail-closed indeterminate decision.

## Load/resilience

- concurrent sessions;
- WAF rate-limit activation;
- replica scale-out;
- Redis transient failure;
- Key Vault throttling/transient failure;
- model timeout;
- container restart mid-request;
- zone-level failure where testable.
