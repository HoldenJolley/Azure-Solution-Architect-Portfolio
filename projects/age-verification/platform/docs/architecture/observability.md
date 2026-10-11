# Observability

## Allowed telemetry

- request ID/correlation ID;
- endpoint name/status code;
- duration;
- model version;
- container revision;
- dependency success/failure;
- rate-limit and WAF events;
- coarse decision/error counters.

## Prohibited telemetry

- request/response bodies;
- ciphertext;
- wrapped keys;
- plaintext images;
- tensors/embeddings;
- raw estimated age/confidence;
- full exception object when it can capture request buffers.

## Required alerts

Production should alert on:

- elevated 5xx/timeout rate;
- Key Vault crypto failures;
- inference readiness failures;
- Redis connectivity/replay-state failures;
- Front Door WAF rate-limit spikes;
- unusual verification volume;
- no healthy gateway/inference replicas;
- ACR image-pull failures.

## Correlation

Use an opaque request ID generated before image processing. Never derive correlation IDs from image content, face data, email, or user identity.
