# ADR-008 — Managed identity as the default Azure authentication mechanism

**Status:** Accepted

## Context
Connection strings and resource keys increase secret-management risk and make least-privilege review harder.

## Decision
Assign a system-managed identity to each API/worker app and grant only the Azure data-plane roles required by that component. Runtime settings carry endpoints/resource names, not credentials. Non-Azure secrets such as payment-provider credentials belong in Key Vault.

GitHub Actions authenticates to Azure through OIDC/federated identity rather than a stored client secret.

## Consequences
RBAC becomes part of the IaC deployment and may take time to propagate. The deployment identity needs permission to create role assignments. Local development must use developer credentials compatible with `DefaultAzureCredential` or an equivalent workload-identity abstraction.
