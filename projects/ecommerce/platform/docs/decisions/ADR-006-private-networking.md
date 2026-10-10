# ADR-006 — Private networking for production data services

**Status:** Accepted

## Context
The production reference should prevent direct public data-plane access while keeping dev inexpensive and easy to bootstrap.

## Decision
Enable private endpoints and private DNS for Cosmos DB, Service Bus, Key Vault, and Data Lake in the production parameter set. Keep dev/test public-network capable unless a test specifically requires private networking.

## Consequences
Production App Service requires VNet integration and correct private DNS. Service Bus uses Premium in the private-network profile. Private endpoint cost and DNS complexity are accepted in prod but avoided for routine dev deployments.
