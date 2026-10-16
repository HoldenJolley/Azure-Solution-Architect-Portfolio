param(
    [switch]$RunWhatIf,
    [string]$Location = 'eastus2'
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

        # CI uses the subscription deployment What-If because it supports the
        # GitHub OIDC service-principal token used by this workflow. Production
        # deployment itself is still managed by portfolio-prod-stack.
        az deployment sub what-if `
            --name $whatIfName `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --result-format ResourceIdOnly

        if ($LASTEXITCODE -ne 0) { throw 'Subscription deployment What-If failed.' }
    }
    finally {
        Remove-Item $compiledParams -ErrorAction SilentlyContinue
    }
}

Write-Host 'Static portfolio infrastructure validation completed successfully.'
