param(
    [switch]$RunWhatIf,
    [string]$Location = 'eastus2',
    [string]$StackName = 'portfolio-prod-stack'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'
$identitySwitch = Join-Path $PSScriptRoot 'use-portfolio-deployment-identity.ps1'

az bicep install | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to install or locate the Bicep CLI.' }

az bicep lint --file (Join-Path $infra 'main.bicep')
if ($LASTEXITCODE -ne 0) { throw 'Bicep lint failed.' }

az bicep build --file (Join-Path $infra 'main.bicep') --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

az bicep build-params --file $params --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep parameter build failed.' }

if ($RunWhatIf) {
    $compiledParams = Join-Path ([System.IO.Path]::GetTempPath()) "portfolio-prod-$([guid]::NewGuid().ToString('N')).parameters.json"
    az bicep build-params --file $params --outfile $compiledParams
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile the production Bicep parameters for What-If.' }

    try {
        $whatIfName = "portfolio-prod-$((Get-Date).ToString('yyyyMMddHHmmss'))"

        # Standard ARM What-If runs under the workflow's initial OIDC identity.
        az deployment sub what-if `
            --name $whatIfName `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --result-format ResourceIdOnly

        if ($LASTEXITCODE -ne 0) { throw 'Subscription deployment What-If failed.' }

        # Deployment Stacks requires an access token carrying the managed
        # identity principal claim. GitHub Actions switches to the dedicated
        # UAMI here; local operators retain their current Azure CLI identity.
        & $identitySwitch

        az stack sub validate `
            --name $StackName `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --action-on-unmanage deleteAll `
            --deny-settings-mode none `
            --validation-level Provider `
            --description 'Azure Solution Architect portfolio hosting stack'

        if ($LASTEXITCODE -ne 0) { throw 'Deployment Stack provider validation failed.' }
    }
    finally {
        Remove-Item $compiledParams -ErrorAction SilentlyContinue
    }
}

Write-Host 'Static portfolio infrastructure validation completed successfully.'
