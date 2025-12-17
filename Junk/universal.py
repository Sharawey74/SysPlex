#!/usr/bin/env python3
"""
Universal Monitor Launcher

This is the single entry point for system monitoring across all platforms.
Automatically detects the OS and runs the appropriate monitoring script.

Workflow:
    1. Detect OS using platform.system()
    2. Route to Windows (PowerShell) or Unix/Linux/macOS (Bash) monitors
    3. Wait for monitors to generate current.json
    4. Optionally launch the dashboard

Usage:
    python universal.py                    # Run monitors only
    python universal.py --dashboard        # Run monitors + launch dashboard
    python universal.py --watch            # Continuous monitoring mode
    python universal.py --help             # Show help
"""

import sys
import platform
import subprocess
import argparse
import time
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Project paths
PROJECT_ROOT = Path(__file__).parent
WINDOWS_MONITOR = PROJECT_ROOT / "windows" / "scripts" / "main_monitor.ps1"
UNIX_MONITOR = PROJECT_ROOT / "scripts" / "main_monitor.sh"
DASHBOARD_SCRIPT = PROJECT_ROOT / "dashboard_tui.py"
METRICS_OUTPUT = PROJECT_ROOT / "data" / "metrics" / "current.json"


def detect_os():
    """
    Detect the operating system.
    
    Returns:
        str: 'Windows', 'Linux', 'Darwin' (macOS), or 'Unknown'
    """
    os_type = platform.system()
    logger.info(f"Detected OS: {os_type}")
    return os_type


def run_windows_monitor(skip_elevation=False):
    """
    Execute Windows monitoring script using PowerShell.
    
    Args:
        skip_elevation: Skip elevation check (use when already running as admin)
    
    Returns:
        bool: True if successful, False otherwise
    """
    logger.info("Running Windows monitoring script...")
    
    if not WINDOWS_MONITOR.exists():
        logger.error(f"Windows monitor script not found: {WINDOWS_MONITOR}")
        return False
    
    try:
        # Run PowerShell script
        cmd = [
            "powershell.exe",
            "-ExecutionPolicy", "Bypass",
            "-NoProfile",
            "-File", str(WINDOWS_MONITOR)
        ]
        
        # Add -SkipElevation flag in continuous monitoring mode
        if skip_elevation:
            cmd.append("-SkipElevation")
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            logger.info("✓ Windows monitoring completed successfully")
            return True
        else:
            logger.error(f"Windows monitor failed with exit code {result.returncode}")
            if result.stderr:
                logger.error(f"Error output: {result.stderr[:500]}")
            return False
            
    except subprocess.TimeoutExpired:
        logger.error("Windows monitor timed out after 60 seconds")
        return False
    except FileNotFoundError:
        logger.error("PowerShell not found. Is PowerShell installed?")
        return False
    except Exception as e:
        logger.error(f"Error running Windows monitor: {e}")
        return False


def run_unix_monitor():
    """
    Execute Unix/Linux/macOS monitoring script using Bash.
    
    Returns:
        bool: True if successful, False otherwise
    """
    logger.info("Running Unix/Linux/macOS monitoring script...")
    
    if not UNIX_MONITOR.exists():
        logger.error(f"Unix monitor script not found: {UNIX_MONITOR}")
        return False
    
    # Make script executable
    try:
        UNIX_MONITOR.chmod(0o755)
    except Exception as e:
        logger.warning(f"Could not set execute permissions: {e}")
    
    try:
        # Run bash script
        result = subprocess.run(
            ["bash", str(UNIX_MONITOR)],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            logger.info("✓ Unix monitoring completed successfully")
            return True
        else:
            logger.error(f"Unix monitor failed with exit code {result.returncode}")
            if result.stderr:
                logger.error(f"Error output: {result.stderr[:500]}")
            return False
            
    except subprocess.TimeoutExpired:
        logger.error("Unix monitor timed out after 60 seconds")
        return False
    except FileNotFoundError:
        logger.error("Bash not found. Is bash installed?")
        return False
    except Exception as e:
        logger.error(f"Error running Unix monitor: {e}")
        return False


def run_monitoring(skip_elevation=False):
    """
    Run the appropriate monitoring script based on OS detection.
    
    Args:
        skip_elevation: Skip elevation check (use in continuous mode after first run)
    
    Returns:
        bool: True if monitoring completed successfully, False otherwise
    """
    os_type = detect_os()
    
    if not skip_elevation:
        print("=" * 60)
        print("UNIVERSAL SYSTEM MONITOR")
        print("=" * 60)
        print(f"Detected OS: {os_type}")
        print(f"Monitor script: ", end="")
    
    if os_type == "Windows":
        if not skip_elevation:
            print(f"{WINDOWS_MONITOR.name}")
            print("-" * 60)
        success = run_windows_monitor(skip_elevation)
        
    elif os_type in ["Linux", "Darwin"]:
        print(f"{UNIX_MONITOR.name}")
        print("-" * 60)
        success = run_unix_monitor()
        
    else:
        print(f"Unsupported OS: {os_type}")
        logger.error(f"Unsupported operating system: {os_type}")
        logger.error("Supported: Windows, Linux, Darwin (macOS)")
        return False
    
    print("-" * 60)
    
    if success:
        # Verify metrics file was created
        if METRICS_OUTPUT.exists():
            print(f"✓ Metrics saved to: {METRICS_OUTPUT}")
            logger.info(f"Metrics file created: {METRICS_OUTPUT}")
        else:
            print(f"⚠ Warning: Metrics file not found: {METRICS_OUTPUT}")
            logger.warning("Monitoring completed but metrics file not found")
            success = False
    else:
        print("✗ Monitoring failed")
    
    print("=" * 60)
    return success


def launch_dashboard(dashboard_type='web'):
    """
    Launch the dashboard (web or TUI).
    
    Args:
        dashboard_type: 'web' for Flask web dashboard, 'tui' for terminal dashboard
    
    Returns:
        subprocess.Popen: Dashboard process
    """
    if dashboard_type == 'web':
        web_script = PROJECT_ROOT / "dashboard_web.py"
        logger.info("Launching web dashboard...")
        
        if not web_script.exists():
            logger.error(f"Web dashboard script not found: {web_script}")
            print(f"✗ Web dashboard not found: {web_script}")
            return None
        
        try:
            print("\nLaunching web dashboard on http://localhost:5000")
            print("Press Ctrl+C to stop the server\n")
            
            # Launch web dashboard (blocks until user exits)
            process = subprocess.run(
                [sys.executable, str(web_script)],
                check=False
            )
            
            return process
            
        except KeyboardInterrupt:
            logger.info("Web dashboard stopped by user")
            print("\n✓ Web dashboard stopped")
            return None
        except Exception as e:
            logger.error(f"Error launching web dashboard: {e}")
            print(f"✗ Error launching web dashboard: {e}")
            return None
    
    else:  # TUI dashboard
        logger.info("Launching terminal dashboard...")
        
        if not DASHBOARD_SCRIPT.exists():
            logger.error(f"Dashboard script not found: {DASHBOARD_SCRIPT}")
            print(f"✗ Dashboard not found: {DASHBOARD_SCRIPT}")
            return None
        
        try:
            print("\nLaunching dashboard...")
            print("Press Ctrl+C to exit\n")
            
            # Launch dashboard (blocks until user exits)
            process = subprocess.run(
                [sys.executable, str(DASHBOARD_SCRIPT)],
                check=False
            )
            
            return process
            
        except KeyboardInterrupt:
            logger.info("Dashboard stopped by user")
            print("\n✓ Dashboard stopped")
            return None
        except Exception as e:
            logger.error(f"Error launching dashboard: {e}")
            print(f"✗ Error launching dashboard: {e}")
            return None


def watch_mode(interval=30, with_dashboard=False):
    """
    Continuous monitoring mode - runs monitors at regular intervals.
    
    Args:
        interval: Seconds between monitoring runs (default: 30)
        with_dashboard: If True, launches web dashboard in background
    """
    logger.info(f"Starting watch mode (interval: {interval}s)")
    print("\n" + "=" * 60)
    print("CONTINUOUS MONITORING MODE")
    print("=" * 60)
    print(f"Update interval: {interval} seconds")
    print("Press Ctrl+C to stop")
    print("=" * 60 + "\n")
    
    dashboard_process = None
    
    # Launch dashboard in background if requested
    if with_dashboard:
        try:
            import threading
            
            def run_dashboard():
                """Run Flask dashboard in a separate thread"""
                web_script = PROJECT_ROOT / "dashboard_web.py"
                subprocess.run([sys.executable, str(web_script)])
            
            print("🌐 Launching web dashboard in background...")
            print(f"📊 Dashboard URL: http://localhost:5000")
            print(f"📊 Alternative URL: http://127.0.0.1:5000")
            print("")
            
            # Start dashboard in a daemon thread
            dashboard_thread = threading.Thread(target=run_dashboard, daemon=True)
            dashboard_thread.start()
            
            time.sleep(3)  # Give dashboard time to start
            
            print("✓ Dashboard started successfully on port 5000")
            print("✓ Open http://127.0.0.1:5000 in your browser")
            print("")
            
            # Store thread reference
            dashboard_process = dashboard_thread
                
        except Exception as e:
            logger.error(f"Failed to start dashboard: {e}")
            print(f"✗ Dashboard error: {e}")
            dashboard_process = None
    
    try:
        iteration = 1
        while True:
            print(f"\n[Iteration {iteration}] {time.strftime('%Y-%m-%d %H:%M:%S')}")
            
            # Skip elevation check after first run (already running as admin)
            success = run_monitoring(skip_elevation=(iteration > 1))
            
            if not success:
                logger.warning(f"Monitoring failed in iteration {iteration}")
            else:
                print(f"✓ Metrics updated in {METRICS_OUTPUT.name}")
            
            iteration += 1
            
            print(f"Next update in {interval} seconds...")
            time.sleep(interval)
            
    except KeyboardInterrupt:
        print("\n\n✓ Watch mode stopped by user")
        logger.info("Watch mode stopped by user")
    finally:
        # Clean up dashboard (thread will terminate automatically)
        if dashboard_process:
            print("\nStopping dashboard...")
            print("✓ Dashboard stopped")


def main():
    """Main entry point for the universal monitor launcher."""
    parser = argparse.ArgumentParser(
        description="Universal System Monitor - Cross-platform monitoring launcher",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python universal.py                              # Run monitors once + launch web dashboard
  python universal.py --watch --interval 5         # Update metrics every 5s (no dashboard)
  python universal.py --watch --dashboard -i 5     # LIVE monitoring: updates every 5s + web dashboard
  python universal.py --tui                        # Run monitors + terminal dashboard
  python universal.py -d -w -i 10                  # Dashboard + watch mode (10s interval)

Workflow:
  1. Detect OS (Windows, Linux, macOS)
  2. Run platform-specific monitoring scripts
  3. Generate data/metrics/current.json
  4. Optionally launch web dashboard (reads current.json every 5s)
  5. With --watch --dashboard: Real-time monitoring (both update every 5s)

Supported Platforms:
  - Windows (PowerShell)
  - Linux (Bash)
  - macOS (Bash)
        """
    )
    
    parser.add_argument(
        "-d", "--dashboard",
        action="store_true",
        help="Launch web dashboard after monitoring (default behavior)"
    )
    
    parser.add_argument(
        "--tui",
        action="store_true",
        help="Launch terminal (TUI) dashboard instead of web dashboard"
    )
    
    parser.add_argument(
        "-w", "--watch",
        action="store_true",
        help="Continuous monitoring mode (runs at intervals)"
    )
    
    parser.add_argument(
        "-i", "--interval",
        type=int,
        default=30,
        help="Interval in seconds for watch mode (default: 30)"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        logger.debug("Verbose logging enabled")
    
    try:
        # Validate interval
        if args.interval < 1:
            print("✗ Error: Interval must be at least 1 second")
            sys.exit(1)
        
        # Watch mode with optional dashboard
        if args.watch:
            # Run initial monitoring
            print("Running initial metrics collection...")
            run_monitoring()
            
            # Start continuous monitoring with optional dashboard
            watch_mode(interval=args.interval, with_dashboard=args.dashboard)
            sys.exit(0)
        
        # Single run mode
        success = run_monitoring()
        
        if not success:
            print("\n✗ Monitoring failed")
            logger.error("Monitoring failed")
            sys.exit(1)
        
        # Launch dashboard (web by default, TUI if --tui flag is set)
        if not METRICS_OUTPUT.exists():
            print("\n✗ Cannot launch dashboard: metrics file not found")
            sys.exit(1)
        
        dashboard_type = 'tui' if args.tui else 'web'
        
        # Default behavior: always launch dashboard unless --no-dashboard would be added
        if args.tui:
            # User explicitly requested TUI
            launch_dashboard(dashboard_type)
        else:
            # Default: launch web dashboard automatically
            print("\n✓ Monitoring completed successfully")
            print("🌐 Launching web dashboard...")
            launch_dashboard('web')
        
        sys.exit(0)
        
    except KeyboardInterrupt:
        print("\n\n✓ Stopped by user")
        logger.info("Stopped by user (Ctrl+C)")
        sys.exit(0)
        
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
