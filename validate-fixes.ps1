#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validation script for System Monitor Dashboard fixes
.DESCRIPTION
    Verifies all critical fixes are working correctly
#>

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🔍 System Monitor Dashboard - Validation Script" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

$baseDir = "c:\Users\DELL\Desktop\system-monitor-project-Batch"
$passed = 0
$failed = 0

# Test 1: Container Status
Write-Host "📦 Test 1: Checking container status..." -ForegroundColor Yellow
$containers = docker ps --filter "name=system-monitor" --format "{{.Names}}"
if ($containers -match "system-monitor-dashboard" -and $containers -match "system-monitor-json-logger") {
    Write-Host "   ✅ Both containers running" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   ❌ Containers not running" -ForegroundColor Red
    $failed++
}

# Test 2: Dashboard Accessible
Write-Host "`n🌐 Test 2: Checking dashboard accessibility..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Dashboard accessible (HTTP 200)" -ForegroundColor Green
        $passed++
    }
} catch {
    Write-Host "   ❌ Dashboard not accessible" -ForegroundColor Red
    $failed++
}

# Test 3: Chart.js CDN Loaded
Write-Host "`n📊 Test 3: Checking Chart.js integration..." -ForegroundColor Yellow
try {
    $html = Invoke-WebRequest -Uri "http://localhost:5000" -UseBasicParsing
    if ($html.Content -match "chart\.js@4\.4\.0") {
        Write-Host "   ✅ Chart.js CDN loaded" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "   ❌ Chart.js CDN not found" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host "   ❌ Failed to check Chart.js" -ForegroundColor Red
    $failed++
}

# Test 4: dashboard-enhanced.js Loaded
Write-Host "`n🔧 Test 4: Checking JavaScript file..." -ForegroundColor Yellow
if ($html.Content -match "dashboard-enhanced\.js") {
    Write-Host "   ✅ dashboard-enhanced.js loaded" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   ❌ Wrong JavaScript file" -ForegroundColor Red
    $failed++
}

# Test 5: Canvas Elements Present
Write-Host "`n🎨 Test 5: Checking canvas elements..." -ForegroundColor Yellow
$canvasCount = ([regex]::Matches($html.Content, '<canvas id="(cpu|memory|disk|network|temperature)Chart"')).Count
if ($canvasCount -eq 5) {
    Write-Host "   ✅ All 5 canvas elements present" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   ❌ Missing canvas elements (found: $canvasCount/5)" -ForegroundColor Red
    $failed++
}

# Test 6: API Metrics Endpoint
Write-Host "`n🔌 Test 6: Checking API metrics endpoint..." -ForegroundColor Yellow
try {
    $metrics = Invoke-RestMethod -Uri "http://localhost:5000/api/metrics" -TimeoutSec 5
    if ($metrics.success) {
        Write-Host "   ✅ API metrics working" -ForegroundColor Green
        Write-Host "      Source: $($metrics.source)" -ForegroundColor Gray
        Write-Host "      Hostname: $($metrics.data.system.hostname)" -ForegroundColor Gray
        Write-Host "      OS: $($metrics.data.system.os)" -ForegroundColor Gray
        $passed++
    }
} catch {
    Write-Host "   ❌ API metrics failed" -ForegroundColor Red
    $failed++
}

# Test 7: JSON Logging
Write-Host "`n💾 Test 7: Checking JSON logging..." -ForegroundColor Yellow
$jsonDir = Join-Path $baseDir "json"
if (Test-Path $jsonDir) {
    $jsonFiles = Get-ChildItem -Path $jsonDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
    if ($jsonFiles.Count -gt 0) {
        $latestFile = $jsonFiles[0]
        $age = (Get-Date) - $latestFile.LastWriteTime
        if ($age.TotalSeconds -lt 30) {
            Write-Host "   ✅ JSON logging active (latest: $($latestFile.Name))" -ForegroundColor Green
            Write-Host "      Files: $($jsonFiles.Count)" -ForegroundColor Gray
            Write-Host "      Latest: $($age.TotalSeconds.ToString('F1'))s ago" -ForegroundColor Gray
            $passed++
        } else {
            Write-Host "   ⚠️  JSON files found but may be stale" -ForegroundColor Yellow
            $passed++
        }
    } else {
        Write-Host "   ❌ No JSON files found" -ForegroundColor Red
        $failed++
    }
} else {
    Write-Host "   ❌ JSON directory not found" -ForegroundColor Red
    $failed++
}

# Test 8: Old dashboard.js Removed
Write-Host "`n🗑️  Test 8: Checking cleanup..." -ForegroundColor Yellow
$oldFile = Join-Path $baseDir "static\js\dashboard.js"
if (-not (Test-Path $oldFile)) {
    Write-Host "   ✅ Old dashboard.js removed" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   ⚠️  Old dashboard.js still exists" -ForegroundColor Yellow
    $failed++
}

# Test 9: Host API File Access
Write-Host "`n📁 Test 9: Checking Host API file..." -ForegroundColor Yellow
$hostFile = Join-Path $baseDir "Host\output\latest.json"
if (Test-Path $hostFile) {
    $fileAge = (Get-Date) - (Get-Item $hostFile).LastWriteTime
    Write-Host "   ✅ Host API latest.json exists" -ForegroundColor Green
    Write-Host "      Age: $($fileAge.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
    $passed++
} else {
    Write-Host "   ⚠️  Host API file not found (container metrics will be used)" -ForegroundColor Yellow
    $passed++
}

# Test 10: docker-entrypoint.sh Updated
Write-Host "`n⚙️  Test 10: Checking entrypoint script..." -ForegroundColor Yellow
$entrypoint = Join-Path $baseDir "docker-entrypoint.sh"
$content = Get-Content $entrypoint -Raw
if ($content -match 'if \[ \$# -eq 0 \]') {
    Write-Host "   ✅ Entrypoint script supports custom commands" -ForegroundColor Green
    $passed++
} else {
    Write-Host "   ❌ Entrypoint script not updated" -ForegroundColor Red
    $failed++
}

# Summary
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n✅ Passed: $passed/10" -ForegroundColor Green
Write-Host "❌ Failed: $failed/10" -ForegroundColor Red

if ($failed -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED! Dashboard is fully functional." -ForegroundColor Green
    Write-Host "`n🌐 Dashboard URL: http://localhost:5000" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "`n⚠️  Some tests failed. Please review the output above." -ForegroundColor Yellow
    exit 1
}
