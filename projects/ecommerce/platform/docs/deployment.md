# Deployment Guide

## Required Azure permissions

The deployment creates resources and role assignments. The deploying identity therefore needs resource deployment permissions and permission to create role assignments. `Owner` is simplest for a lab subscription; controlled environments should separate these privileges.

## Resource providers

The deployment script registers Microsoft.Authorization, Microsoft.Cdn, Microsoft.DocumentDB, Microsoft.Insights, Microsoft.KeyVault, Microsoft.Network, Microsoft.OperationalInsights, Microsoft.ServiceBus, Microsoft.Storage, and Microsoft.Web.

## Validate first

```powershell
./scripts/validate.ps1 -Environment dev
./scripts/validate.ps1 -Environment dev -RunWhatIf
```

## Deploy

```powershell
./scripts/deploy.ps1 -Environment dev
```

The template is subscription-scoped because it creates its own resource groups.

## Production reference

```powershell
./scripts/deploy.ps1 -Environment prod
```

Before prod, verify regional SKU availability/quota and budget for Premium Front Door, Service Bus Premium, multi-region Cosmos DB, private endpoints, and two PremiumV3 App Service plans.

## Application deployment sequence

1. Deploy infrastructure.
2. Build API/worker binaries.
3. Deploy API to regional API apps.
4. Deploy workers.
5. Seed catalog/inventory.
6. Run smoke tests through Front Door.
7. Run concurrency/failure tests.

## Destroy a lab deployment

```powershell
./scripts/destroy.ps1 -Environment dev
```

Review resource locks/data-retention requirements before destructive cleanup outside a lab environment.
