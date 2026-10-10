# CI/CD Architecture

## Goals

- Authenticate GitHub Actions to Azure without a stored client secret.
- Separate infrastructure deployment from application deployment.
- Require explicit production approval.
- Make deployments reproducible from a clean subscription.

## Infrastructure workflow

The root `.github/workflows/ecommerce-infra.yml` performs checkout, Azure OIDC login, Bicep lint/build, parameter validation, Azure `what-if`, and optional manual deployment.

Expected GitHub values:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

No Azure client secret is required when the federated credential is configured correctly.

## Deployment identity

Use a dedicated Entra application/service principal or managed identity with a federated credential restricted to the repository/environment. Because Bicep creates role assignments, the deployment identity also requires role-assignment permissions. A portfolio subscription may use Owner for simplicity; an enterprise implementation should narrow those privileges.

## Environments

- `dev`: low-cost development.
- `test`: separate integration/resilience state.
- `prod`: protected GitHub Environment with reviewer approval.

## Application delivery layer

After backend code exists, add a separate workflow:

```text
build -> unit tests -> package -> deploy primary -> health check -> deploy secondary -> integration tests
```

Use deployment slots for production rollout/rollback. If SCM becomes private, use a runner with private network access.
