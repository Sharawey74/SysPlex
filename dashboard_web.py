#!/usr/bin/env python3
"""
System Monitor Web Dashboard Launcher
Stage 4: Web Dashboard + Reports

Usage:
    python dashboard_web.py [--host HOST] [--port PORT] [--debug]

Examples:
    python dashboard_web.py
    python dashboard_web.py --port 8080
    python dashboard_web.py --host 0.0.0.0 --port 5000 --debug
"""

import sys
import argparse
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from web.app import run_server


def main():
    """Parse arguments and start the web server"""
    parser = argparse.ArgumentParser(
        description='System Monitor Web Dashboard - Stage 4',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          Start on localhost:5000
  %(prog)s --port 8080              Use custom port
  %(prog)s --host 0.0.0.0          Listen on all interfaces
  %(prog)s --debug                  Enable debug mode
        """
    )
    
    parser.add_argument(
        '--host',
        default='0.0.0.0',
        help='Host to bind to (default: 0.0.0.0 for all interfaces)'
    )
    
    parser.add_argument(
        '--port',
        type=int,
        default=5000,
        help='Port to listen on (default: 5000)'
    )
    
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable Flask debug mode (auto-reload, detailed errors)'
    )
    
    args = parser.parse_args()
    
    # Display banner
    print("=" * 60)
    print("   System Monitor - Web Dashboard (Stage 4)")
    print("=" * 60)
    print()
    
    # Check if metrics exist
    metrics_file = project_root / 'data' / 'metrics' / 'current.json'
    if not metrics_file.exists():
        print("⚠️  Warning: Metrics file not found!")
        print(f"   Expected: {metrics_file}")
        print()
        print("💡 Run the system monitor first:")
        print("   python universal.py")
        print("   or")
        print("   .\\scripts\\main_monitor.ps1  (Windows)")
        print("   bash scripts/main_monitor.sh  (Unix/Linux)")
        print()
    
    # Start the web server
    try:
        run_server(host=args.host, port=args.port, debug=args.debug)
    except KeyboardInterrupt:
        print("\n\n⏹️  Server stopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error starting server: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
