# Cleanup and Reorganize Script
# Moves all remaining PowerShell files to windows/ directory
# Moves all Docker files to Docker/ directory
# Updates .gitignore

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SYSTEM MONITOR - CLEANUP & REORGANIZATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Statistics
$stats = @{
    PowerShellMoved = 0
    PowerShellDeleted = 0
    DockerMoved = 0
    DirectoriesRemoved = 0
    Errors = 0
}

# ============================================
# PART 1: Move remaining PowerShell files
# ============================================

Write-Host "[PHASE 1] Moving PowerShell files to windows/ directory..." -ForegroundColor Yellow

# Define source-to-destination mappings for remaining .ps1 files
$psFileMappings = @(
    # Root level
    @{ Source = "migrate_powershell_scripts.ps1"; Dest = "windows/scripts/migrate_powershell_scripts.ps1" }
    
    # Scripts directory
    @{ Source = "scripts/main_monitor.ps1"; Dest = "windows/scripts/main_monitor.ps1"; Skip = $true }  # Already exists
    @{ Source = "scripts/run_as_admin.ps1"; Dest = "windows/scripts/run_as_admin.ps1"; Skip = $true }
    @{ Source = "scripts/setup_libs.ps1"; Dest = "windows/scripts/setup_libs.ps1"; Skip = $true }
    @{ Source = "scripts/start_continuous_monitoring.ps1"; Dest = "windows/scripts/start_continuous_monitoring.ps1"; Skip = $true }
    @{ Source = "scripts/test_fan_bundled.ps1"; Dest = "windows/scripts/test_fan_bundled.ps1"; Skip = $true }
    
    # Scripts/utils
    @{ Source = "scripts/utils/hardware_sensor.ps1"; Dest = "windows/utils/hardware_sensor.ps1" }
    @{ Source = "scripts/utils/json_writer.ps1"; Dest = "windows/utils/json_writer.ps1"; Skip = $true }
    @{ Source = "scripts/utils/os_detector.ps1"; Dest = "windows/utils/os_detector.ps1"; Skip = $true }
    
    # Scripts/monitors/windows - DELETE these (duplicates)
    @{ Source = "scripts/monitors/windows/cpu_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/disk_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/fan_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/memory_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/network_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/smart_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/system_monitor.ps1"; Delete = $true }
    @{ Source = "scripts/monitors/windows/temperature_monitor.ps1"; Delete = $true }
    
    # Tests/windows - DELETE these (duplicates)
    @{ Source = "tests/windows/CPU_ALL_METHODS.ps1"; Delete = $true }
    @{ Source = "tests/windows/debug_cpu_temp.ps1"; Delete = $true }
    @{ Source = "tests/windows/Debug-Temperature.ps1"; Delete = $true }
    @{ Source = "tests/windows/Run-AllTests.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-CpuMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-DiskMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-FanMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-MainMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-MemoryMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-NetworkMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-SmartMonitor.ps1"; Delete = $true }
    @{ Source = "tests/windows/Test-TemperatureMonitor.ps1"; Delete = $true }
)

foreach ($mapping in $psFileMappings) {
    $sourcePath = Join-Path $ProjectRoot $mapping.Source
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  ⊘ Not found: $($mapping.Source)" -ForegroundColor DarkGray
        continue
    }
    
    if ($mapping.Delete) {
        # Delete duplicate file
        try {
            Remove-Item -Path $sourcePath -Force
            Write-Host "  ✗ Deleted: $($mapping.Source)" -ForegroundColor Red
            $stats.PowerShellDeleted++
        }
        catch {
            Write-Host "  ✗ Error deleting $($mapping.Source): $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors++
        }
    }
    elseif ($mapping.Skip) {
        # File already in destination, just delete source
        try {
            Remove-Item -Path $sourcePath -Force
            Write-Host "  ✗ Removed duplicate: $($mapping.Source)" -ForegroundColor DarkYellow
            $stats.PowerShellDeleted++
        }
        catch {
            Write-Host "  ✗ Error removing $($mapping.Source): $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors++
        }
    }
    else {
        # Move file to windows directory
        $destPath = Join-Path $ProjectRoot $mapping.Dest
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Remove-Item -Path $sourcePath -Force
            Write-Host "  ✓ Moved: $($mapping.Source) -> $($mapping.Dest)" -ForegroundColor Green
            $stats.PowerShellMoved++
        }
        catch {
            Write-Host "  ✗ Error moving $($mapping.Source): $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors++
        }
    }
}

# ============================================
# PART 2: Remove empty directories
# ============================================

Write-Host "`n[PHASE 2] Removing empty PowerShell directories..." -ForegroundColor Yellow

$dirsToRemove = @(
    "scripts/monitors/windows"
    "scripts/utils"
    "tests/windows"
)

foreach ($dir in $dirsToRemove) {
    $dirPath = Join-Path $ProjectRoot $dir
    
    if (Test-Path $dirPath) {
        try {
            # Check if empty
            $items = Get-ChildItem -Path $dirPath -Force
            if ($items.Count -eq 0) {
                Remove-Item -Path $dirPath -Force -Recurse
                Write-Host "  ✓ Removed empty directory: $dir" -ForegroundColor Green
                $stats.DirectoriesRemoved++
            }
            else {
                Write-Host "  ⚠ Directory not empty, skipping: $dir" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ✗ Error removing ${dir}: $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors++
        }
    }
}

# ============================================
# PART 3: Move Docker files
# ============================================

Write-Host "`n[PHASE 3] Moving Docker files to Docker/ directory..." -ForegroundColor Yellow

# Create Docker directory
$dockerDir = Join-Path $ProjectRoot "Docker"
if (-not (Test-Path $dockerDir)) {
    New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null
    Write-Host "  ✓ Created Docker/ directory" -ForegroundColor Green
}

# Docker file mappings
$dockerFiles = @(
    "Dockerfile.method1"
    "Dockerfile.method2"
    "docker-compose.method1.yml"
    "docker-compose.method2.yml"
    ".dockerignore"
    "docker-entrypoint.sh"
)

foreach ($file in $dockerFiles) {
    $sourcePath = Join-Path $ProjectRoot $file
    $destPath = Join-Path $dockerDir $file
    
    if (Test-Path $sourcePath) {
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Remove-Item -Path $sourcePath -Force
            Write-Host "  ✓ Moved: $file -> Docker/$file" -ForegroundColor Green
            $stats.DockerMoved++
        }
        catch {
            Write-Host "  ✗ Error moving ${file}: $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors++
        }
    }
    else {
        Write-Host "  ⊘ Not found: $file" -ForegroundColor DarkGray
    }
}

# ============================================
# PART 4: Update .gitignore
# ============================================

Write-Host "`n[PHASE 4] Updating .gitignore..." -ForegroundColor Yellow

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$gitignoreContent = Get-Content $gitignorePath -Raw

# Add __pycache__ if not already present
if ($gitignoreContent -notmatch "__pycache__") {
    $newContent = $gitignoreContent.TrimEnd() + "`n`n# Python cache`n__pycache__/`n*.pyc`n*.pyo`n*.pyd`n.Python`n"
    Set-Content -Path $gitignorePath -Value $newContent -NoNewline
    Write-Host "  ✓ Added __pycache__ to .gitignore" -ForegroundColor Green
}
else {
    Write-Host "  ⊘ __pycache__ already in .gitignore" -ForegroundColor DarkGray
}

# ============================================
# SUMMARY
# ============================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CLEANUP SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nPowerShell Files:" -ForegroundColor White
Write-Host "  Moved:   $($stats.PowerShellMoved)" -ForegroundColor Green
Write-Host "  Deleted: $($stats.PowerShellDeleted)" -ForegroundColor Red

Write-Host "`nDocker Files:" -ForegroundColor White
Write-Host "  Moved:   $($stats.DockerMoved)" -ForegroundColor Green

Write-Host "`nDirectories:" -ForegroundColor White
Write-Host "  Removed: $($stats.DirectoriesRemoved)" -ForegroundColor Yellow

Write-Host "`nErrors:    $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Green" })

Write-Host "`n========================================" -ForegroundColor Cyan

if ($stats.Errors -eq 0) {
    Write-Host "✓ Cleanup completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "⚠ Cleanup completed with $($stats.Errors) errors" -ForegroundColor Yellow
}

Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "  1. Update docker-compose files to reference Docker/ directory" -ForegroundColor Gray
Write-Host "  2. Update any scripts that reference old paths" -ForegroundColor Gray
Write-Host "  3. Run: git status" -ForegroundColor Gray
Write-Host "  4. Run: git add ." -ForegroundColor Gray
Write-Host "  5. Run: git commit -m 'Reorganize: Move .ps1 to windows/, Docker files to Docker/'" -ForegroundColor Gray
Write-Host ""
