param(
    [switch]$RunWhatIf,
    [string]$Location = 'eastus2',
    [string]$StackName = 'portfolio-prod-stack'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$infra = Join-Path $root 'infra'
$params = Join-Path $infra 'environments/prod.bicepparam'

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

        # Perform provider-aware semantic and RBAC validation using the standard
        # subscription deployment engine, which supports the GitHub OIDC
        # service-principal token used by this workflow.
        az deployment sub what-if `
            --name $whatIfName `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --result-format ResourceIdOnly

        if ($LASTEXITCODE -ne 0) { throw 'Subscription deployment What-If failed.' }

        # Validate the Deployment Stack definition itself with static/template
        # validation. Deployment Stack provider-level preflight currently rejects
        # this federated application token, while the ARM What-If above already
        # performs provider and RBAC validation.
        az stack sub validate `
            --name $StackName `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --action-on-unmanage deleteAll `
            --deny-settings-mode none `
            --validation-level Template `
            --description 'Azure Solution Architect portfolio hosting stack'

        if ($LASTEXITCODE -ne 0) { throw 'Deployment Stack template validation failed.' }
    }
    finally {
        Remove-Item $compiledParams -ErrorAction SilentlyContinue
    }
}

Write-Host 'Static portfolio infrastructure validation completed successfully.'
