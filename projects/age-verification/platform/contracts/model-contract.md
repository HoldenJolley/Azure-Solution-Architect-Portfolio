# Customer Model / Inference Contract

This landing zone deliberately does not ship an age-estimation model. The customer's inference container owns model execution and must implement the privacy boundary.

## Required behavior

- Listen on the configured `inferencePort`.
- Provide `GET /health` and `GET /ready`.
- Accept encrypted verification envelopes from the gateway only.
- Authenticate to Key Vault with the assigned managed identity.
- Decrypt only in process memory.
- Never write image bytes, face crops, tensors, embeddings, or raw age estimates to persistent storage or logs.
- Return only a binary policy result plus a signed attestation or the fields needed to create one.
- Respect cancellation/timeouts and clear request-scoped buffers on all success/failure paths.

## Model interface inside the container

The application may use any model/framework, but should normalize it to a narrow internal interface such as:

```text
Estimate(frame) -> {
  estimatedAge: transient number,
  uncertainty: transient number,
  quality: transient quality signal
}
```

The application policy layer—not the raw model—maps that output to:

```text
APPROVED | DENIED | INDETERMINATE
```

For a binary external API, `INDETERMINATE` should normally fail closed (`DENIED`) or route to an alternate age-verification method.

## Model governance requirements

Document:

- source/license and provenance;
- model version/hash;
- intended population and limitations;
- performance around the configured threshold;
- demographic error analysis/fairness testing;
- image-quality requirements;
- spoof/liveness assumptions;
- threshold/safety margin;
- rollback process;
- release approval record.

## No embeddings

The reference architecture does not require face recognition or identity matching. Do not create or retain a reusable facial embedding simply to perform age assurance.
