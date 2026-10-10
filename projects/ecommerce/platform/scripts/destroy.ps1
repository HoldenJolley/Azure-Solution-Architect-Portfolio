[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('dev','test','prod')]
    [string]$Environment = 'dev',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$resourceGroups = @(
    "rg-ecommerce-$Environment-global",
    "rg-ecommerce-$Environment-eus2",
    "rg-ecommerce-$Environment-wus2"
)

foreach ($rg in $resourceGroups) {
    $exists = az group exists --name $rg
    if ($exists -eq 'true') {
        if ($Force -or $PSCmdlet.ShouldProcess($rg, 'Delete resource group')) {
            Write-Host "Deleting $rg" -ForegroundColor Yellow
            az group delete --name $rg --yes --no-wait
            if ($LASTEXITCODE -ne 0) { throw "Failed to start deletion for $rg" }
        }
    }
}
