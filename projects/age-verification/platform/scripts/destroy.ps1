param(
  [ValidateSet('dev','test','prod')]
  [string]$Environment = 'dev',
  [string]$WorkloadName = 'ageverify'
)

$ErrorActionPreference = 'Stop'
$prefix = "$WorkloadName-$Environment"
$groups = @(
  "$prefix-platform-rg",
  "$prefix-network-rg",
  "$prefix-security-rg",
  "$prefix-monitor-rg"
)

Write-Warning "This deletes the complete $Environment age-verification landing zone."
foreach ($rg in $groups) {
  az group delete --name $rg --yes --no-wait
}
