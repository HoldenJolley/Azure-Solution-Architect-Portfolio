# Privacy Contract

## Promise

The platform is designed so a verification image is never intentionally stored.

### The platform MAY process

- encrypted image bytes in transit;
- plaintext image bytes transiently in inference-process memory;
- a model output long enough to derive a binary decision;
- a one-time session identifier/nonce hash;
- the final approved/denied decision when needed to create a signed attestation;
- operational metrics that do not contain image content or biometric templates.

### The platform MUST NOT retain

- source images;
- decrypted image bytes;
- encrypted image payloads;
- face crops;
- facial embeddings;
- biometric templates;
- estimated age values;
- EXIF/GPS metadata;
- model input tensors after request completion;
- cryptographic session keys;
- request or response bodies in logs/traces.

## Data minimization

The client should strip metadata and re-encode/resize the image before encryption. The default integration contract recommends a maximum 512x512 frame and a strict request-size limit.

The inference adapter should immediately map model output to `approved` or `denied`. Exact estimated age and confidence may be used transiently for decision logic but must not be returned or persisted unless the customer deliberately changes this privacy contract.

## Logging

Allowed examples:

- request/correlation ID;
- timestamp;
- route/status code;
- processing latency;
- model version identifier;
- decision category if business policy permits;
- coarse failure category;
- region and revision.

Prohibited examples:

- request body;
- ciphertext blob;
- wrapped session key;
- raw model output;
- image hashes that could become linkable biometric identifiers;
- full IP address when it is not operationally required.

## Caching

Verification routes and responses must set `Cache-Control: no-store`. Front Door caching is not enabled by this landing zone.

## Backups

There is no image datastore to back up. Platform backups/DR cover configuration, keys according to Key Vault protections, container images, and infrastructure definitions—not user photographs.
