[CmdletBinding()]
param(
    [string]$Namespace = 'hybrid-lab',
    [string]$LabelSelector = 'app.kubernetes.io/name=hybrid-demo',
    [string]$ServiceName = 'hybrid-demo',
    [int]$IsolationSeconds = 30,
    [string]$OutputDirectory = './evidence'
)

$ErrorActionPreference = 'Stop'

if ($IsolationSeconds -lt 5 -or $IsolationSeconds -gt 120) {
    throw 'IsolationSeconds must be between 5 and 120 seconds.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = Join-Path $OutputDirectory "network-isolation-$timestamp.txt"
$policyName = "chaos-deny-ingress-$timestamp".ToLowerInvariant()
$chaosLabelKey = 'chaos-network-isolated'
$chaosLabelValue = 'true'
$podName = $null
$labelApplied = $false
$policyApplied = $false

function Write-Evidence {
    param([string]$Message)
    $line = "$(Get-Date -Format o) $Message"
    $line | Tee-Object -FilePath $outputPath -Append
}

Write-Evidence 'Starting controlled network-isolation experiment.'
Write-Evidence "Namespace=$Namespace Selector=$LabelSelector Service=$ServiceName IsolationSeconds=$IsolationSeconds"

try {
    $podsJson = kubectl get pods -n $Namespace -l $LabelSelector -o json
    if ($LASTEXITCODE -ne 0) {
        throw 'kubectl could not list target pods.'
    }

    $pods = ($podsJson | ConvertFrom-Json).items
    $readyPods = @($pods | Where-Object {
        $_.status.phase -eq 'Running' -and
        (@($_.status.containerStatuses | Where-Object { $_.ready }).Count -ge 1)
    })

    if ($readyPods.Count -lt 2) {
        throw "Expected at least 2 Ready application replicas before network isolation, found $($readyPods.Count)."
    }

    $target = Get-Random -InputObject $readyPods
    $podName = $target.metadata.name
    $nodeName = $target.spec.nodeName
    $podIp = $target.status.podIP

    $existingChaosLabel = $target.metadata.labels.$chaosLabelKey
    if ($null -ne $existingChaosLabel) {
        throw "Target pod already has label ${chaosLabelKey}=$existingChaosLabel. Refusing to overwrite a pre-existing chaos label."
    }

    Write-Evidence "Pre-chaos readyReplicas=$($readyPods.Count)"
    Write-Evidence "Selected pod=$podName node=$nodeName podIP=$podIp"

    kubectl label pod $podName -n $Namespace "${chaosLabelKey}=${chaosLabelValue}" --overwrite | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to label the target pod for network isolation.'
    }
    $labelApplied = $true

    $manifest = @"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $policyName
  namespace: $Namespace
  labels:
    app.kubernetes.io/part-of: hybrid-kubernetes-chaos
    chaos-experiment: network-isolation
spec:
  podSelector:
    matchLabels:
      ${chaosLabelKey}: "${chaosLabelValue}"
  policyTypes:
    - Ingress
  ingress: []
"@

    Write-Evidence "Applying temporary deny-ingress NetworkPolicy=$policyName to pod=$podName"
    $manifest | kubectl apply -f - | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the temporary NetworkPolicy.'
    }
    $policyApplied = $true

    # Allow the CNI a short propagation window before measuring the isolation period.
    Start-Sleep -Seconds 2

    $duringJson = kubectl get pod $podName -n $Namespace -o json
    if ($LASTEXITCODE -eq 0) {
        $duringPod = $duringJson | ConvertFrom-Json
        $duringReady = @($duringPod.status.containerStatuses | Where-Object { $_.ready }).Count -ge 1
        $duringRestarts = (@($duringPod.status.containerStatuses | Measure-Object -Property restartCount -Sum).Sum)
        Write-Evidence "During-isolation podPhase=$($duringPod.status.phase) ready=$duringReady restartCount=$duringRestarts"
    }

    Write-Evidence "Holding network isolation for ${IsolationSeconds}s. Availability impact is measured independently by availability-probe.ps1."
    Start-Sleep -Seconds $IsolationSeconds

    Write-Evidence 'Isolation interval complete; beginning cleanup.'
}
finally {
    if ($policyApplied) {
        kubectl delete networkpolicy $policyName -n $Namespace --ignore-not-found=true --wait=true | Tee-Object -FilePath $outputPath -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Evidence "Removed NetworkPolicy=$policyName"
        }
        else {
            Write-Evidence "WARNING=Failed to remove NetworkPolicy=$policyName automatically. Manual cleanup may be required."
        }
    }

    if ($labelApplied -and $podName) {
        kubectl label pod $podName -n $Namespace "${chaosLabelKey}-" 2>&1 | Tee-Object -FilePath $outputPath -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Evidence "Removed temporary label=$chaosLabelKey from pod=$podName"
        }
        else {
            Write-Evidence "WARNING=Failed to remove temporary label=$chaosLabelKey from pod=$podName automatically."
        }
    }
}

Start-Sleep -Seconds 2
$postJson = kubectl get pod $podName -n $Namespace -o json
if ($LASTEXITCODE -ne 0) {
    Write-Evidence 'RESULT=FAIL target pod could not be retrieved after network-policy cleanup.'
    throw 'Target pod could not be retrieved after network-policy cleanup.'
}

$postPod = $postJson | ConvertFrom-Json
$postReady = @($postPod.status.containerStatuses | Where-Object { $_.ready }).Count -ge 1
$postRestarts = (@($postPod.status.containerStatuses | Measure-Object -Property restartCount -Sum).Sum)
$postPhase = $postPod.status.phase

kubectl get pods -n $Namespace -l $LabelSelector -o wide | Tee-Object -FilePath $outputPath -Append

Write-Evidence "Post-chaos podPhase=$postPhase ready=$postReady restartCount=$postRestarts"

if ($postPhase -ne 'Running' -or -not $postReady) {
    Write-Evidence 'RESULT=FAIL target pod was not Running and Ready after network isolation cleanup.'
    throw 'Target pod was not Running and Ready after network isolation cleanup.'
}

Write-Evidence 'RESULT=PASS network isolation was injected and removed; inspect availability evidence for service impact.'
Write-Evidence "Evidence=$outputPath"
