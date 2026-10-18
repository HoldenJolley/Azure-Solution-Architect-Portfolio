[CmdletBinding()]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [Parameter(Mandatory=$true)][string]$GatewayImage,
    [Parameter(Mandatory=$true)][string]$InferenceImage,
    [string]$DeploymentLocation = 'eastus2',
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra/workloads.bicep'
$params = Join-Path $root "infra/environments/$Environment.workloads.bicepparam"
$foundationStackName = "ageverify-$Environment-foundation-validation-stack"
$stackName = "ageverify-$Environment-workloads-validation-stack"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

$foundation = az stack sub show --name $foundationStackName --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $foundation) {
    throw "Foundation Deployment Stack '$foundationStackName' was not found. Deploy the foundation first."
}
if ($foundation.properties.provisioningState -ne 'Succeeded') {
    throw "Foundation stack is not ready. State: $($foundation.properties.provisioningState)"
}

Write-Host "Subscription: $($account.name) [$($account.id)]" -ForegroundColor Cyan
Write-Host "Environment:  $Environment" -ForegroundColor Cyan
Write-Host "Stack:        $stackName" -ForegroundColor Cyan

Write-Host 'Running workload ARM What-If...' -ForegroundColor Cyan
az deployment sub what-if `
    --name "ageverify-$Environment-workloads-preflight-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --location $DeploymentLocation `
    --template-file $template `
    --parameters $params `
    --parameters gatewayImage=$GatewayImage inferenceImage=$InferenceImage
if ($LASTEXITCODE -ne 0) { throw 'Workload What-If failed. No workload resources were deployed.' }

Write-Host 'Creating or updating workload Deployment Stack...' -ForegroundColor Cyan
$result = az stack sub create `
    --name $stackName `
    --location $DeploymentLocation `
    --template-file $template `
    --parameters $params `
    --parameters gatewayImage=$GatewayImage inferenceImage=$InferenceImage `
    --action-on-unmanage deleteAll `
    --deny-settings-mode none `
    --description "Temporary portfolio validation workloads for age assurance ($Environment)." `
    --yes `
    --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Workload Deployment Stack creation failed.' }

Write-Host 'Workload Deployment Stack completed.' -ForegroundColor Green

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
        gatewayImage = $GatewayImage
        inferenceImage = $InferenceImage
        outputs = $result.properties.outputs
    }
    $metadata | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $EvidenceDirectory 'workloads-stack.json') -Encoding utf8
    az stack sub show --name $stackName --output json | Set-Content -Path (Join-Path $EvidenceDirectory 'workloads-stack-full.json') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Workloads deployed, but evidence capture failed.' }
}

if ($result.properties.outputs) {
    $result.properties.outputs | ConvertTo-Json -Depth 20
}
