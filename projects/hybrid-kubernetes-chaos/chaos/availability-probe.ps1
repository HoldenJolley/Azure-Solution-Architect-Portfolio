[CmdletBinding()]
param(
    [string]$Namespace = 'hybrid-lab',
    [string]$ServiceUrl = 'http://hybrid-demo.hybrid-lab.svc.cluster.local',
    [int]$DurationSeconds = 120,
    [int]$IntervalSeconds = 1,
    [string]$OutputDirectory = './evidence'
)

$ErrorActionPreference = 'Stop'

if ($DurationSeconds -lt 1) {
    throw 'DurationSeconds must be at least 1.'
}

if ($IntervalSeconds -lt 1) {
    throw 'IntervalSeconds must be at least 1.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$podName = "hybrid-availability-$timestamp".ToLowerInvariant()
$outputPath = Join-Path $OutputDirectory "availability-$timestamp.csv"
$podTimeoutSeconds = $DurationSeconds + 90

$template = @'
apiVersion: v1
kind: Pod
metadata:
  name: __POD_NAME__
  namespace: __NAMESPACE__
  labels:
    app.kubernetes.io/name: hybrid-availability-probe
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
        - |
          end=$(( $(date +%s) + __DURATION__ ))
          echo 'TimestampUtc,Success,StatusCode,LatencyMs,Error'
          while [ "$(date +%s)" -lt "$end" ]; do
            ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            error_file=/tmp/curl-error
            metrics=$(curl -sS -o /dev/null -w '%{http_code},%{time_total}' --max-time 5 '__SERVICE_URL__' 2>"$error_file")
            rc=$?
            status=$(printf '%s' "$metrics" | cut -d, -f1)
            seconds=$(printf '%s' "$metrics" | cut -d, -f2)
            latency_ms=$(awk -v t="$seconds" 'BEGIN { printf "%.2f", t * 1000 }')
            error=$(tr '\n' ' ' < "$error_file" | tr -d '"' | sed 's/,/;/g')

            success=False
            if [ "$rc" -eq 0 ] && [ -n "$status" ] && [ "$status" -ge 200 ] 2>/dev/null && [ "$status" -lt 400 ] 2>/dev/null; then
              success=True
            fi

            printf '%s,%s,%s,%s,"%s"\n' "$ts" "$success" "$status" "$latency_ms" "$error"
            sleep __INTERVAL__
          done
'@

$manifest = $template.Replace('__POD_NAME__', $podName).
    Replace('__NAMESPACE__', $Namespace).
    Replace('__DURATION__', $DurationSeconds.ToString()).
    Replace('__INTERVAL__', $IntervalSeconds.ToString()).
    Replace('__SERVICE_URL__', $ServiceUrl)

Write-Host "Starting in-cluster availability probe against $ServiceUrl"
Write-Host "Probe pod: $Namespace/$podName"
Write-Host "Duration:  $DurationSeconds seconds"
Write-Host "Evidence:  $outputPath"
Write-Host ''

try {
    $manifest | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create the in-cluster availability probe pod.'
    }

    $deadline = (Get-Date).AddSeconds($podTimeoutSeconds)
    $lastPhase = $null

    while ((Get-Date) -lt $deadline) {
        $phase = kubectl get pod $podName -n $Namespace -o jsonpath='{.status.phase}' 2>$null
        if ($LASTEXITCODE -ne 0) {
            Start-Sleep -Seconds 2
            continue
        }

        if ($phase -ne $lastPhase) {
            Write-Host "Probe pod phase: $phase"
            $lastPhase = $phase
        }

        if ($phase -eq 'Succeeded' -or $phase -eq 'Failed') {
            break
        }

        Start-Sleep -Seconds 2
    }

    if ($lastPhase -ne 'Succeeded') {
        kubectl describe pod $podName -n $Namespace
        throw "Availability probe pod did not complete successfully within ${podTimeoutSeconds}s. Final phase: $lastPhase"
    }

    kubectl logs $podName -n $Namespace | Set-Content -Path $outputPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to retrieve availability probe logs.'
    }

    $data = @(Import-Csv $outputPath)
    $total = $data.Count
    $successful = @($data | Where-Object { $_.Success -eq 'True' }).Count
    $failed = $total - $successful
    $availability = if ($total -gt 0) { [math]::Round(($successful / $total) * 100, 3) } else { 0 }
    $successfulLatencies = @($data | Where-Object { $_.Success -eq 'True' -and $_.LatencyMs } | ForEach-Object { [double]$_.LatencyMs })
    $averageLatency = if ($successfulLatencies.Count -gt 0) {
        [math]::Round(($successfulLatencies | Measure-Object -Average).Average, 2)
    } else {
        $null
    }

    Write-Host ''
    Write-Host '=== In-cluster availability summary ==='
    Write-Host "Samples:      $total"
    Write-Host "Successful:   $successful"
    Write-Host "Failed:       $failed"
    Write-Host "Availability: $availability%"
    Write-Host "Avg latency:  $averageLatency ms"
    Write-Host "Evidence:     $outputPath"
}
finally {
    kubectl delete pod $podName -n $Namespace --ignore-not-found=true --wait=false | Out-Null
}
