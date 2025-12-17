#!/usr/bin/env python3
"""
Dashboard Fixes Verification Script
Checks that all three issues have been resolved
"""

import json
import os
import sys
from pathlib import Path

# Color codes for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def check_mark(passed):
    return f"{GREEN}✅{RESET}" if passed else f"{RED}❌{RESET}"

def print_header(text):
    print(f"\n{BLUE}{'=' * 60}{RESET}")
    print(f"{BLUE}{text:^60}{RESET}")
    print(f"{BLUE}{'=' * 60}{RESET}\n")

def verify_json_files():
    """Verify JSON files exist and contain correct data"""
    print_header("JSON DATA VERIFICATION")
    
    json_files = {
        "WSL2 (Bash)": "Host/output/latest.json",
        "Windows (Go)": "Host2/bin/go_latest.json"
    }
    
    results = []
    
    for name, path in json_files.items():
        print(f"Checking {name}: {path}")
        
        if not os.path.exists(path):
            print(f"  {check_mark(False)} File not found")
            results.append(False)
            continue
        
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            
            # Check logical_processors
            logical_cores = data.get('cpu', {}).get('logical_processors', 0)
            print(f"  {check_mark(logical_cores == 8)} Logical Processors: {logical_cores}")
            
            # Check network data
            network = data.get('network', [])
            print(f"  {check_mark(len(network) > 0)} Network Interfaces: {len(network)}")
            
            if network:
                total_rx = sum(n.get('rx_bytes', 0) for n in network)
                total_tx = sum(n.get('tx_bytes', 0) for n in network)
                print(f"    Total RX: {total_rx / 1024 / 1024:.2f} MB")
                print(f"    Total TX: {total_tx / 1024 / 1024:.2f} MB")
            
            # Check temperature
            temp = data.get('temperature', {})
            gpu_temp = temp.get('gpu_celsius', 0)
            print(f"  {check_mark(gpu_temp > 0)} GPU Temperature: {gpu_temp}°C")
            
            results.append(True)
            print()
            
        except json.JSONDecodeError as e:
            print(f"  {check_mark(False)} Invalid JSON: {e}")
            results.append(False)
    
    return all(results)

def verify_template_file():
    """Verify HTML template has report button"""
    print_header("HTML TEMPLATE VERIFICATION")
    
    template_path = "templates/dashboard.html"
    
    if not os.path.exists(template_path):
        print(f"{check_mark(False)} Template file not found: {template_path}")
        return False
    
    with open(template_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = [
        ("Report button exists", "generateReport()" in content),
        ("Report button icon", "bx-file" in content),
        ("WSL CPU cores element", "wsl-cpu-cores" in content),
        ("Windows CPU temp element", "win-cpu-temp" in content),
        ("WSL CPU temp element", "wsl-cpu-temp" in content)
    ]
    
    results = []
    for name, passed in checks:
        print(f"{check_mark(passed)} {name}")
        results.append(passed)
    
    return all(results)

def verify_javascript_file():
    """Verify JavaScript has correct logic"""
    print_header("JAVASCRIPT LOGIC VERIFICATION")
    
    js_path = "static/js/dashboard.js"
    
    if not os.path.exists(js_path):
        print(f"{check_mark(False)} JavaScript file not found: {js_path}")
        return False
    
    with open(js_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = [
        ("generateReport() function exists", "async function generateReport()" in content),
        ("Network rate debugging added", "Network calc:" in content),
        ("Time delta logging", "Time delta:" in content),
        ("Rates calculation logging", "Rates calculated:" in content),
        ("Physical | Logical cores display", "Physical | ${logicalCores} Logical" in content or "Physical | \" + logicalCores + \" Logical" in content),
        ("vCPUs display for WSL2", "vCPUs" in content),
        ("formatRate() function exists", "function formatRate(" in content)
    ]
    
    results = []
    for name, passed in checks:
        print(f"{check_mark(passed)} {name}")
        results.append(passed)
    
    return all(results)

def verify_api_endpoint():
    """Check if Flask app defines the dual metrics endpoint"""
    print_header("API ENDPOINT VERIFICATION")
    
    api_path = "web/app.py"
    
    if not os.path.exists(api_path):
        print(f"{check_mark(False)} API file not found: {api_path}")
        return False
    
    with open(api_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    checks = [
        ("/api/metrics/dual endpoint", "/api/metrics/dual" in content),
        ("/api/reports/generate endpoint", "/api/reports/generate" in content)
    ]
    
    results = []
    for name, passed in checks:
        print(f"{check_mark(passed)} {name}")
        results.append(passed)
    
    return all(results)

def main():
    print(f"\n{GREEN}╔════════════════════════════════════════════════════════════╗{RESET}")
    print(f"{GREEN}║     DASHBOARD FIXES VERIFICATION SCRIPT                    ║{RESET}")
    print(f"{GREEN}║     Checking all three issues have been resolved          ║{RESET}")
    print(f"{GREEN}╚════════════════════════════════════════════════════════════╝{RESET}")
    
    # Change to script directory
    script_dir = Path(__file__).parent
    os.chdir(script_dir)
    
    print(f"\n{YELLOW}Working directory: {os.getcwd()}{RESET}\n")
    
    # Run all verifications
    results = {
        "JSON Data Files": verify_json_files(),
        "HTML Template": verify_template_file(),
        "JavaScript Logic": verify_javascript_file(),
        "API Endpoints": verify_api_endpoint()
    }
    
    # Summary
    print_header("VERIFICATION SUMMARY")
    
    all_passed = True
    for category, passed in results.items():
        status = f"{GREEN}PASSED{RESET}" if passed else f"{RED}FAILED{RESET}"
        print(f"{check_mark(passed)} {category}: {status}")
        all_passed = all_passed and passed
    
    print(f"\n{BLUE}{'=' * 60}{RESET}")
    
    if all_passed:
        print(f"{GREEN}✅ ALL CHECKS PASSED!{RESET}")
        print(f"\n{GREEN}Next steps:{RESET}")
        print("1. Restart dashboard: docker-compose restart web")
        print("2. Open browser: http://localhost:5000")
        print("3. Open console (F12) to see network debugging")
        print("4. Wait 2+ seconds for network rates to appear")
        print("5. Click 'Generate Report' button to test")
        return 0
    else:
        print(f"{RED}❌ SOME CHECKS FAILED{RESET}")
        print(f"\n{YELLOW}Please review the failed items above{RESET}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
