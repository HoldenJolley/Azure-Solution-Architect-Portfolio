[CmdletBinding()]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [switch]$RunWhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$referenceTemplate = Join-Path $repoRoot 'infra/main.bicep'
$referenceParams = Join-Path $repoRoot "infra/environments/$Environment.bicepparam"
$validationTemplate = Join-Path $repoRoot 'infra/validation.bicep'
$validationParams = Join-Path $repoRoot 'infra/environments/dev.validation.bicepparam'

foreach ($template in @($referenceTemplate, $validationTemplate)) {
    Write-Host "Linting $template" -ForegroundColor Cyan
    az bicep lint --file $template
    if ($LASTEXITCODE -ne 0) { throw "Bicep lint failed: $template" }

    Write-Host "Building $template" -ForegroundColor Cyan
    az bicep build --file $template --stdout | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $template" }
}

Write-Host "Building reference parameter file $referenceParams" -ForegroundColor Cyan
az bicep build-params --file $referenceParams --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Reference Bicep parameter build failed.' }

Write-Host "Building temporary validation parameter file $validationParams" -ForegroundColor Cyan
az bicep build-params --file $validationParams --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Temporary validation Bicep parameter build failed.' }

if ($RunWhatIf) {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) { throw 'Run az login before -RunWhatIf.' }

    $whatIfTemplate = $Environment -eq 'dev' ? $validationTemplate : $referenceTemplate
    $whatIfParams = $Environment -eq 'dev' ? $validationParams : $referenceParams

    if ($Environment -eq 'dev') {
        Write-Host 'Running subscription-scope what-if for the actual temporary validation profile (Azure Front Door intentionally omitted).' -ForegroundColor Cyan
    } else {
        Write-Host "Running subscription-scope what-if for the $Environment reference profile." -ForegroundColor Cyan
    }

    az deployment sub what-if `
        --location 'eastus2' `
        --template-file $whatIfTemplate `
        --parameters $whatIfParams
    if ($LASTEXITCODE -ne 0) { throw 'Azure what-if failed.' }
}

Write-Host 'Validation completed successfully.' -ForegroundColor Green
