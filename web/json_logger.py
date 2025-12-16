#!/usr/bin/env python3
"""
JSON Logging Service - Saves metrics every 60 seconds from Host API
Logs are stored in json/ directory at project root
"""

import json
import time
import sys
from pathlib import Path
from datetime import datetime
import signal
import requests

# Add project root to path (web/ is one level down from project root)
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

JSON_DIR = project_root / 'json'
INTERVAL = 60  # seconds
MAX_FILES = 10  # Keep only last 10 files
HOST_API_URL = "http://host.docker.internal:8888/metrics"

running = True

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global running
    running = False
    print("\n\nJSON Logging Service stopped")
    sys.exit(0)

def save_metrics_json():
    """Save current metrics from Host API to JSON file with local timestamp"""
    try:
        # Fetch metrics from Host API (real hardware data)
        response = requests.get(HOST_API_URL, timeout=5.0)
        response.raise_for_status()
        api_response = response.json()
        
        if api_response.get('status') != 'ok':
            print(f"ERROR: Host API returned status: {api_response.get('status')}")
            return False
        
        metrics = api_response.get('data', {})
        
        # Get current local time
        now_local = datetime.now()
        now_utc = datetime.utcnow()
        
        # Filename format: YYYYMMDD_HHMMSS.json (local time)
        filename = now_local.strftime('%Y%m%d_%H%M%S') + '.json'
        filepath = JSON_DIR / filename
        
        # Add timestamps to metrics (local time format: dd/mm/year HH:MM:SS)
        metrics['saved_at'] = now_utc.isoformat() + 'Z'
        metrics['log_timestamp'] = now_local.strftime('%d/%m/%Y %H:%M:%S')
        metrics['source'] = 'host-api'
        
        with open(filepath, 'w') as f:
            json.dump(metrics, f, indent=2)
        
        print(f"[{now_local.strftime('%H:%M:%S')}] ✓ Saved: {filename} | Host: {metrics.get('system', {}).get('hostname', 'unknown')} | CPU: {metrics.get('cpu', {}).get('usage_percent', 0)}%")
        
        # Cleanup old files (keep only last 10)
        cleanup_old_files()
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"ERROR connecting to Host API: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR saving metrics: {e}", file=sys.stderr)
        return False

def cleanup_old_files():
    """Keep only the last MAX_FILES JSON files"""
    try:
        files = sorted(JSON_DIR.glob('*.json'), key=lambda p: p.stat().st_mtime, reverse=True)
        
        if len(files) > MAX_FILES:
            deleted_count = 0
            for old_file in files[MAX_FILES:]:
                try:
                    old_file.unlink()
                    deleted_count += 1
                except Exception as e:
                    print(f"Warning: Could not delete {old_file}: {e}", file=sys.stderr)
            
            if deleted_count > 0:
                print(f"  Cleaned up {deleted_count} old log files")
                
    except Exception as e:
        print(f"Warning: Cleanup failed: {e}", file=sys.stderr)

def main():
    """Main loop - fetch from Host API and save metrics every 60 seconds"""
    global running
    
    print("=" * 60)
    print("JSON Logging Service - Fetching from Host API")
    print("=" * 60)
    print(f"Host API:      {HOST_API_URL}")
    print(f"Log Directory: {JSON_DIR}")
    print(f"Save Interval: {INTERVAL} seconds")
    print(f"Max Files:     {MAX_FILES} (auto-cleanup)")
    print(f"Timestamp:     Local time (dd/mm/yyyy HH:MM:SS)")
    print("=" * 60)
    print("\nPress Ctrl+C to stop\n")
    
    # Create JSON directory
    JSON_DIR.mkdir(parents=True, exist_ok=True)
    
    # Register signal handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    consecutive_errors = 0
    max_consecutive_errors = 5
    
    try:
        while running:
            success = save_metrics_json()
            
            if success:
                consecutive_errors = 0
            else:
                consecutive_errors += 1
                if consecutive_errors >= max_consecutive_errors:
                    print(f"\nERROR: {max_consecutive_errors} consecutive failures. Stopping.")
                    break
            
            time.sleep(INTERVAL)
            
    except KeyboardInterrupt:
        print("\n\nJSON Logging Service stopped by user")
    except Exception as e:
        print(f"\nFATAL ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    
    sys.exit(0)

if __name__ == '__main__':
    main()
