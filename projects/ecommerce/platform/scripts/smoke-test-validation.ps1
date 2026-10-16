[CmdletBinding()]
param(
    [ValidateSet('dev')]
    [string]$Environment = 'dev',
    [Parameter(Mandatory=$true)][string]$TokenFile,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$stackName = "ecommerce-$Environment-validation-stack"
$globalResourceGroup = "rg-ecommerce-$Environment-global"

if (-not $EvidenceDirectory) {
    $EvidenceDirectory = Join-Path $repoRoot '_evidence/runtime'
}
if (-not (Test-Path $TokenFile)) {
    throw "Validation token file '$TokenFile' was not found."
}

$token = (Get-Content -Path $TokenFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Validation token file is empty.' }

$stack = az stack sub show --name $stackName --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $stack) { throw "Deployment Stack '$stackName' was not found." }
if ($stack.properties.provisioningState -ne 'Succeeded') {
    throw "Deployment Stack '$stackName' is not ready. Provisioning state: $($stack.properties.provisioningState)"
}

$outputs = $stack.properties.outputs
$frontDoorUrl = [string]$outputs.frontDoorUrl.value
$primaryApiHostName = [string]$outputs.primaryApiHostName.value
$appInsightsName = [string]$outputs.applicationInsightsName.value

if ([string]::IsNullOrWhiteSpace($frontDoorUrl) -or [string]::IsNullOrWhiteSpace($primaryApiHostName)) {
    throw 'Required Deployment Stack outputs are missing.'
}

$frontDoorUrl = $frontDoorUrl.TrimEnd('/')
$headers = @{ 'X-Validation-Token' = $token }
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null

Write-Host "Waiting for Front Door health at $frontDoorUrl/health ..." -ForegroundColor Cyan
$healthResponse = $null
for ($attempt = 1; $attempt -le 40; $attempt++) {
    $candidate = Invoke-WebRequest -Uri "$frontDoorUrl/health" -Method Get -SkipHttpErrorCheck -TimeoutSec 30
    if ($candidate.StatusCode -ge 200 -and $candidate.StatusCode -lt 300) {
        $healthResponse = $candidate
        break
    }

    Write-Host "Front Door health attempt $attempt returned HTTP $($candidate.StatusCode); retrying in 15 seconds..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 15
}
if (-not $healthResponse) { throw 'Front Door health endpoint did not become healthy within the validation window.' }

Write-Host 'Confirming direct App Service origin is rejected...' -ForegroundColor Cyan
$directOrigin = Invoke-WebRequest -Uri "https://$primaryApiHostName/health" -Method Get -SkipHttpErrorCheck -TimeoutSec 30
if ($directOrigin.StatusCode -ge 200 -and $directOrigin.StatusCode -lt 300) {
    throw "Direct App Service access unexpectedly succeeded with HTTP $($directOrigin.StatusCode)."
}

Write-Host 'Starting synthetic Cosmos + Service Bus validation...' -ForegroundColor Cyan
$run = Invoke-RestMethod `
    -Uri "$frontDoorUrl/validation/run" `
    -Method Post `
    -Headers $headers `
    -ContentType 'application/json' `
    -TimeoutSec 60

$eventId = [string]$run.eventId
if ([string]::IsNullOrWhiteSpace($eventId)) { throw 'Validation endpoint did not return an eventId.' }

$expectedConsumers = @('inventory', 'payment', 'shipping', 'analytics')
$status = $null
Write-Host "Waiting for all Service Bus subscriptions to process EventId=$eventId ..." -ForegroundColor Cyan
for ($attempt = 1; $attempt -le 60; $attempt++) {
    $status = Invoke-RestMethod `
        -Uri "$frontDoorUrl/validation/status/$eventId" `
        -Method Get `
        -Headers $headers `
        -TimeoutSec 30

    $processed = @($status.processedConsumers)
    $missing = @($expectedConsumers | Where-Object { $_ -notin $processed })
    if ($missing.Count -eq 0) { break }

    Write-Host "Waiting on: $($missing -join ', ')" -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
}

$processed = @($status.processedConsumers)
$missing = @($expectedConsumers | Where-Object { $_ -notin $processed })
if ($missing.Count -gt 0) {
    throw "Validation event was not processed by all subscriptions. Missing: $($missing -join ', ')"
}

Write-Host 'Waiting for Application Insights request telemetry...' -ForegroundColor Cyan
$telemetryCount = 0
for ($attempt = 1; $attempt -le 18; $attempt++) {
    $countText = az monitor app-insights query `
        --app $appInsightsName `
        --resource-group $globalResourceGroup `
        --analytics-query 'requests | where timestamp > ago(30m) | summarize count()' `
        --query 'tables[0].rows[0][0]' `
        --output tsv 2>$null

    if ($LASTEXITCODE -eq 0 -and [int]::TryParse(($countText | Out-String).Trim(), [ref]$telemetryCount) -and $telemetryCount -gt 0) {
        break
    }

    Start-Sleep -Seconds 10
}
if ($telemetryCount -le 0) {
    throw 'Application Insights did not return request telemetry within the validation window.'
}

Write-Host 'Cleaning synthetic Cosmos validation receipts...' -ForegroundColor Cyan
$cleanup = Invoke-RestMethod `
    -Uri "$frontDoorUrl/validation/status/$eventId" `
    -Method Delete `
    -Headers $headers `
    -TimeoutSec 60

$evidence = [ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    environment = $Environment
    stackName = $stackName
    frontDoorUrl = $frontDoorUrl
    frontDoorHealthStatus = [int]$healthResponse.StatusCode
    directOriginHostName = $primaryApiHostName
    directOriginStatus = [int]$directOrigin.StatusCode
    directOriginRejected = -not ($directOrigin.StatusCode -ge 200 -and $directOrigin.StatusCode -lt 300)
    eventId = $eventId
    cosmosWriteReadDelete = [string]$run.cosmosWriteReadDelete
    serviceBusPublish = [string]$run.serviceBusPublish
    processedConsumers = @($processed)
    allExpectedConsumersProcessed = $true
    applicationInsightsName = $appInsightsName
    applicationInsightsRequestCountLast30Minutes = $telemetryCount
    syntheticReceiptsDeleted = [int]$cleanup.deleted
    validationTokenStoredInEvidence = $false
}
$evidence | ConvertTo-Json -Depth 20 | Set-Content -Path (Join-Path $EvidenceDirectory 'runtime-smoke-test.json') -Encoding utf8

Write-Host 'E-commerce live validation smoke test succeeded.' -ForegroundColor Green
Write-Host "Evidence written to $EvidenceDirectory" -ForegroundColor Green
