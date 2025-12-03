# Download and Setup Bundled Hardware Monitoring Library
# This script downloads LibreHardwareMonitor DLL for bundling with the project

$ErrorActionPreference = "Stop"

# Configuration
$scriptDir = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$libsDir = Join-Path $projectRoot "libs"
$downloadUrl = "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases/download/v0.9.3/LibreHardwareMonitor-net472.zip"
$zipPath = Join-Path $libsDir "LibreHardwareMonitor.zip"
$extractPath = Join-Path $libsDir "LibreHardwareMonitor"

Write-Host "Setting up bundled hardware monitoring library..." -ForegroundColor Cyan

# Create libs directory if it doesn't exist
if (-not (Test-Path $libsDir)) {
    New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
    Write-Host "Created libs directory" -ForegroundColor Green
}

# Download LibreHardwareMonitor
Write-Host "Downloading LibreHardwareMonitor..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Download complete" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to download: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Extract the ZIP
Write-Host "Extracting files..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "Extraction complete" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to extract: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Copy the main DLL to libs root
$sourceDll = Join-Path $extractPath "LibreHardwareMonitorLib.dll"
$destDll = Join-Path $libsDir "LibreHardwareMonitorLib.dll"

if (Test-Path $sourceDll) {
    Copy-Item -Path $sourceDll -Destination $destDll -Force
    Write-Host "Copied DLL to libs directory" -ForegroundColor Green
} else {
    Write-Host "ERROR: LibreHardwareMonitorLib.dll not found in extracted files" -ForegroundColor Red
    exit 1
}

# Also copy required dependencies
$dependencies = @(
    "HidSharp.dll",
    "Newtonsoft.Json.dll"
)

foreach ($dep in $dependencies) {
    $sourcePath = Join-Path $extractPath $dep
    $destPath = Join-Path $libsDir $dep
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "Copied dependency: $dep" -ForegroundColor Green
    }
}

# Clean up
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nSetup complete! Library files are in: $libsDir" -ForegroundColor Green
Write-Host "You can now commit the 'libs' folder to your repository." -ForegroundColor Cyan
Write-Host "`nFiles installed:" -ForegroundColor Cyan
Get-ChildItem $libsDir | ForEach-Object { Write-Host "  - $($_.Name)" }

exit 0
