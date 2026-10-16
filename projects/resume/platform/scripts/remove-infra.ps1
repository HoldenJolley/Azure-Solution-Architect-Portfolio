param(
    [string]$StackName = 'portfolio-prod-stack',
    [switch]$ConfirmDelete
)

$ErrorActionPreference = 'Stop'

if (-not $ConfirmDelete) {
    throw "Refusing to delete '$StackName'. Re-run with -ConfirmDelete after reviewing the stack contents."
}

az stack sub show --name $StackName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment stack '$StackName' was not found. Nothing to remove."
    exit 0
}

Write-Host "Deleting deployment stack '$StackName' and all resources/resource groups it manages..."
az stack sub delete `
    --name $StackName `
    --action-on-unmanage deleteAll `
    --yes

if ($LASTEXITCODE -ne 0) { throw "Failed to delete deployment stack '$StackName'." }
Write-Host "Deployment stack '$StackName' and its managed infrastructure were removed."
