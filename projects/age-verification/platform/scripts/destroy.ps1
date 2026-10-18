[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [switch]$Force,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$foundationStack = "ageverify-$Environment-foundation-validation-stack"
$workloadStack = "ageverify-$Environment-workloads-validation-stack"
$resourceGroups = @(
    "ageverify-$Environment-platform-rg",
    "ageverify-$Environment-network-rg",
    "ageverify-$Environment-security-rg",
    "ageverify-$Environment-monitor-rg"
)

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure. Run az login first.' }

$captured = [ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    subscriptionId = $account.id
    environment = $Environment
    stacks = @()
}

foreach ($stackName in @($workloadStack, $foundationStack)) {
    $stack = az stack sub show --name $stackName --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0 -and $stack) {
        $captured.stacks += [ordered]@{
            name = $stackName
            id = $stack.id
            provisioningState = $stack.properties.provisioningState
            managedResources = $stack.properties.resources
        }
    }
}

if ($captured.stacks.Count -eq 0) {
    throw 'No age-assurance validation Deployment Stacks were found. Refusing to fall back to direct resource-group deletion.'
}

Write-Warning "This deletes the $Environment age-assurance validation stacks and all managed resources using action-on-unmanage=deleteAll."
if (-not $Force -and -not $PSCmdlet.ShouldProcess("ageverify-$Environment", 'Delete validation Deployment Stacks and managed resources')) {
    Write-Host 'Cleanup cancelled.' -ForegroundColor Yellow
    return
}

foreach ($stackName in @($workloadStack, $foundationStack)) {
    $exists = az stack sub show --name $stackName --query name -o tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $exists) {
        Write-Host "Stack '$stackName' is already absent." -ForegroundColor DarkGray
        continue
    }

    Write-Host "Deleting $stackName with deleteAll..." -ForegroundColor Yellow
    az stack sub delete --name $stackName --action-on-unmanage deleteAll --yes
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete Deployment Stack '$stackName'." }
}

$remainingGroups = @()
foreach ($rg in $resourceGroups) {
    $exists = az group exists --name $rg
    if ($exists -eq 'true') { $remainingGroups += $rg }
}

if ($EvidenceDirectory) {
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $cleanup = [ordered]@{
        deletedUtc = (Get-Date).ToUniversalTime().ToString('o')
        beforeDelete = $captured
        remainingExpectedResourceGroups = $remainingGroups
        cleanupVerified = ($remainingGroups.Count -eq 0)
    }
    $cleanup | ConvertTo-Json -Depth 30 | Set-Content -Path (Join-Path $EvidenceDirectory 'cleanup.json') -Encoding utf8
}

if ($remainingGroups.Count -gt 0) {
    Write-Warning "Stack deletion returned, but these resource groups still exist: $($remainingGroups -join ', '). Azure may still be completing asynchronous cleanup."
} else {
    Write-Host 'Age-assurance validation stacks and expected resource groups are gone.' -ForegroundColor Green
}
