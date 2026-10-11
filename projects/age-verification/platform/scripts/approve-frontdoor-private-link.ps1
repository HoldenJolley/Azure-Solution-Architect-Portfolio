param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [string]$WorkloadName = 'ageverify'
)

$ErrorActionPreference = 'Stop'
$prefix = "$WorkloadName-$Environment"
$rg = "$prefix-platform-rg"
$envName = "$prefix-cae"

$connections = az network private-endpoint-connection list `
  --name $envName `
  --resource-group $rg `
  --type Microsoft.App/managedEnvironments `
  --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id" -o tsv

if (-not $connections) {
  Write-Host 'No pending private endpoint connections found.'
  exit 0
}

foreach ($connection in $connections) {
  az network private-endpoint-connection approve `
    --id $connection `
    --description 'Approved Front Door private origin connection'
}
