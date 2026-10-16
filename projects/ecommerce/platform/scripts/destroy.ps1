[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [switch]$Force,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$stackName = "ecommerce-$Environment-validation-stack"
$resourceGroups = @(
    "rg-ecommerce-$Environment-global",
    "rg-ecommerce-$Environment-eus2",
    "rg-ecommerce-$Environment-wus2"
)

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

$stack = az stack sub show --name $stackName --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $stack) {
    throw "Deployment Stack '$stackName' was not found. Refusing to fall back to direct resource-group deletion."
}

Write-Warning "This deletes Deployment Stack '$stackName' and all managed resources/resource groups using action-on-unmanage=deleteAll."

if (-not $Force -and -not $PSCmdlet.ShouldProcess($stackName, 'Delete Deployment Stack and managed resources')) {
    Write-Host 'Cleanup cancelled.' -ForegroundColor Yellow
    return
}

$capturedBeforeDelete = [ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    subscriptionId = $account.id
    environment = $Environment
    stackName = $stackName
    stackId = $stack.id
    provisioningState = $stack.properties.provisioningState
    managedResources = $stack.properties.resources
}

Write-Host "Deleting $stackName with deleteAll..." -ForegroundColor Yellow
az stack sub delete `
    --name $stackName `
    --action-on-unmanage deleteAll `
    --yes
if ($LASTEXITCODE -ne 0) { throw "Failed to delete Deployment Stack '$stackName'." }

$remainingGroups = @()
foreach ($rg in $resourceGroups) {
    $exists = az group exists --name $rg
    if ($exists -eq 'true') { $remainingGroups += $rg }
}

if ($EvidenceDirectory) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $cleanup = [ordered]@{
        deletedUtc = (Get-Date).ToUniversalTime().ToString('o')
        stack = $capturedBeforeDelete
        remainingExpectedResourceGroups = $remainingGroups
        cleanupVerified = ($remainingGroups.Count -eq 0)
    }
    $cleanup | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $EvidenceDirectory 'cleanup.json') -Encoding utf8
}

if ($remainingGroups.Count -gt 0) {
    Write-Warning "Stack deletion completed, but these resource groups still exist: $($remainingGroups -join ', '). Azure may still be completing asynchronous child-resource cleanup."
} else {
    Write-Host 'Deployment Stack and expected resource groups are gone.' -ForegroundColor Green
}
