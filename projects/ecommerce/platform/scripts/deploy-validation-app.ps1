[CmdletBinding()]
param(
    [ValidateSet('dev')]
    [string]$Environment = 'dev',
    [string]$RuntimeDirectory,
    [string]$EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/ValidationApp/ValidationApp.csproj'
$stackName = "ecommerce-$Environment-validation-stack"
$primaryResourceGroup = "rg-ecommerce-$Environment-eus2"

if (-not $RuntimeDirectory) {
    $RuntimeDirectory = Join-Path $repoRoot '_runtime'
}
if (-not $EvidenceDirectory) {
    $EvidenceDirectory = Join-Path $repoRoot '_evidence/application'
}

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure.' }

$stack = az stack sub show --name $stackName --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $stack) {
    throw "Deployment Stack '$stackName' does not exist. Deploy infrastructure before the validation application."
}
if ($stack.properties.provisioningState -ne 'Succeeded') {
    throw "Deployment Stack '$stackName' is not ready. Provisioning state: $($stack.properties.provisioningState)"
}

$apps = az webapp list --resource-group $primaryResourceGroup --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate web apps in '$primaryResourceGroup'." }

$expectedComponents = @('api', 'inventory-worker', 'payment-worker', 'shipping-worker', 'analytics-worker')
$appMap = [ordered]@{}

foreach ($component in $expectedComponents) {
    $matches = @($apps | Where-Object { $_.tags.component -eq $component })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one App Service tagged component='$component' in '$primaryResourceGroup'; found $($matches.Count)."
    }
    $appMap[$component] = $matches[0]
}

New-Item -ItemType Directory -Path $RuntimeDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
$publishDirectory = Join-Path $RuntimeDirectory 'publish'
$zipPath = Join-Path $RuntimeDirectory 'ecommerce-validation.zip'
$tokenPath = Join-Path $RuntimeDirectory 'validation-token.txt'

Remove-Item $publishDirectory -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

Write-Host 'Publishing .NET validation workload...' -ForegroundColor Cyan
dotnet publish $project --configuration Release --output $publishDirectory --nologo
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

Compress-Archive -Path (Join-Path $publishDirectory '*') -DestinationPath $zipPath -CompressionLevel Optimal

$validationToken = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
if ($env:GITHUB_ACTIONS -eq 'true') {
    Write-Host "::add-mask::$validationToken"
}
Set-Content -Path $tokenPath -Value $validationToken -NoNewline -Encoding utf8

$api = $appMap['api']
Write-Host "Enabling token-protected validation endpoints on $($api.name)..." -ForegroundColor Cyan
az webapp config appsettings set `
    --resource-group $primaryResourceGroup `
    --name $api.name `
    --settings ENABLE_VALIDATION_ENDPOINTS=true VALIDATION_TOKEN=$validationToken `
    --output none
if ($LASTEXITCODE -ne 0) { throw 'Failed to configure temporary validation endpoints.' }

$deployedApps = @()
foreach ($component in $expectedComponents) {
    $webApp = $appMap[$component]
    Write-Host "Deploying validation package to $component ($($webApp.name))..." -ForegroundColor Cyan
    az webapp deploy `
        --resource-group $primaryResourceGroup `
        --name $webApp.name `
        --src-path $zipPath `
        --type zip `
        --restart true `
        --output none
    if ($LASTEXITCODE -ne 0) { throw "Application deployment failed for '$($webApp.name)'." }

    $deployedApps += [ordered]@{
        component = $component
        name = $webApp.name
        defaultHostName = $webApp.defaultHostName
    }
}

$evidence = [ordered]@{
    capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    subscriptionId = $account.id
    environment = $Environment
    stackName = $stackName
    primaryResourceGroup = $primaryResourceGroup
    validationEndpointsEnabled = $true
    validationTokenStoredInEvidence = $false
    applications = $deployedApps
}
$evidence | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $EvidenceDirectory 'application-deployment.json') -Encoding utf8

Write-Host "Validation applications deployed. Ephemeral token file: $tokenPath" -ForegroundColor Green
Write-Host 'The token is intentionally excluded from evidence artifacts and must be deleted after smoke testing.' -ForegroundColor Yellow
