[CmdletBinding()]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [string]$DeploymentLocation = 'eastus2',
    [switch]$SkipProviderRegistration
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$main = Join-Path $repoRoot 'infra/main.bicep'
$params = Join-Path $repoRoot "infra/environments/$Environment.bicepparam"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

Write-Host "Subscription: $($account.name) [$($account.id)]" -ForegroundColor Cyan
Write-Host "Environment:  $Environment" -ForegroundColor Cyan

if (-not $SkipProviderRegistration) {
    $providers = @(
        'Microsoft.Authorization','Microsoft.Cdn','Microsoft.DocumentDB','Microsoft.Insights',
        'Microsoft.KeyVault','Microsoft.Network','Microsoft.OperationalInsights',
        'Microsoft.ServiceBus','Microsoft.Storage','Microsoft.Web'
    )

    foreach ($provider in $providers) {
        Write-Host "Registering $provider" -ForegroundColor DarkGray
        az provider register --namespace $provider --wait | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Provider registration failed: $provider" }
    }
}

$deploymentName = "ecommerce-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host 'Running what-if...' -ForegroundColor Cyan
az deployment sub what-if `
    --name $deploymentName `
    --location $DeploymentLocation `
    --template-file $main `
    --parameters $params
if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

Write-Host 'Deploying infrastructure...' -ForegroundColor Cyan
$result = az deployment sub create `
    --name $deploymentName `
    --location $DeploymentLocation `
    --template-file $main `
    --parameters $params `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }

Write-Host 'Deployment completed.' -ForegroundColor Green
$result.properties.outputs | ConvertTo-Json -Depth 20
