param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [switch]$RunWhatIf
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'

az bicep install | Out-Null
az bicep lint --file "$infra/foundation.bicep"
az bicep build --file "$infra/foundation.bicep" --stdout | Out-Null
az bicep lint --file "$infra/workloads.bicep"
az bicep build --file "$infra/workloads.bicep" --stdout | Out-Null
az bicep build-params --file "$infra/environments/$Environment.foundation.bicepparam" --stdout | Out-Null
az bicep build-params --file "$infra/environments/$Environment.workloads.bicepparam" --stdout | Out-Null

Write-Host 'Bicep lint/build completed.' -ForegroundColor Green

if ($RunWhatIf) {
  az deployment sub what-if `
    --location eastus2 `
    --name "ageverify-$Environment-foundation-whatif" `
    --template-file "$infra/foundation.bicep" `
    --parameters "$infra/environments/$Environment.foundation.bicepparam"
}
