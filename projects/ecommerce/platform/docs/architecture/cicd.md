# CI/CD Architecture

## Goals

- Authenticate GitHub Actions to Azure without a stored client secret.
- Separate infrastructure deployment from application deployment.
- Require explicit production approval.
- Make deployments reproducible from a clean subscription.

## Infrastructure workflow

The root `.github/workflows/ecommerce-infra.yml` performs checkout, Bicep lint/build, parameter validation, Azure OIDC login, live Azure Resource Manager `what-if`, and an optional explicitly gated deployment.

The connected workflow has successfully completed OIDC login and a subscription-scope dev What-If. No infrastructure deployment has been run.

Expected GitHub values:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

No Azure client secret is required.

## Deployment identity

The portfolio currently uses a dedicated Entra application/service principal with immutable GitHub federated credentials. At the subscription scope it has:

- `Contributor` for resource creation/update; and
- `Role Based Access Control Administrator` because this Bicep package creates Azure role assignments.

That is intentionally more constrained than using `Owner`, while still broad enough for subscription-scoped resource-group creation and the RBAC resources modeled by this reference architecture. A production enterprise implementation should further split identities by workload/environment and narrow scope/custom roles wherever the deployment model permits it.

## Environments

- `dev`: low-cost development and current live What-If profile.
- `test`: separate integration/resilience state.
- `prod`: protected GitHub Environment / explicit production approval target.

## Application delivery layer

After backend code exists, add a separate workflow:

```text
build -> unit tests -> package -> deploy primary -> health check -> deploy secondary -> integration tests
```

Use deployment slots for production rollout/rollback. If SCM becomes private, use a runner with private network access.
