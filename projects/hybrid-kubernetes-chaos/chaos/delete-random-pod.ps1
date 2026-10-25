[CmdletBinding()]
param(
    [string]$Namespace = 'hybrid-lab',
    [string]$Deployment = 'hybrid-demo',
    [string]$LabelSelector = 'app.kubernetes.io/name=hybrid-demo',
    [int]$RecoveryTimeoutSeconds = 120,
    [string]$OutputDirectory = './evidence'
)

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = Join-Path $OutputDirectory "pod-delete-$timestamp.txt"

function Write-Evidence {
    param([string]$Message)
    $line = "$(Get-Date -Format o) $Message"
    $line | Tee-Object -FilePath $outputPath -Append
}

Write-Evidence "Starting controlled pod deletion experiment."
Write-Evidence "Namespace=$Namespace Deployment=$Deployment Selector=$LabelSelector"

$deploymentJson = kubectl get deployment $Deployment -n $Namespace -o json
if ($LASTEXITCODE -ne 0) {
    throw "kubectl could not read deployment $Deployment."
}
$deploymentState = $deploymentJson | ConvertFrom-Json
$desiredReplicas = [int]$deploymentState.spec.replicas

$podsJson = kubectl get pods -n $Namespace -l $LabelSelector -o json
if ($LASTEXITCODE -ne 0) {
    throw 'kubectl could not list target pods.'
}

$pods = ($podsJson | ConvertFrom-Json).items
$readyPods = @($pods | Where-Object {
    $_.status.phase -eq 'Running' -and
    $_.status.containerStatuses -and
    (@($_.status.containerStatuses | Where-Object { -not $_.ready }).Count -eq 0)
})

if ($readyPods.Count -ne $desiredReplicas) {
    throw "Expected $desiredReplicas ready replicas before chaos, found $($readyPods.Count)."
}

$target = Get-Random -InputObject $readyPods
Write-Evidence "Pre-chaos desiredReplicas=$desiredReplicas readyReplicas=$($readyPods.Count)"
Write-Evidence "Selected pod=$($target.metadata.name) node=$($target.spec.nodeName)"

kubectl delete pod $target.metadata.name -n $Namespace --wait=false | Tee-Object -FilePath $outputPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete pod $($target.metadata.name)."
}

$recoveryStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$recovered = $false
Write-Evidence 'Waiting for the deployment to restore the desired number of Ready replicas...'

while ($recoveryStopwatch.Elapsed.TotalSeconds -lt $RecoveryTimeoutSeconds) {
    Start-Sleep -Seconds 1

    $currentDeploymentJson = kubectl get deployment $Deployment -n $Namespace -o json 2>$null
    if ($LASTEXITCODE -ne 0) {
        continue
    }

    $currentDeployment = $currentDeploymentJson | ConvertFrom-Json
    $readyReplicas = if ($null -eq $currentDeployment.status.readyReplicas) { 0 } else { [int]$currentDeployment.status.readyReplicas }
    $availableReplicas = if ($null -eq $currentDeployment.status.availableReplicas) { 0 } else { [int]$currentDeployment.status.availableReplicas }

    Write-Host ("Recovery check: ready={0}/{1} available={2}/{1} elapsed={3}s" -f $readyReplicas, $desiredReplicas, $availableReplicas, [math]::Round($recoveryStopwatch.Elapsed.TotalSeconds, 1))

    if ($readyReplicas -ge $desiredReplicas -and $availableReplicas -ge $desiredReplicas) {
        $recovered = $true
        break
    }
}

$recoveryStopwatch.Stop()

kubectl get pods -n $Namespace -l $LabelSelector -o wide | Tee-Object -FilePath $outputPath -Append

if (-not $recovered) {
    Write-Evidence "RESULT=FAIL recovery exceeded ${RecoveryTimeoutSeconds}s."
    throw 'Deployment did not recover within the configured timeout.'
}

Write-Evidence "RESULT=PASS recoverySeconds=$([math]::Round($recoveryStopwatch.Elapsed.TotalSeconds, 2))"
Write-Evidence "Evidence=$outputPath"
