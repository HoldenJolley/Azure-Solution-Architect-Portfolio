[CmdletBinding()]
param(
    [string]$Namespace = 'hybrid-lab',
    [string]$LabelSelector = 'app.kubernetes.io/name=hybrid-demo',
    [string]$Container = 'nginx',
    [int]$StressSeconds = 30,
    [string]$OutputDirectory = './evidence'
)

$ErrorActionPreference = 'Stop'

if ($StressSeconds -lt 5 -or $StressSeconds -gt 120) {
    throw 'StressSeconds must be between 5 and 120 seconds.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = Join-Path $OutputDirectory "cpu-stress-$timestamp.txt"

function Write-Evidence {
    param([string]$Message)
    $line = "$(Get-Date -Format o) $Message"
    $line | Tee-Object -FilePath $outputPath -Append
}

Write-Evidence 'Starting controlled CPU saturation experiment.'
Write-Evidence "Namespace=$Namespace Selector=$LabelSelector Container=$Container StressSeconds=$StressSeconds"

$podsJson = kubectl get pods -n $Namespace -l $LabelSelector -o json
if ($LASTEXITCODE -ne 0) {
    throw 'kubectl could not list target pods.'
}

$pods = ($podsJson | ConvertFrom-Json).items
$readyPods = @($pods | Where-Object {
    $_.status.phase -eq 'Running' -and
    (@($_.status.containerStatuses | Where-Object { $_.name -eq $Container -and $_.ready }).Count -eq 1)
})

if ($readyPods.Count -lt 2) {
    throw "Expected at least 2 Ready application replicas before CPU stress, found $($readyPods.Count)."
}

$target = Get-Random -InputObject $readyPods
$podName = $target.metadata.name
$nodeName = $target.spec.nodeName
$cpuLimit = ($target.spec.containers | Where-Object { $_.name -eq $Container }).resources.limits.cpu

Write-Evidence "Pre-chaos readyReplicas=$($readyPods.Count)"
Write-Evidence "Selected pod=$podName node=$nodeName cpuLimit=$cpuLimit"

kubectl exec -n $Namespace $podName -c $Container -- sh -c 'command -v timeout >/dev/null 2>&1'
if ($LASTEXITCODE -ne 0) {
    throw "The target container does not provide the BusyBox timeout command required for a bounded stress run."
}

Write-Evidence "Injecting one busy-loop CPU worker for ${StressSeconds}s. The pod remains alive; the container CPU limit should throttle it."
$stressStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$stressCommand = "timeout ${StressSeconds}s sh -c 'while :; do :; done'"
kubectl exec -n $Namespace $podName -c $Container -- sh -c $stressCommand | Tee-Object -FilePath $outputPath -Append
$stressExit = $LASTEXITCODE
$stressStopwatch.Stop()

# BusyBox timeout commonly returns 124 when the timeout expires; treat 0 or 124 as an expected bounded completion.
if ($stressExit -ne 0 -and $stressExit -ne 124) {
    Write-Evidence "RESULT=FAIL kubectlExecExit=$stressExit"
    throw "CPU stress command exited unexpectedly with code $stressExit."
}

$postJson = kubectl get pod $podName -n $Namespace -o json
if ($LASTEXITCODE -ne 0) {
    Write-Evidence 'RESULT=FAIL target pod could not be retrieved after stress.'
    throw 'Target pod could not be retrieved after CPU stress.'
}

$postPod = $postJson | ConvertFrom-Json
$postStatus = @($postPod.status.containerStatuses | Where-Object { $_.name -eq $Container })[0]
$postReady = [bool]$postStatus.ready
$postRestarts = [int]$postStatus.restartCount
$postPhase = $postPod.status.phase

kubectl get pods -n $Namespace -l $LabelSelector -o wide | Tee-Object -FilePath $outputPath -Append

Write-Evidence "Post-chaos podPhase=$postPhase ready=$postReady restartCount=$postRestarts elapsedSeconds=$([math]::Round($stressStopwatch.Elapsed.TotalSeconds, 2))"

if ($postPhase -ne 'Running' -or -not $postReady) {
    Write-Evidence 'RESULT=FAIL target pod was not Ready after the bounded CPU stress period.'
    throw 'Target pod was not Ready after the bounded CPU stress period.'
}

Write-Evidence 'RESULT=PASS target pod remained Running and Ready after bounded CPU saturation.'
Write-Evidence "Evidence=$outputPath"
