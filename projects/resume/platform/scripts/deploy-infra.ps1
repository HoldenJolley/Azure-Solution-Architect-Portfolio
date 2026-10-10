param(
    [string]$Location = 'eastus2'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'

az deployment sub create `
    --name "portfolio-static-hosting-$((Get-Date).ToString('yyyyMMddHHmmss'))" `
    --location $Location `
    --template-file (Join-Path $infra 'main.bicep') `
    --parameters $params
