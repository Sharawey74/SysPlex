# Continuous Monitoring - Runs main_monitor.ps1 every 5 seconds

param(
    [int]$IntervalSeconds = 5
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$monitorScript = Join-Path $scriptPath "main_monitor.ps1"

Write-Host "Starting continuous monitoring..." -ForegroundColor Green
Write-Host "Running every $IntervalSeconds seconds" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$iteration = 1

try {
    while ($true) {
        Write-Host "[$iteration] $(Get-Date -Format 'HH:mm:ss') - Collecting metrics..." -ForegroundColor White
        
        # Run the monitoring script
        & PowerShell -ExecutionPolicy Bypass -NoProfile -File $monitorScript
        
        Write-Host "[$iteration] Metrics updated" -ForegroundColor Green
        Write-Host ""
        
        $iteration++
        
        # Wait for the specified interval
        Start-Sleep -Seconds $IntervalSeconds
    }
}
catch {
    Write-Host "Monitoring stopped: $_" -ForegroundColor Red
}
