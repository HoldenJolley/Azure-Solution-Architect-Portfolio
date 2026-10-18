[CmdletBinding()]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [string]$DeploymentLocation = 'eastus2',
    [switch]$SkipProviderRegistration,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra/foundation.bicep'
$params = Join-Path $root "infra/environments/$Environment.foundation.bicepparam"
$stackName = "ageverify-$Environment-foundation-validation-stack"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

Write-Host "Subscription: $($account.name) [$($account.id)]" -ForegroundColor Cyan
Write-Host "Environment:  $Environment" -ForegroundColor Cyan
Write-Host "Stack:        $stackName" -ForegroundColor Cyan

if (-not $SkipProviderRegistration) {
    $providers = @(
        'Microsoft.App','Microsoft.Authorization','Microsoft.Cache','Microsoft.Cdn',
        'Microsoft.ContainerRegistry','Microsoft.Insights','Microsoft.KeyVault',
        'Microsoft.ManagedIdentity','Microsoft.Network','Microsoft.OperationalInsights'
    )

    foreach ($provider in $providers) {
        Write-Host "Registering $provider" -ForegroundColor DarkGray
        az provider register --namespace $provider --wait | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Provider registration failed: $provider" }
    }
}

$whatIfName = "ageverify-$Environment-foundation-preflight-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host 'Running ARM subscription-scope foundation What-If...' -ForegroundColor Cyan
az deployment sub what-if `
    --name $whatIfName `
    --location $DeploymentLocation `
    --template-file $template `
    --parameters $params
if ($LASTEXITCODE -ne 0) { throw 'Foundation What-If failed. No resources were deployed.' }

Write-Host 'Creating or updating foundation Deployment Stack...' -ForegroundColor Cyan
$result = az stack sub create `
    --name $stackName `
    --location $DeploymentLocation `
    --template-file $template `
    --parameters $params `
    --action-on-unmanage deleteAll `
    --deny-settings-mode none `
    --description "Temporary portfolio validation foundation for age assurance ($Environment)." `
    --yes `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Foundation Deployment Stack creation failed.' }

Write-Host 'Foundation Deployment Stack completed.' -ForegroundColor Green

if ($EvidenceDirectory) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $metadata = [ordered]@{
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        subscriptionId = $account.id
        environment = $Environment
        deploymentLocation = $DeploymentLocation
        stackName = $stackName
        stackId = $result.id
        provisioningState = $result.properties.provisioningState
        actionOnUnmanage = $result.properties.actionOnUnmanage
        outputs = $result.properties.outputs
    }
    $metadata | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $EvidenceDirectory 'foundation-stack.json') -Encoding utf8
    az stack sub show --name $stackName --output json | Set-Content -Path (Join-Path $EvidenceDirectory 'foundation-stack-full.json') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Foundation deployed, but evidence capture failed.' }
}

if ($result.properties.outputs) {
    $result.properties.outputs | ConvertTo-Json -Depth 20
}
