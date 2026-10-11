param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [string]$DeploymentLocation = 'eastus2'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra/foundation.bicep'
$params = Join-Path $root "infra/environments/$Environment.foundation.bicepparam"

az deployment sub create `
  --location $DeploymentLocation `
  --name "ageverify-$Environment-foundation-$(Get-Date -Format yyyyMMddHHmmss)" `
  --template-file $template `
  --parameters $params
