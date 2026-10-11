param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [Parameter(Mandatory=$true)][string]$GatewayImage,
  [Parameter(Mandatory=$true)][string]$InferenceImage,
  [string]$DeploymentLocation = 'eastus2'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra/workloads.bicep'
$params = Join-Path $root "infra/environments/$Environment.workloads.bicepparam"

az deployment sub create `
  --location $DeploymentLocation `
  --name "ageverify-$Environment-workloads-$(Get-Date -Format yyyyMMddHHmmss)" `
  --template-file $template `
  --parameters $params `
  --parameters gatewayImage=$GatewayImage inferenceImage=$InferenceImage
