# Portfolio Deployment Stack Lifecycle

The production portfolio infrastructure is managed as an Azure subscription-scope Deployment Stack.

## Stack

- Name: `portfolio-prod-stack`
- Scope: subscription
- Template: `infra/main.bicep`
- Managed resource group: `portfolio-prod-rg`
- Primary managed resource: `portfolio-prod-swa`
- Deny settings: `none`
- Action on unmanage: `deleteAll`

`deleteAll` is intentional for this project because the resource group is dedicated to the portfolio. Resources removed from the stack definition, or the stack itself when explicitly deleted with the same action, are eligible for cleanup instead of being silently orphaned.

## Validation

`./scripts/validate.ps1 -RunWhatIf` performs a Deployment Stack What-If against the intended `portfolio-prod-stack` resource ID after the normal Bicep lint/build checks.

## Deploy or update

`./scripts/deploy-infra.ps1` creates or updates the stack with the production Bicep parameters.

## Teardown

Teardown is deliberately guarded. Review the stack contents first:

```powershell
az stack sub show --name portfolio-prod-stack --output jsonc
```

Then remove the stack and its managed infrastructure:

```powershell
./scripts/remove-infra.ps1 -ConfirmDelete
```

The teardown script calls `az stack sub delete --action-on-unmanage deleteAll`. Because the stack manages the dedicated resource group, this can delete the resource group and everything contained in it. Do not place unrelated resources in `portfolio-prod-rg`.
