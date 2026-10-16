[CmdletBinding()]
param(
    [ValidateSet('dev')]
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
$resourceGroup = "rg-ecommerce-$Environment-eus2"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { throw 'Not logged into Azure.' }

$apiName = az webapp list `
    --resource-group $resourceGroup `
    --query "[?tags.component=='api'].name | [0]" `
    --output tsv 2>$null

$apiName = ($apiName | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apiName)) {
    Write-Warning "No API App Service was found in '$resourceGroup'; there are no temporary validation settings to remove."
    return
}

Write-Host "Removing temporary validation settings from $apiName..." -ForegroundColor Cyan
az webapp config appsettings delete `
    --resource-group $resourceGroup `
    --name $apiName `
    --setting-names ENABLE_VALIDATION_ENDPOINTS VALIDATION_TOKEN `
    --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to remove temporary validation settings from '$apiName'." }

$remaining = @(az webapp config appsettings list `
    --resource-group $resourceGroup `
    --name $apiName `
    --query "[?name=='ENABLE_VALIDATION_ENDPOINTS' || name=='VALIDATION_TOKEN'].name" `
    --output tsv 2>$null)

if ($LASTEXITCODE -ne 0) { throw 'Unable to verify temporary setting removal.' }
if (@($remaining | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw 'Temporary validation settings are still present after cleanup.'
}

Write-Host 'Temporary validation endpoints are disabled and the token setting is removed.' -ForegroundColor Green
