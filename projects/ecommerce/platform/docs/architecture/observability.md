# Observability Architecture

## Goals

An operator should be able to answer: what failed, where, for which order/customer request, whether the failure is transient, and what action is safe.

## Telemetry stack

- Application Insights for application traces, dependencies, exceptions, and metrics.
- Log Analytics as the central query workspace.
- Azure Monitor alerts for platform/application health.
- Structured application logging with correlation IDs.

## Correlation

Generate or accept a `correlationId` at the API boundary and propagate it through order state, Service Bus message properties, worker logs, and downstream provider calls. Each event also carries a globally unique `eventId` used for idempotency.

## Minimum dashboard signals

- requests/sec and P95/P99 latency
- HTTP 4xx/5xx rate
- checkout success/failure rate
- orders/minute
- payment failure rate
- inventory reservation failure/conflict rate
- Service Bus active-message backlog
- DLQ count
- worker processing latency/failures
- Cosmos throttling/latency
- Front Door origin health

## Alerting priorities

Page-worthy: sustained checkout failure, all healthy API origins lost, runaway DLQ/backlog, critical payment/inventory failures.

Ticket/investigation: elevated latency, rising throttling, unusual reservation conflicts, analytics lag, cost anomalies.

## Logging rules

Do not log passwords, tokens, payment credentials, full request bodies by default, or unnecessary personal data. Prefer stable IDs and structured fields that support correlation without exposing sensitive content.

## Acceptance criterion

Given an `orderId` or `correlationId`, an operator must be able to reconstruct the API request, emitted events, worker processing, payment result, inventory transition, and final order state from telemetry and operational records.
