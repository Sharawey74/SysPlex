# Test Fan Monitor with Bundled Library
# Run this to test if the bundled library works

$ErrorActionPreference = "Stop"

Write-Host "Testing Fan Monitor with Bundled Library" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`nWARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "Hardware library requires administrator privileges for full functionality" -ForegroundColor Yellow
    Write-Host "To run as admin: Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Write-Host "`nContinuing with standard privileges (limited functionality)...`n" -ForegroundColor Yellow
} else {
    Write-Host "`nRunning as Administrator - Full hardware access enabled`n" -ForegroundColor Green
}

# Check if library exists
$projectRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $projectRoot "libs\LibreHardwareMonitorLib.dll"

if (Test-Path $libPath) {
    Write-Host "Bundled library found: $libPath" -ForegroundColor Green
} else {
    Write-Host "Bundled library NOT found" -ForegroundColor Red
    Write-Host "Run: .\scripts\setup_libs.ps1" -ForegroundColor Yellow
    exit 1
}

# Run fan monitor
Write-Host "Running fan monitor..." -ForegroundColor Cyan
$fanOutput = & "$projectRoot\scripts\monitors\windows\fan_monitor.ps1"

# Display results
Write-Host "`nResults:" -ForegroundColor Cyan
Write-Host $fanOutput

# Parse and display formatted
Write-Host "`nFormatted Output:" -ForegroundColor Cyan
$fanData = $fanOutput | ConvertFrom-Json
$fanData | ConvertTo-Json -Depth 10

Write-Host "`nTest complete!" -ForegroundColor Green
