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
        $subscriptionId = (az account show --query id --output tsv).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $subscriptionId) { throw 'Unable to determine the current Azure subscription.' }

        $stackId = "/subscriptions/$subscriptionId/providers/Microsoft.Resources/deploymentStacks/$StackName"
        $whatIfName = "portfolio-prod-$((Get-Date).ToString('yyyyMMddHHmmss'))"

        az stack-whatif sub create `
            --name $whatIfName `
            --stack-id $stackId `
            --retention-interval PT3H `
            --location $Location `
            --template-file (Join-Path $infra 'main.bicep') `
            --parameters "@$compiledParams" `
            --action-on-unmanage deleteAll `
            --deny-settings-mode none `
            --description 'Portfolio deployment stack preflight' `
            --no-color

        if ($LASTEXITCODE -ne 0) { throw 'Deployment Stack What-If failed.' }
    }
    finally {
        Remove-Item $compiledParams -ErrorAction SilentlyContinue
    }
}

Write-Host 'Static portfolio infrastructure validation completed successfully.'
