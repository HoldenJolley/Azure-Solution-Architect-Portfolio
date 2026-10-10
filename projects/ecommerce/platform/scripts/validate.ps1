[CmdletBinding()]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [switch]$RunWhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$main = Join-Path $repoRoot 'infra/main.bicep'
$params = Join-Path $repoRoot "infra/environments/$Environment.bicepparam"

Write-Host "Linting $main" -ForegroundColor Cyan
az bicep lint --file $main
if ($LASTEXITCODE -ne 0) { throw 'Bicep lint failed.' }

Write-Host 'Building Bicep template' -ForegroundColor Cyan
az bicep build --file $main --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

Write-Host 'Building parameter file' -ForegroundColor Cyan
az bicep build-params --file $params --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep parameter build failed.' }

if ($RunWhatIf) {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) { throw 'Run az login before -RunWhatIf.' }

    Write-Host 'Running subscription-scope what-if' -ForegroundColor Cyan
    az deployment sub what-if `
        --location 'eastus2' `
        --template-file $main `
        --parameters $params
    if ($LASTEXITCODE -ne 0) { throw 'Azure what-if failed.' }
}

Write-Host 'Validation completed successfully.' -ForegroundColor Green
