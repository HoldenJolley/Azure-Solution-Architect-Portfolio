param(
    [string]$Location = 'eastus2',
    [string]$StackName = 'portfolio-prod-stack'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'
$identitySwitch = Join-Path $PSScriptRoot 'use-portfolio-deployment-identity.ps1'
$compiledParams = Join-Path ([System.IO.Path]::GetTempPath()) "portfolio-prod-$([guid]::NewGuid().ToString('N')).parameters.json"

az bicep build-params --file $params --outfile $compiledParams
if ($LASTEXITCODE -ne 0) { throw 'Failed to compile the production Bicep parameters.' }

try {
    # In GitHub Actions, switch from the initial ARM-compatible OIDC identity
    # to the dedicated UAMI before invoking Deployment Stacks. Local operators
    # retain whichever Azure CLI identity they authenticated with themselves.
    & $identitySwitch

    az stack sub create `
        --name $StackName `
        --location $Location `
        --template-file (Join-Path $infra 'main.bicep') `
        --parameters "@$compiledParams" `
        --action-on-unmanage deleteAll `
        --deny-settings-mode none `
        --validation-level Provider `
        --description 'Azure Solution Architect portfolio hosting stack' `
        --yes

    if ($LASTEXITCODE -ne 0) { throw 'Portfolio deployment stack creation or update failed.' }
}
finally {
    Remove-Item $compiledParams -ErrorAction SilentlyContinue
}
