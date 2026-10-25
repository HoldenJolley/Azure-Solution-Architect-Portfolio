[CmdletBinding()]
param(
    [string]$Url = 'http://localhost:8080',
    [int]$DurationSeconds = 120,
    [int]$IntervalMilliseconds = 1000,
    [string]$OutputDirectory = './evidence'
)

$ErrorActionPreference = 'Stop'

if ($DurationSeconds -lt 1) {
    throw 'DurationSeconds must be at least 1.'
}

if ($IntervalMilliseconds -lt 100) {
    throw 'IntervalMilliseconds must be at least 100.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = Join-Path $OutputDirectory "availability-$timestamp.csv"

$handler = [System.Net.Http.HttpClientHandler]::new()
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(5)

$started = Get-Date
$deadline = $started.AddSeconds($DurationSeconds)
$results = [System.Collections.Generic.List[object]]::new()

Write-Host "Probing $Url for $DurationSeconds seconds..."
Write-Host "Evidence: $outputPath"

try {
    while ((Get-Date) -lt $deadline) {
        $sampleTime = Get-Date
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $success = $false
        $statusCode = $null
        $errorMessage = $null

        try {
            $response = $client.GetAsync($Url).GetAwaiter().GetResult()
            $stopwatch.Stop()
            $statusCode = [int]$response.StatusCode
            $success = $response.IsSuccessStatusCode
            $response.Dispose()
        }
        catch {
            $stopwatch.Stop()
            $errorMessage = $_.Exception.Message
        }

        $result = [pscustomobject]@{
            TimestampUtc = $sampleTime.ToUniversalTime().ToString('o')
            Success      = $success
            StatusCode   = $statusCode
            LatencyMs    = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
            Error        = $errorMessage
        }

        $results.Add($result)
        $result | Export-Csv -Path $outputPath -NoTypeInformation -Append

        $state = if ($success) { 'OK' } else { 'FAIL' }
        Write-Host ("{0:u} {1,-4} status={2} latency={3}ms" -f $sampleTime, $state, $statusCode, $result.LatencyMs)

        Start-Sleep -Milliseconds $IntervalMilliseconds
    }
}
finally {
    $client.Dispose()
    $handler.Dispose()
}

$total = $results.Count
$successful = @($results | Where-Object Success).Count
$failed = $total - $successful
$availability = if ($total -gt 0) { [math]::Round(($successful / $total) * 100, 3) } else { 0 }
$successfulLatencies = @($results | Where-Object Success | Select-Object -ExpandProperty LatencyMs)
$averageLatency = if ($successfulLatencies.Count -gt 0) {
    [math]::Round(($successfulLatencies | Measure-Object -Average).Average, 2)
} else {
    $null
}

Write-Host ''
Write-Host '=== Availability summary ==='
Write-Host "Samples:      $total"
Write-Host "Successful:   $successful"
Write-Host "Failed:       $failed"
Write-Host "Availability: $availability%"
Write-Host "Avg latency:  $averageLatency ms"
Write-Host "Evidence:     $outputPath"
