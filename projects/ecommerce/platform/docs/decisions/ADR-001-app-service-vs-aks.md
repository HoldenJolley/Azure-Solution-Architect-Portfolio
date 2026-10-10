# ADR-001 — App Service instead of AKS

**Status:** Accepted

## Context
The backend needs regional HTTP APIs and long-running worker processes, but the project should emphasize Azure solution architecture rather than Kubernetes platform administration.

## Decision
Use Linux Azure App Service plans for the API and worker applications.

## Alternatives
AKS, Container Apps, Functions.

## Rationale
App Service provides managed patching, identity, VNet integration, autoscale options, health checks, deployment slots, and straightforward Front Door integration with less operational overhead than AKS.

## Consequences
Container orchestration features are intentionally absent. If workload requirements later demand Kubernetes-specific scheduling/service-mesh/platform capabilities, reevaluate AKS rather than adopting it for résumé value alone.
