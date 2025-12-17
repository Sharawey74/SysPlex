# Quick Fix Script for Native Agent Startup Issues
# Run this as Administrator in PowerShell

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Native Agent Quick Fix" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = $PSScriptRoot
$BinaryPath = Join-Path $ProjectRoot "Host2\bin\host-agent-windows.exe"

# Check 1: Binary exists
Write-Host "[CHECK 1] Checking binary existence..." -ForegroundColor Yellow
if (Test-Path $BinaryPath) {
    Write-Host "✓ Binary found: $BinaryPath" -ForegroundColor Green
} else {
    Write-Host "✗ FAILED: Binary not found!" -ForegroundColor Red
    Write-Host "Expected location: $BinaryPath" -ForegroundColor Red
    exit 1
}

# Check 2: Unblock the file
Write-Host ""
Write-Host "[CHECK 2] Unblocking binary..." -ForegroundColor Yellow
try {
    Unblock-File -Path $BinaryPath -ErrorAction Stop
    Write-Host "✓ Binary unblocked successfully!" -ForegroundColor Green
} catch {
    Write-Host "⚠ Warning: Could not unblock file (may already be unblocked)" -ForegroundColor Yellow
}

# Check 3: Test if port 8889 is available
Write-Host ""
Write-Host "[CHECK 3] Checking port 8889..." -ForegroundColor Yellow
$PortInUse = Get-NetTCPConnection -LocalPort 8889 -ErrorAction SilentlyContinue
if ($PortInUse) {
    Write-Host "⚠ WARNING: Port 8889 is already in use!" -ForegroundColor Red
    Write-Host "Process using port:" -ForegroundColor Red
    Get-Process -Id $PortInUse.OwningProcess | Format-Table ProcessName, Id
    Write-Host ""
    Write-Host "SOLUTION: Kill the process or choose a different port" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✓ Port 8889 is available" -ForegroundColor Green
}

# Check 4: Add firewall rule
Write-Host ""
Write-Host "[CHECK 4] Configuring Windows Firewall..." -ForegroundColor Yellow
$RuleName = "System Monitor Native Agent"
$ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

if ($ExistingRule) {
    Write-Host "✓ Firewall rule already exists" -ForegroundColor Green
} else {
    try {
        New-NetFirewallRule -DisplayName $RuleName `
            -Direction Inbound `
            -LocalPort 8889 `
            -Protocol TCP `
            -Action Allow `
            -ErrorAction Stop | Out-Null
        Write-Host "✓ Firewall rule created" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Warning: Could not create firewall rule (may need Administrator rights)" -ForegroundColor Yellow
    }
}

# Check 5: Test binary execution
Write-Host ""
Write-Host "[CHECK 5] Testing binary execution..." -ForegroundColor Yellow

# Kill any existing instance
Get-Process | Where-Object {$_.Name -like "*host-agent*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start the binary
Write-Host "Starting Native Agent..." -ForegroundColor Cyan
$Process = Start-Process -FilePath $BinaryPath -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5

# Test health endpoint
Write-Host "Testing health endpoint..." -ForegroundColor Cyan
try {
    $Response = Invoke-WebRequest -Uri "http://localhost:8889/health" -TimeoutSec 5 -UseBasicParsing
    if ($Response.StatusCode -eq 200) {
        Write-Host "✓ SUCCESS! Native Agent is running!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Response:" -ForegroundColor Cyan
        Write-Host $Response.Content
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "  All checks passed!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Now run: bash start-universal.sh" -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "✗ FAILED: Native Agent did not respond!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "POSSIBLE CAUSES:" -ForegroundColor Yellow
    Write-Host "  1. Antivirus is blocking the binary" -ForegroundColor White
    Write-Host "  2. Binary crashed immediately (check Event Viewer)" -ForegroundColor White
    Write-Host "  3. Missing dependencies (unlikely for Go binaries)" -ForegroundColor White
    Write-Host ""
    Write-Host "SOLUTIONS:" -ForegroundColor Yellow
    Write-Host "  1. Add exception to antivirus for: $BinaryPath" -ForegroundColor White
    Write-Host "  2. Try running manually: $BinaryPath" -ForegroundColor White
    Write-Host "  3. Check Windows Event Viewer → Application logs" -ForegroundColor White
    
    # Stop the process if still running
    if ($Process -and !$Process.HasExited) {
        $Process.Kill()
    }
    exit 1
}

# Keep process running
Write-Host "Native Agent is running in background (PID: $($Process.Id))" -ForegroundColor Green
Write-Host ""
