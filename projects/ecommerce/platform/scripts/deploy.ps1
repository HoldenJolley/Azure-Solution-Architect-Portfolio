[CmdletBinding()]
param(
    [ValidateSet('dev')]
    [string]$Environment = 'dev',
    [string]$DeploymentLocation = 'eastus2',
    [switch]$SkipProviderRegistration,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$main = Join-Path $repoRoot 'infra/validation.bicep'
$params = Join-Path $repoRoot 'infra/environments/dev.validation.bicepparam'
$stackName = "ecommerce-$Environment-validation-stack"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

Write-Host "Subscription: $($account.name) [$($account.id)]" -ForegroundColor Cyan
Write-Host "Environment:  $Environment" -ForegroundColor Cyan
Write-Host "Stack:        $stackName" -ForegroundColor Cyan
Write-Host 'Validation profile: Free Trial-compatible, Azure Front Door intentionally omitted.' -ForegroundColor Yellow

if (-not $SkipProviderRegistration) {
    $providers = @(
        'Microsoft.Authorization','Microsoft.DocumentDB','Microsoft.Insights',
        'Microsoft.KeyVault','Microsoft.Network','Microsoft.OperationalInsights',
        'Microsoft.ServiceBus','Microsoft.Storage','Microsoft.Web'
    )

    foreach ($provider in $providers) {
        Write-Host "Registering $provider" -ForegroundColor DarkGray
        az provider register --namespace $provider --wait | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Provider registration failed: $provider" }
    }
}

$whatIfName = "ecommerce-$Environment-preflight-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host 'Running ARM subscription-scope what-if against the temporary validation profile...' -ForegroundColor Cyan
az deployment sub what-if `
    --name $whatIfName `
    --location $DeploymentLocation `
    --template-file $main `
    --parameters $params
if ($LASTEXITCODE -ne 0) { throw 'What-if failed. No resources were deployed.' }

Write-Host 'Creating or updating Azure Deployment Stack...' -ForegroundColor Cyan
$result = az stack sub create `
    --name $stackName `
    --location $DeploymentLocation `
    --template-file $main `
    --parameters $params `
    --action-on-unmanage deleteAll `
    --deny-settings-mode none `
    --description "Temporary portfolio validation environment for e-commerce ($Environment); Front Door omitted because the validation subscription forbids it." `
    --yes `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Deployment Stack creation failed.' }

Write-Host 'Deployment Stack completed.' -ForegroundColor Green

if ($EvidenceDirectory) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null

    $metadata = [ordered]@{
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        environment = $Environment
        deploymentLocation = $DeploymentLocation
        stackName = $stackName
        provisioningState = $result.properties.provisioningState
        actionOnUnmanage = $result.properties.actionOnUnmanage
        validationProfile = 'free-trial-compatible-no-front-door'
        frontDoorRuntimeIncluded = $false
        frontDoorOmissionReason = 'Validation subscription blocks Azure Front Door resource creation.'
        outputs = $result.properties.outputs
    }

    $metadata | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $EvidenceDirectory 'deployment-stack.json') -Encoding utf8

    $stackSummary = az stack sub show `
        --name $stackName `
        --query '{name:name,provisioningState:properties.provisioningState,actionOnUnmanage:properties.actionOnUnmanage,outputs:properties.outputs}' `
        --output json
    if ($LASTEXITCODE -ne 0) { throw 'Deployment succeeded, but evidence capture failed.' }
    $stackSummary | Set-Content -Path (Join-Path $EvidenceDirectory 'deployment-stack-summary.json') -Encoding utf8

    Write-Host "Evidence written to $EvidenceDirectory" -ForegroundColor Green
}

if ($result.properties.outputs) {
    $result.properties.outputs | ConvertTo-Json -Depth 20
}
