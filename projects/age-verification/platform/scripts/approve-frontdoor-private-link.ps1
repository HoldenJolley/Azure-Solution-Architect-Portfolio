[CmdletBinding()]
param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [string]$WorkloadName = 'ageverify',
  [int]$Attempts = 24,
  [int]$DelaySeconds = 10
)

$ErrorActionPreference = 'Stop'
$prefix = "$WorkloadName-$Environment"
$rg = "$prefix-platform-rg"
$envName = "$prefix-cae"

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
  $connections = az network private-endpoint-connection list `
    --name $envName `
    --resource-group $rg `
    --type Microsoft.App/managedEnvironments `
    --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id" -o tsv
  if ($LASTEXITCODE -ne 0) { throw 'Failed to query Container Apps private endpoint connections.' }

  if ($connections) {
    foreach ($connection in @($connections -split "`n" | Where-Object { $_ })) {
      az network private-endpoint-connection approve `
        --id $connection `
        --description 'Approved Front Door private origin connection for temporary portfolio validation'
      if ($LASTEXITCODE -ne 0) { throw "Failed to approve private endpoint connection '$connection'." }
    }
    Write-Host 'Front Door private-link origin connection approved.' -ForegroundColor Green
    exit 0
  }

  $approved = az network private-endpoint-connection list `
    --name $envName `
    --resource-group $rg `
    --type Microsoft.App/managedEnvironments `
    --query "[?properties.privateLinkServiceConnectionState.status=='Approved'].id | [0]" -o tsv
  if ($LASTEXITCODE -ne 0) { throw 'Failed to query approved private endpoint connections.' }
  if ($approved) {
    Write-Host 'Front Door private-link origin connection is already approved.' -ForegroundColor Green
    exit 0
  }

  if ($attempt -lt $Attempts) {
    Write-Host "Private-link request has not appeared yet ($attempt/$Attempts); waiting $DelaySeconds seconds..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $DelaySeconds
  }
}

throw "No pending or approved Front Door private-link connection appeared after $Attempts attempts."
