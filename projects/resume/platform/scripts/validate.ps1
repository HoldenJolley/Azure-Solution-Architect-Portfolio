param(
    [switch]$RunWhatIf
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'

az bicep install | Out-Null
az bicep lint --file (Join-Path $infra 'main.bicep')
az bicep build --file (Join-Path $infra 'main.bicep') --stdout | Out-Null
az bicep build-params --file $params --stdout | Out-Null

if ($RunWhatIf) {
    az deployment sub what-if `
        --location eastus2 `
        --template-file (Join-Path $infra 'main.bicep') `
        --parameters $params
}

Write-Host 'Static portfolio infrastructure validation completed successfully.'
