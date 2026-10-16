param(
    [string]$Location = 'eastus2',
    [string]$StackName = 'portfolio-prod-stack'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'
$compiledParams = Join-Path ([System.IO.Path]::GetTempPath()) "portfolio-prod-$([guid]::NewGuid().ToString('N')).parameters.json"

az bicep build-params --file $params --outfile $compiledParams
if ($LASTEXITCODE -ne 0) { throw 'Failed to compile the production Bicep parameters.' }

try {
    # Provider/RBAC validation is performed by the preceding ARM What-If job.
    # Template validation here avoids repeating Deployment Stack provider-level
    # preflight, which rejects the federated application token before deployment.
    az stack sub create `
        --name $StackName `
        --location $Location `
        --template-file (Join-Path $infra 'main.bicep') `
        --parameters "@$compiledParams" `
        --action-on-unmanage deleteAll `
        --deny-settings-mode none `
        --validation-level Template `
        --description 'Azure Solution Architect portfolio hosting stack' `
        --yes

    if ($LASTEXITCODE -ne 0) { throw 'Portfolio deployment stack creation or update failed.' }
}
finally {
    Remove-Item $compiledParams -ErrorAction SilentlyContinue
}
