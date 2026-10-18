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
$primaryResourceGroup = "rg-ecommerce-$Environment-eus2"

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
$frontDoorDeployed = $false
if ($outputs.frontDoorDeployed) { $frontDoorDeployed = [bool]$outputs.frontDoorDeployed.value }
$frontDoorUrl = if ($outputs.frontDoorUrl) { [string]$outputs.frontDoorUrl.value } else { '' }
$runtimeEntryUrl = if ($outputs.runtimeEntryUrl) { [string]$outputs.runtimeEntryUrl.value } else { '' }
$primaryApiHostName = [string]$outputs.primaryApiHostName.value
$appInsightsName = [string]$outputs.applicationInsightsName.value
$cosmosEndpoint = [string]$outputs.cosmosEndpoint.value
$serviceBusFqdn = [string]$outputs.serviceBusNamespace.value

if ([string]::IsNullOrWhiteSpace($runtimeEntryUrl)) {
    if ($frontDoorDeployed -and -not [string]::IsNullOrWhiteSpace($frontDoorUrl)) {
        $runtimeEntryUrl = $frontDoorUrl
    } elseif (-not [string]::IsNullOrWhiteSpace($primaryApiHostName)) {
        $runtimeEntryUrl = "https://$primaryApiHostName"
    }
}
if ([string]::IsNullOrWhiteSpace($runtimeEntryUrl) -or [string]::IsNullOrWhiteSpace($primaryApiHostName)) {
    throw 'Required Deployment Stack outputs are missing.'
}

$runtimeEntryUrl = $runtimeEntryUrl.TrimEnd('/')
$headers = @{ 'X-Validation-Token' = $token }
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null

$entryMode = $frontDoorDeployed ? 'azure-front-door' : 'direct-app-service-validation'
Write-Host "Waiting for runtime health through $entryMode at $runtimeEntryUrl/health ..." -ForegroundColor Cyan
$healthResponse = $null
for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
        $candidate = Invoke-WebRequest -Uri "$runtimeEntryUrl/health" -Method Get -SkipHttpErrorCheck -TimeoutSec 30
        if ($candidate.StatusCode -ge 200 -and $candidate.StatusCode -lt 300) {
            $healthResponse = $candidate
            break
        }
        Write-Host "Health attempt $attempt returned HTTP $($candidate.StatusCode); retrying in 15 seconds..." -ForegroundColor DarkGray
    } catch {
        Write-Host "Health attempt $attempt failed while the app converges; retrying in 15 seconds..." -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds 15
}
if (-not $healthResponse) { throw 'Runtime health endpoint did not become healthy within the validation window.' }

$directOriginStatus = 0
$directOriginRejected = $false
if ($frontDoorDeployed) {
    Write-Host 'Confirming direct App Service origin is rejected...' -ForegroundColor Cyan
    try {
        $directOrigin = Invoke-WebRequest -Uri "https://$primaryApiHostName/health" -Method Get -SkipHttpErrorCheck -TimeoutSec 30
        $directOriginStatus = [int]$directOrigin.StatusCode
        if ($directOriginStatus -ge 200 -and $directOriginStatus -lt 300) {
            throw "Direct App Service access unexpectedly succeeded with HTTP $directOriginStatus."
        }
    } catch {
        if ($_.Exception.Message -like 'Direct App Service access unexpectedly succeeded*') { throw }
        $directOriginStatus = 0
    }
    $directOriginRejected = $true
} else {
    Write-Host 'Front Door runtime test intentionally omitted because this validation subscription blocks Front Door creation.' -ForegroundColor Yellow
    $directOriginStatus = [int]$healthResponse.StatusCode
}

Write-Host 'Confirming temporary validation endpoints reject requests without the ephemeral token...' -ForegroundColor Cyan
$unauthorized = Invoke-WebRequest `
    -Uri "$runtimeEntryUrl/validation/run" `
    -Method Post `
    -ContentType 'application/json' `
    -SkipHttpErrorCheck `
    -TimeoutSec 30
if ([int]$unauthorized.StatusCode -ne 401) {
    throw "Validation endpoint without token returned HTTP $($unauthorized.StatusCode); expected 401."
}

Write-Host 'Verifying deployed data-plane authentication posture...' -ForegroundColor Cyan
if ($cosmosEndpoint -notmatch '^https://([^.]+)\.') { throw "Unable to derive Cosmos account name from '$cosmosEndpoint'." }
$cosmosAccountName = $Matches[1]
$serviceBusNamespaceName = $serviceBusFqdn -replace '\.servicebus\.windows\.net$', ''
if ([string]::IsNullOrWhiteSpace($serviceBusNamespaceName)) { throw 'Unable to derive Service Bus namespace name.' }

$cosmosLocalAuth = az resource show `
    --resource-group $globalResourceGroup `
    --resource-type Microsoft.DocumentDB/databaseAccounts `
    --name $cosmosAccountName `
    --api-version 2024-11-15 `
    --query properties.disableLocalAuth `
    --output tsv
if ($LASTEXITCODE -ne 0 -or (($cosmosLocalAuth | Out-String).Trim().ToLowerInvariant() -ne 'true')) {
    throw 'Cosmos DB local/key authentication is not disabled as expected.'
}

$serviceBusLocalAuth = az resource show `
    --resource-group $globalResourceGroup `
    --resource-type Microsoft.ServiceBus/namespaces `
    --name $serviceBusNamespaceName `
    --api-version 2024-01-01 `
    --query properties.disableLocalAuth `
    --output tsv
if ($LASTEXITCODE -ne 0 -or (($serviceBusLocalAuth | Out-String).Trim().ToLowerInvariant() -ne 'true')) {
    throw 'Service Bus local/SAS authentication is not disabled as expected.'
}

$apiName = az webapp list `
    --resource-group $primaryResourceGroup `
    --query "[?tags.component=='api'].name | [0]" `
    --output tsv
$apiName = ($apiName | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apiName)) { throw 'Unable to resolve the deployed API App Service.' }

$appSettingNames = @(az webapp config appsettings list `
    --resource-group $primaryResourceGroup `
    --name $apiName `
    --query '[].name' `
    --output tsv)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect API application-setting names.' }

$forbiddenSettingPattern = '(?i)(COSMOS.*KEY|SERVICEBUS.*(CONNECTION|SAS|KEY)|STORAGE.*KEY|ACCOUNT_KEY|SAS_TOKEN|CLIENT_SECRET|PASSWORD)'
$forbiddenSettings = @($appSettingNames | Where-Object { $_ -match $forbiddenSettingPattern })
if ($forbiddenSettings.Count -gt 0) {
    throw "Reusable Azure resource credential-like application settings were found: $($forbiddenSettings -join ', ')"
}

Write-Host 'Starting synthetic Cosmos + Service Bus validation...' -ForegroundColor Cyan
$run = $null
for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
        $response = Invoke-WebRequest `
            -Uri "$runtimeEntryUrl/validation/run" `
            -Method Post `
            -Headers $headers `
            -ContentType 'application/json' `
            -SkipHttpErrorCheck `
            -TimeoutSec 60

        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            $run = $response.Content | ConvertFrom-Json
            break
        }
        Write-Host "Validation attempt $attempt returned HTTP $($response.StatusCode). RBAC/app propagation may still be settling; retrying in 15 seconds..." -ForegroundColor DarkGray
    } catch {
        Write-Host "Validation attempt $attempt failed while Azure dependencies settle; retrying in 15 seconds..." -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds 15
}
if (-not $run) { throw 'Synthetic Cosmos + Service Bus validation did not succeed within the propagation window.' }

$eventId = [string]$run.eventId
if ([string]::IsNullOrWhiteSpace($eventId)) { throw 'Validation endpoint did not return an eventId.' }

$expectedConsumers = @('inventory', 'payment', 'shipping', 'analytics')
$status = $null
Write-Host "Waiting for all Service Bus subscriptions to process EventId=$eventId ..." -ForegroundColor Cyan
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        $status = Invoke-RestMethod `
            -Uri "$runtimeEntryUrl/validation/status/$eventId" `
            -Method Get `
            -Headers $headers `
            -TimeoutSec 30

        $processed = @($status.processedConsumers)
        $missing = @($expectedConsumers | Where-Object { $_ -notin $processed })
        if ($missing.Count -eq 0) { break }
        Write-Host "Waiting on: $($missing -join ', ')" -ForegroundColor DarkGray
    } catch {
        Write-Host "Status poll $attempt failed transiently; retrying..." -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds 5
}

if (-not $status) { throw 'Unable to retrieve validation consumer status.' }
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

    $candidateCount = 0
    if ($LASTEXITCODE -eq 0 -and [int]::TryParse(($countText | Out-String).Trim(), [ref]$candidateCount) -and $candidateCount -gt 0) {
        $telemetryCount = $candidateCount
        break
    }
    Start-Sleep -Seconds 10
}
if ($telemetryCount -le 0) {
    throw 'Application Insights did not return request telemetry within the validation window.'
}

Write-Host 'Cleaning synthetic Cosmos validation receipts...' -ForegroundColor Cyan
$cleanup = Invoke-RestMethod `
    -Uri "$runtimeEntryUrl/validation/status/$eventId" `
    -Method Delete `
    -Headers $headers `
    -TimeoutSec 60

$evidence = [ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    environment = $Environment
    stackName = $stackName
    runtimeEntryMode = $entryMode
    runtimeEntryHostName = ([uri]$runtimeEntryUrl).Host
    runtimeHealthStatus = [int]$healthResponse.StatusCode
    frontDoorRuntimeValidated = $frontDoorDeployed
    frontDoorOmissionReason = $frontDoorDeployed ? '' : 'Validation subscription blocks Azure Front Door resource creation.'
    directOriginHostName = $primaryApiHostName
    directOriginStatus = $directOriginStatus
    directOriginRejected = $directOriginRejected
    directApiIngressTemporaryValidationException = (-not $frontDoorDeployed)
    validationEndpointRejectsMissingToken = $true
    cosmosAccountName = $cosmosAccountName
    cosmosLocalAuthDisabled = $true
    serviceBusNamespaceName = $serviceBusNamespaceName
    serviceBusLocalAuthDisabled = $true
    reusableAzureResourceCredentialsInAppSettings = $false
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
