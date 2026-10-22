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
$globalRgName = "rg-ecommerce-$Environment-global"
$primaryRgName = "rg-ecommerce-$Environment-eus2"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

function Protect-EvidenceText {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    $protected = $Text
    if ($account.id) {
        $protected = $protected.Replace([string]$account.id, '<subscription-id>')
    }
    if ($account.tenantId) {
        $protected = $protected.Replace([string]$account.tenantId, '<tenant-id>')
    }
    return $protected
}

function Write-EvidenceJson {
    param(
        [string]$FileName,
        [object]$Value
    )

    if (-not $EvidenceDirectory) { return }
    $json = $Value | ConvertTo-Json -Depth 50
    Protect-EvidenceText -Text $json | Set-Content -Path (Join-Path $EvidenceDirectory $FileName) -Encoding utf8
}

function Write-EvidenceText {
    param(
        [string]$FileName,
        [AllowEmptyString()][string]$Value
    )

    if (-not $EvidenceDirectory) { return }
    Protect-EvidenceText -Text $Value | Set-Content -Path (Join-Path $EvidenceDirectory $FileName) -Encoding utf8
}

function Get-SanitizedDeploymentOperations {
    param(
        [ValidateSet('subscription','resourceGroup')]
        [string]$Scope,
        [string]$DeploymentName,
        [string]$ResourceGroupName
    )

    if ($Scope -eq 'subscription') {
        $raw = az deployment operation sub list --name $DeploymentName --output json 2>$null
    }
    else {
        $raw = az deployment operation group list --resource-group $ResourceGroupName --name $DeploymentName --output json 2>$null
    }

    if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }

    $operations = @($raw | ConvertFrom-Json)
    return @(
        foreach ($operation in $operations) {
            [ordered]@{
                operationId = $operation.operationId
                provisioningOperation = $operation.properties.provisioningOperation
                provisioningState = $operation.properties.provisioningState
                targetResource = [ordered]@{
                    resourceName = $operation.properties.targetResource.resourceName
                    resourceType = $operation.properties.targetResource.resourceType
                    resourceGroup = $operation.properties.targetResource.resourceGroup
                }
                statusCode = $operation.properties.statusCode
                statusMessage = $operation.properties.statusMessage
            }
        }
    )
}

function Capture-FailureEvidence {
    if (-not $EvidenceDirectory) { return }

    Write-Host 'Capturing failed deployment diagnostics...' -ForegroundColor Yellow

    $stackState = az stack sub show `
        --name $stackName `
        --query '{name:name,provisioningState:properties.provisioningState,actionOnUnmanage:properties.actionOnUnmanage,error:properties.error}' `
        --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $stackState) {
        Write-EvidenceText -FileName 'stack-state-on-failure.json' -Value ($stackState -join [Environment]::NewLine)
    }

    $subscriptionRaw = az deployment sub list --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $subscriptionRaw) {
        $subscriptionDeployments = @($subscriptionRaw | ConvertFrom-Json) |
            Sort-Object { $_.properties.timestamp } -Descending |
            Select-Object -First 10

        $subscriptionSummary = @(
            foreach ($deployment in $subscriptionDeployments) {
                [ordered]@{
                    name = $deployment.name
                    provisioningState = $deployment.properties.provisioningState
                    timestamp = $deployment.properties.timestamp
                    error = $deployment.properties.error
                }
            }
        )
        Write-EvidenceJson -FileName 'recent-subscription-deployments.json' -Value $subscriptionSummary

        foreach ($deployment in @($subscriptionDeployments | Where-Object { $_.properties.provisioningState -eq 'Failed' } | Select-Object -First 5)) {
            $operations = Get-SanitizedDeploymentOperations -Scope subscription -DeploymentName $deployment.name
            if ($operations.Count -gt 0) {
                Write-EvidenceJson -FileName ("subscription-deployment-{0}-operations.json" -f $deployment.name) -Value $operations
            }
        }
    }

    foreach ($resourceGroupName in @($globalRgName, $primaryRgName)) {
        $exists = az group exists --name $resourceGroupName 2>$null
        if ($LASTEXITCODE -ne 0 -or $exists -ne 'true') { continue }

        $groupRaw = az deployment group list --resource-group $resourceGroupName --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $groupRaw) { continue }

        $groupDeployments = @($groupRaw | ConvertFrom-Json) |
            Sort-Object { $_.properties.timestamp } -Descending |
            Select-Object -First 10

        $groupSummary = @(
            foreach ($deployment in $groupDeployments) {
                [ordered]@{
                    name = $deployment.name
                    resourceGroup = $resourceGroupName
                    provisioningState = $deployment.properties.provisioningState
                    timestamp = $deployment.properties.timestamp
                    error = $deployment.properties.error
                }
            }
        )
        Write-EvidenceJson -FileName ("{0}-deployments.json" -f $resourceGroupName) -Value $groupSummary

        foreach ($deployment in @($groupDeployments | Where-Object { $_.properties.provisioningState -eq 'Failed' } | Select-Object -First 5)) {
            $operations = Get-SanitizedDeploymentOperations -Scope resourceGroup -ResourceGroupName $resourceGroupName -DeploymentName $deployment.name
            if ($operations.Count -gt 0) {
                Write-EvidenceJson -FileName ("{0}-deployment-{1}-operations.json" -f $resourceGroupName, $deployment.name) -Value $operations
            }
        }
    }

    Write-Host "Failure evidence written to $EvidenceDirectory" -ForegroundColor Yellow
}

Write-Host "Subscription: $($account.name) [redacted id]" -ForegroundColor Cyan
Write-Host "Environment:  $Environment" -ForegroundColor Cyan
Write-Host "Stack:        $stackName" -ForegroundColor Cyan
Write-Host 'Validation profile: Free Trial-compatible, Azure Front Door intentionally omitted.' -ForegroundColor Yellow

if ($EvidenceDirectory) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    Write-EvidenceJson -FileName 'deployment-attempt.json' -Value ([ordered]@{
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        environment = $Environment
        deploymentLocation = $DeploymentLocation
        stackName = $stackName
        validationProfile = 'free-trial-compatible-no-front-door'
        frontDoorRuntimeIncluded = $false
        frontDoorOmissionReason = 'Validation subscription blocks Azure Front Door resource creation.'
    })
}

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
$stackErrorPath = if ($EvidenceDirectory) { Join-Path $EvidenceDirectory 'stack-create-stderr.txt' } else { $null }
$stackArguments = @(
    'stack','sub','create',
    '--name',$stackName,
    '--location',$DeploymentLocation,
    '--template-file',$main,
    '--parameters',$params,
    '--action-on-unmanage','deleteAll',
    '--deny-settings-mode','none',
    '--description',"Temporary portfolio validation environment for e-commerce ($Environment); Front Door omitted because the validation subscription forbids it.",
    '--yes',
    '--output','none'
)

if ($stackErrorPath) {
    & az @stackArguments 2> $stackErrorPath
}
else {
    & az @stackArguments
}
$stackExitCode = $LASTEXITCODE

if ($stackErrorPath -and (Test-Path $stackErrorPath)) {
    $rawStackError = Get-Content -Path $stackErrorPath -Raw
    Write-EvidenceText -FileName 'stack-create-stderr.txt' -Value $rawStackError
}

if ($stackExitCode -ne 0) {
    Capture-FailureEvidence
    throw "Deployment Stack creation failed. Diagnostics were captured in '$EvidenceDirectory'."
}

$resultRaw = az stack sub show --name $stackName --output json
if ($LASTEXITCODE -ne 0 -or -not $resultRaw) { throw 'Deployment Stack completed, but its final state could not be read.' }
$result = $resultRaw | ConvertFrom-Json

Write-Host 'Deployment Stack completed.' -ForegroundColor Green

if ($EvidenceDirectory) {
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

    Write-EvidenceJson -FileName 'deployment-stack.json' -Value $metadata

    $stackSummary = az stack sub show `
        --name $stackName `
        --query '{name:name,provisioningState:properties.provisioningState,actionOnUnmanage:properties.actionOnUnmanage,outputs:properties.outputs}' `
        --output json
    if ($LASTEXITCODE -ne 0) { throw 'Deployment succeeded, but evidence capture failed.' }
    Write-EvidenceText -FileName 'deployment-stack-summary.json' -Value ($stackSummary -join [Environment]::NewLine)

    Write-Host "Evidence written to $EvidenceDirectory" -ForegroundColor Green
}

if ($result.properties.outputs) {
    $result.properties.outputs | ConvertTo-Json -Depth 20
}
