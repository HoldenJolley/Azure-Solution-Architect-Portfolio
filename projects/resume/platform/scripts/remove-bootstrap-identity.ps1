param(
    [string]$ResourceGroupName = 'portfolio-bootstrap-rg',
    [string]$IdentityName = 'github-portfolio-prod-mi',
    [switch]$ConfirmDelete
)

$ErrorActionPreference = 'Stop'

if (-not $ConfirmDelete) {
    throw "Refusing to delete deployment identity '$IdentityName'. Re-run with -ConfirmDelete after the portfolio stack is removed."
}

$subscriptionId = (az account show --query id --output tsv).Trim()
if ($LASTEXITCODE -ne 0 -or -not $subscriptionId) {
    throw 'Unable to determine the current Azure subscription.'
}
$scope = "/subscriptions/$subscriptionId"

$identityJson = az identity show `
    --resource-group $ResourceGroupName `
    --name $IdentityName `
    --output json 2>$null

if ($LASTEXITCODE -eq 0 -and $identityJson) {
    $identity = $identityJson | ConvertFrom-Json
    if ($identity.principalId) {
        Write-Host "Removing Contributor assignment for deployment identity '$IdentityName'..."
        az role assignment delete `
            --assignee-object-id $identity.principalId `
            --role Contributor `
            --scope $scope
        if ($LASTEXITCODE -ne 0) { throw 'Failed to remove deployment identity Contributor role assignment.' }
    }
}
else {
    Write-Host "Managed identity '$IdentityName' was not found; continuing with bootstrap resource-group cleanup."
}

az group show --name $ResourceGroupName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting bootstrap resource group '$ResourceGroupName'..."
    az group delete --name $ResourceGroupName --yes
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete bootstrap resource group '$ResourceGroupName'." }
}
else {
    Write-Host "Bootstrap resource group '$ResourceGroupName' was not found."
}

Write-Host 'Portfolio deployment identity bootstrap resources were removed.'
