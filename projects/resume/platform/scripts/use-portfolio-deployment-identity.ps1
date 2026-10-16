param(
    [string]$ClientId = '928d071b-e664-4cc3-b6aa-a740b65eca3a'
)

$ErrorActionPreference = 'Stop'

# Local operators can keep using their existing Azure CLI identity. In GitHub
# Actions, request a fresh short-lived OIDC token and exchange it for the
# dedicated portfolio deployment managed identity.
if (-not $env:GITHUB_ACTIONS) {
    Write-Host 'GitHub Actions not detected; retaining the current Azure CLI identity.'
    return
}

if (-not $env:ACTIONS_ID_TOKEN_REQUEST_URL -or -not $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    throw 'GitHub OIDC token request variables are unavailable. Ensure id-token: write is granted.'
}

$currentAccount = az account show --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $currentAccount.id -or -not $currentAccount.tenantId) {
    throw 'Unable to determine the current Azure subscription and tenant before switching identities.'
}

$subscriptionId = $currentAccount.id
$tenantId = $currentAccount.tenantId
$separator = if ($env:ACTIONS_ID_TOKEN_REQUEST_URL.Contains('?')) { '&' } else { '?' }
$audience = [uri]::EscapeDataString('api://AzureADTokenExchange')
$requestUri = "$($env:ACTIONS_ID_TOKEN_REQUEST_URL)$separator`audience=$audience"

$response = Invoke-RestMethod `
    -Method Get `
    -Uri $requestUri `
    -Headers @{ Authorization = "Bearer $($env:ACTIONS_ID_TOKEN_REQUEST_TOKEN)" }

if (-not $response.value) {
    throw 'GitHub did not return an OIDC token for the portfolio deployment identity.'
}

az login `
    --service-principal `
    --username $ClientId `
    --tenant $tenantId `
    --federated-token $response.value `
    --output none

if ($LASTEXITCODE -ne 0) { throw 'Failed to authenticate as the portfolio deployment managed identity.' }

az account set --subscription $subscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Failed to restore the target Azure subscription after managed-identity login.' }

$activeClientId = (az account show --query user.name --output tsv).Trim()
if ($LASTEXITCODE -ne 0 -or $activeClientId -ne $ClientId) {
    throw 'Azure CLI did not switch to the expected portfolio deployment managed identity.'
}

Write-Host "Azure CLI switched to portfolio deployment managed identity $ClientId."
