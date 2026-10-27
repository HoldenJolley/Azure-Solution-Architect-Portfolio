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
$probePodName = "chaos-direct-probe-$timestamp".ToLowerInvariant()
$chaosLabelKey = 'chaos-network-isolated'
$chaosLabelValue = 'true'
$podName = $null
$podIp = $null
$labelApplied = $false
$policyApplied = $false
$probeCreated = $false

function Write-Evidence {
    param([string]$Message)
    $line = "$(Get-Date -Format o) $Message"
    $line | Tee-Object -FilePath $outputPath -Append
}

function Test-DirectEndpoint {
    param(
        [string]$ProbePod,
        [string]$TargetIp
    )

    $raw = kubectl exec -n $Namespace $ProbePod -- curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "http://${TargetIp}:80/" 2>&1
    $exitCode = $LASTEXITCODE
    $text = (($raw | ForEach-Object { "$_" }) -join ' ').Trim()
    $match = [regex]::Match($text, '(?<!\d)(\d{3})(?!\d)')
    $statusCode = if ($match.Success) { $match.Groups[1].Value } else { 'none' }
    $reachable = ($exitCode -eq 0 -and $statusCode -match '^[23]\d\d$')

    [pscustomobject]@{
        Reachable = $reachable
        ExitCode = $exitCode
        StatusCode = $statusCode
        Raw = $text
    }
}

Write-Evidence 'Starting controlled network-isolation experiment with direct endpoint validation.'
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

    if (-not $podIp) {
        throw 'Selected target pod does not have a pod IP.'
    }

    $existingChaosLabel = $target.metadata.labels.$chaosLabelKey
    if ($null -ne $existingChaosLabel) {
        throw "Target pod already has label ${chaosLabelKey}=$existingChaosLabel. Refusing to overwrite a pre-existing chaos label."
    }

    Write-Evidence "Pre-chaos readyReplicas=$($readyPods.Count)"
    Write-Evidence "Selected pod=$podName node=$nodeName podIP=$podIp"

    $probeManifest = @"
apiVersion: v1
kind: Pod
metadata:
  name: $probePodName
  namespace: $Namespace
  labels:
    app.kubernetes.io/name: hybrid-direct-endpoint-probe
    app.kubernetes.io/part-of: hybrid-kubernetes-chaos
spec:
  restartPolicy: Never
  containers:
    - name: probe
      image: curlimages/curl:8.23.0
      imagePullPolicy: IfNotPresent
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 100m
          memory: 64Mi
      command:
        - /bin/sh
        - -c
      args:
        - sleep 300
"@

    Write-Evidence "Creating independent direct-endpoint probe pod=$probePodName"
    $probeManifest | kubectl apply -f - | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the direct-endpoint probe pod.'
    }
    $probeCreated = $true

    kubectl wait -n $Namespace --for=condition=Ready "pod/$probePodName" --timeout=60s | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        kubectl describe pod $probePodName -n $Namespace | Tee-Object -FilePath $outputPath -Append
        throw 'Direct-endpoint probe pod did not become Ready.'
    }

    $preCheck = Test-DirectEndpoint -ProbePod $probePodName -TargetIp $podIp
    Write-Evidence "Direct-before reachable=$($preCheck.Reachable) statusCode=$($preCheck.StatusCode) exitCode=$($preCheck.ExitCode)"
    if (-not $preCheck.Reachable) {
        throw "Baseline direct connectivity to target pod $podIp failed before NetworkPolicy injection."
    }

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

    # Allow the CNI a short propagation window before validating isolation.
    Start-Sleep -Seconds 3

    $duringJson = kubectl get pod $podName -n $Namespace -o json
    if ($LASTEXITCODE -eq 0) {
        $duringPod = $duringJson | ConvertFrom-Json
        $duringReady = @($duringPod.status.containerStatuses | Where-Object { $_.ready }).Count -ge 1
        $duringRestarts = (@($duringPod.status.containerStatuses | Measure-Object -Property restartCount -Sum).Sum)
        Write-Evidence "During-isolation podPhase=$($duringPod.status.phase) ready=$duringReady restartCount=$duringRestarts"
    }

    $duringCheck = Test-DirectEndpoint -ProbePod $probePodName -TargetIp $podIp
    Write-Evidence "Direct-during reachable=$($duringCheck.Reachable) statusCode=$($duringCheck.StatusCode) exitCode=$($duringCheck.ExitCode)"
    if ($duringCheck.Reachable) {
        Write-Evidence 'WARNING=Direct endpoint remained reachable during NetworkPolicy interval; isolation has not been proven.'
    }
    else {
        Write-Evidence 'Direct endpoint is unreachable from the independent probe while NetworkPolicy is active.'
    }

    Write-Evidence "Holding network isolation for ${IsolationSeconds}s. Service availability is measured independently by availability-probe.ps1."
    Start-Sleep -Seconds $IsolationSeconds

    Write-Evidence 'Isolation interval complete; beginning cleanup.'

    kubectl delete networkpolicy $policyName -n $Namespace --ignore-not-found=true --wait=true | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove NetworkPolicy=$policyName."
    }
    $policyApplied = $false
    Write-Evidence "Removed NetworkPolicy=$policyName"

    kubectl label pod $podName -n $Namespace "${chaosLabelKey}-" 2>&1 | Tee-Object -FilePath $outputPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove temporary label=$chaosLabelKey from pod=$podName."
    }
    $labelApplied = $false
    Write-Evidence "Removed temporary label=$chaosLabelKey from pod=$podName"

    # Allow the dataplane a short convergence window before validating restoration.
    Start-Sleep -Seconds 3

    $postCheck = Test-DirectEndpoint -ProbePod $probePodName -TargetIp $podIp
    Write-Evidence "Direct-after reachable=$($postCheck.Reachable) statusCode=$($postCheck.StatusCode) exitCode=$($postCheck.ExitCode)"

    $postJson = kubectl get pod $podName -n $Namespace -o json
    if ($LASTEXITCODE -ne 0) {
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

    if (-not $postCheck.Reachable) {
        Write-Evidence 'RESULT=FAIL direct connectivity to the target pod did not recover after NetworkPolicy cleanup.'
        throw 'Direct connectivity to the target pod did not recover after NetworkPolicy cleanup.'
    }

    if ($duringCheck.Reachable) {
        Write-Evidence 'RESULT=INCONCLUSIVE policy was applied and removed, but direct endpoint isolation was not observed.'
    }
    else {
        Write-Evidence 'RESULT=PASS direct endpoint sequence was reachable-before, unreachable-during, reachable-after.'
    }

    Write-Evidence "Evidence=$outputPath"
}
finally {
    if ($policyApplied) {
        kubectl delete networkpolicy $policyName -n $Namespace --ignore-not-found=true --wait=true 2>&1 | Tee-Object -FilePath $outputPath -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Evidence "Cleanup removed NetworkPolicy=$policyName"
        }
        else {
            Write-Evidence "WARNING=Failed to remove NetworkPolicy=$policyName automatically. Manual cleanup may be required."
        }
    }

    if ($labelApplied -and $podName) {
        kubectl label pod $podName -n $Namespace "${chaosLabelKey}-" 2>&1 | Tee-Object -FilePath $outputPath -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Evidence "Cleanup removed temporary label=$chaosLabelKey from pod=$podName"
        }
        else {
            Write-Evidence "WARNING=Failed to remove temporary label=$chaosLabelKey from pod=$podName automatically."
        }
    }

    if ($probeCreated) {
        kubectl delete pod $probePodName -n $Namespace --ignore-not-found=true --wait=false 2>&1 | Tee-Object -FilePath $outputPath -Append
        if ($LASTEXITCODE -eq 0) {
            Write-Evidence "Removed direct-endpoint probe pod=$probePodName"
        }
        else {
            Write-Evidence "WARNING=Failed to remove direct-endpoint probe pod=$probePodName automatically."
        }
    }
}
