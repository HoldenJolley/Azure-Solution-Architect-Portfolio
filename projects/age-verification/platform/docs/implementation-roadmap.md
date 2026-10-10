# Implementation Roadmap

## Phase 1 — Landing zone

- Bicep foundation/workload templates.
- Front Door/WAF/Private Link.
- private Container Apps environment.
- Key Vault/ACR/Managed Redis/private DNS.
- managed identities and observability.

## Phase 2 — Gateway

- browser/device encryption helper;
- public-key endpoint;
- short-lived sessions;
- strict envelope validation;
- anti-replay state;
- private inference forwarding;
- no-store headers.

## Phase 3 — Customer inference adapter

- Key Vault unwrap/sign;
- in-memory decrypt/preprocessing;
- model adapter contract;
- threshold/indeterminate policy;
- buffer disposal;
- signed decision attestation.

## Phase 4 — Security assurance

- privacy test harness;
- WAF/load/abuse testing;
- supply-chain scanning/signing;
- egress restriction;
- Defender posture review;
- confidential compute where supported/required.

## Phase 5 — Product assurance

- liveness/anti-spoof layer;
- model card/fairness report;
- DPIA/legal review;
- accessibility/fallback verification path;
- regional DR if business RTO requires it.
