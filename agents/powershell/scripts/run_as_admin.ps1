# Run System Monitor as Administrator
# This enables full hardware access for bundled library

$scriptPath = Join-Path $PSScriptRoot "main_monitor.ps1"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -Wait
} else {
    & $scriptPath
}
