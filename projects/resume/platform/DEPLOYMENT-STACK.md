# Portfolio Deployment Stack Lifecycle

The production portfolio infrastructure is managed as an Azure subscription-scope Deployment Stack. GitHub Actions authenticates without stored Azure credentials and uses a dedicated user-assigned managed identity (UAMI) for Deployment Stack operations.

## Production stack

- Name: `portfolio-prod-stack`
- Scope: subscription
- Template: `infra/main.bicep`
- Managed resource group: `portfolio-prod-rg`
- Primary managed resource: `portfolio-prod-swa`
- Deny settings: `none`
- Action on unmanage: `deleteAll`

`deleteAll` is intentional because `portfolio-prod-rg` is dedicated to this site. Resources removed from the stack definition, or the stack itself when explicitly deleted with the same action, are eligible for cleanup instead of being silently orphaned.

Do not place unrelated resources in `portfolio-prod-rg`.

## Deployment identity

Deployment Stacks require an Azure access token that identifies the calling principal in a way the original GitHub/Entra application token did not consistently provide. The portfolio therefore uses a dedicated deployment UAMI:

- Resource group: `portfolio-bootstrap-rg`
- Managed identity: `github-portfolio-prod-mi`
- Federated credential: `github-prod`
- GitHub trust: the repository `prod` environment
- Azure role: `Contributor` at subscription scope
- Bootstrap template: `infra/bootstrap/bootstrap-identity.bicep`

The bootstrap identity deliberately lives **outside** `portfolio-prod-stack`. A deployment identity must not be managed by the stack that depends on that identity, otherwise teardown/update operations could create a circular lifecycle dependency.

The bootstrap template is reproducible infrastructure as code. It creates the bootstrap resource group, UAMI, GitHub federated identity credential, and subscription-scoped Contributor assignment.

## Authentication flow

The workflow keeps the existing GitHub OIDC login for ordinary Azure Resource Manager operations such as ARM What-If. Immediately before a Deployment Stack operation, `scripts/use-portfolio-deployment-identity.ps1` requests a fresh GitHub OIDC token with the Azure token-exchange audience and signs the Azure CLI into `github-portfolio-prod-mi`.

No Azure client secret is stored or generated. Tokens are short lived.

For local administration, the identity-switch helper does nothing outside GitHub Actions, so an operator can use their existing `az login` identity.

## Validation

`./scripts/validate.ps1 -RunWhatIf` performs layered validation:

1. Bicep lint/build and production parameter compilation.
2. Standard subscription-scope ARM What-If under the workflow's initial OIDC identity.
3. Switch to `github-portfolio-prod-mi` when running in GitHub Actions.
4. Deployment Stack Provider-level validation for `portfolio-prod-stack`.

This validates both the resources Azure would change and the exact identity that will perform the stack deployment.

## Deploy or update

`./scripts/deploy-infra.ps1` compiles the production parameters, switches to the deployment UAMI when running in GitHub Actions, and creates or updates `portfolio-prod-stack` with Provider-level validation.

The production GitHub workflow runs automatically after a relevant change reaches `main`, but only after local validation and Azure What-If succeed. Manual workflow dispatch remains available as a redeploy fallback.

## Remove the portfolio

Teardown is deliberately guarded. Review the stack contents first:

```powershell
az stack sub show --name portfolio-prod-stack --output jsonc
```

Then remove the stack and its managed infrastructure:

```powershell
./scripts/remove-infra.ps1 -ConfirmDelete
```

The teardown script calls `az stack sub delete --action-on-unmanage deleteAll`. Because the stack manages the dedicated resource group, this can delete `portfolio-prod-rg` and everything contained in it.

## Retire the CI/CD identity too

The deployment UAMI is intentionally independent of the portfolio stack, so deleting the site does not delete the identity required to perform that deletion.

If the entire portfolio CI/CD setup is being retired, remove the portfolio stack first, authenticate with an Azure identity that can manage subscription role assignments, and then run:

```powershell
./scripts/remove-bootstrap-identity.ps1 -ConfirmDelete
```

That guarded script removes the deployment UAMI's subscription-level Contributor assignment and then deletes `portfolio-bootstrap-rg`, which removes the UAMI and its GitHub federated credential.
