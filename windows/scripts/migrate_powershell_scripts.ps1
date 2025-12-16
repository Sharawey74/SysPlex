# migrate_powershell_scripts.ps1
# Migrates all PowerShell scripts to the new /windows directory structure

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PowerShell Script Migration to /windows" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = $PSScriptRoot
$WindowsRoot = Join-Path $ProjectRoot "windows"

# Ensure windows directories exist
$directories = @(
    "$WindowsRoot\scripts",
    "$WindowsRoot\monitors",
    "$WindowsRoot\utils",
    "$WindowsRoot\tests"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✓ Created directory: $dir" -ForegroundColor Green
    }
}

# Define migration mappings
$migrations = @(
    # Main scripts
    @{
        Source = "scripts\main_monitor.ps1"
        Dest = "windows\scripts\main_monitor.ps1"
    },
    @{
        Source = "scripts\run_as_admin.ps1"
        Dest = "windows\scripts\run_as_admin.ps1"
    },
    @{
        Source = "scripts\setup_libs.ps1"
        Dest = "windows\scripts\setup_libs.ps1"
    },
    @{
        Source = "scripts\start_continuous_monitoring.ps1"
        Dest = "windows\scripts\start_continuous_monitoring.ps1"
    },
    @{
        Source = "scripts\test_fan_bundled.ps1"
        Dest = "windows\scripts\test_fan_bundled.ps1"
    },
    
    # Monitor scripts
    @{
        Source = "scripts\monitors\windows\cpu_monitor.ps1"
        Dest = "windows\monitors\cpu_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\memory_monitor.ps1"
        Dest = "windows\monitors\memory_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\disk_monitor.ps1"
        Dest = "windows\monitors\disk_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\network_monitor.ps1"
        Dest = "windows\monitors\network_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\temperature_monitor.ps1"
        Dest = "windows\monitors\temperature_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\fan_monitor.ps1"
        Dest = "windows\monitors\fan_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\smart_monitor.ps1"
        Dest = "windows\monitors\smart_monitor.ps1"
    },
    @{
        Source = "scripts\monitors\windows\system_monitor.ps1"
        Dest = "windows\monitors\system_monitor.ps1"
    },
    
    # Utility scripts
    @{
        Source = "scripts\utils\json_writer.ps1"
        Dest = "windows\utils\json_writer.ps1"
    },
    @{
        Source = "scripts\utils\os_detector.ps1"
        Dest = "windows\utils\os_detector.ps1"
    },
    @{
        Source = "scripts\utils\hardware_sensor.ps1"
        Dest = "windows\utils\hardware_sensor.ps1"
    },
    
    # Test scripts
    @{
        Source = "tests\windows\Run-AllTests.ps1"
        Dest = "windows\tests\Run-AllTests.ps1"
    },
    @{
        Source = "tests\windows\Test-MainMonitor.ps1"
        Dest = "windows\tests\Test-MainMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-CpuMonitor.ps1"
        Dest = "windows\tests\Test-CpuMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-MemoryMonitor.ps1"
        Dest = "windows\tests\Test-MemoryMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-DiskMonitor.ps1"
        Dest = "windows\tests\Test-DiskMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-NetworkMonitor.ps1"
        Dest = "windows\tests\Test-NetworkMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-TemperatureMonitor.ps1"
        Dest = "windows\tests\Test-TemperatureMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-FanMonitor.ps1"
        Dest = "windows\tests\Test-FanMonitor.ps1"
    },
    @{
        Source = "tests\windows\Test-SmartMonitor.ps1"
        Dest = "windows\tests\Test-SmartMonitor.ps1"
    },
    @{
        Source = "tests\windows\Debug-Temperature.ps1"
        Dest = "windows\tests\Debug-Temperature.ps1"
    },
    @{
        Source = "tests\windows\debug_cpu_temp.ps1"
        Dest = "windows\tests\debug_cpu_temp.ps1"
    },
    @{
        Source = "tests\windows\CPU_ALL_METHODS.ps1"
        Dest = "windows\tests\CPU_ALL_METHODS.ps1"
    }
)

Write-Host "`nMigrating PowerShell scripts..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$skipCount = 0
$errorCount = 0

foreach ($migration in $migrations) {
    $sourcePath = Join-Path $ProjectRoot $migration.Source
    $destPath = Join-Path $ProjectRoot $migration.Dest
    
    if (Test-Path $sourcePath) {
        try {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Host "✓ Migrated: $($migration.Source) → $($migration.Dest)" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "✗ Error migrating $($migration.Source): $_" -ForegroundColor Red
            $errorCount++
        }
    }
    else {
        Write-Host "⊘ Skipped (not found): $($migration.Source)" -ForegroundColor DarkGray
        $skipCount++
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Migration Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Migrated: $successCount files" -ForegroundColor Green
Write-Host "  ⊘ Skipped:  $skipCount files" -ForegroundColor DarkGray
Write-Host "  ✗ Errors:   $errorCount files" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($errorCount -eq 0) {
    Write-Host "✓ Migration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Update universal.py to reference new paths" -ForegroundColor White
    Write-Host "2. Test the new structure with: .\windows\tests\Run-AllTests.ps1" -ForegroundColor White
    Write-Host "3. Remove old PowerShell files from scripts/ and tests/ directories" -ForegroundColor White
}
else {
    Write-Host "⚠ Migration completed with errors. Please review above." -ForegroundColor Yellow
}
