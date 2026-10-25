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

$podsJson = kubectl get pods -n $Namespace -l $LabelSelector -o json
if ($LASTEXITCODE -ne 0) {
    throw 'kubectl could not list target pods.'
}

$pods = ($podsJson | ConvertFrom-Json).items
$runningPods = @($pods | Where-Object { $_.status.phase -eq 'Running' })

if ($runningPods.Count -lt 2) {
    throw "Expected at least 2 running replicas before chaos, found $($runningPods.Count)."
}

$target = Get-Random -InputObject $runningPods
Write-Evidence "Pre-chaos running replicas=$($runningPods.Count)"
Write-Evidence "Selected pod=$($target.metadata.name) node=$($target.spec.nodeName)"

kubectl delete pod $target.metadata.name -n $Namespace --wait=false | Tee-Object -FilePath $outputPath -Append
if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete pod $($target.metadata.name)."
}

$recoveryStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Evidence "Waiting for deployment rollout to return to healthy state..."

kubectl rollout status "deployment/$Deployment" -n $Namespace --timeout="${RecoveryTimeoutSeconds}s" | Tee-Object -FilePath $outputPath -Append
$rolloutExit = $LASTEXITCODE
$recoveryStopwatch.Stop()

kubectl get pods -n $Namespace -l $LabelSelector -o wide | Tee-Object -FilePath $outputPath -Append

if ($rolloutExit -ne 0) {
    Write-Evidence "RESULT=FAIL recovery exceeded ${RecoveryTimeoutSeconds}s."
    throw 'Deployment did not recover within the configured timeout.'
}

Write-Evidence "RESULT=PASS recoverySeconds=$([math]::Round($recoveryStopwatch.Elapsed.TotalSeconds, 2))"
Write-Evidence "Evidence=$outputPath"
