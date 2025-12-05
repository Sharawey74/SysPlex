"""
Run all Python unit tests for the dashboard.

Usage:
    python tests/python/run_tests.py
    python tests/python/run_tests.py --coverage
"""

import sys
import subprocess
from pathlib import Path


def run_tests(with_coverage=False):
    """Run pytest tests with optional coverage."""
    
    # Ensure we're in the project root
    project_root = Path(__file__).parent.parent.parent
    
    if with_coverage:
        cmd = [
            'pytest',
            'tests/python/',
            '-v',
            '--cov=core',
            '--cov=display',
            '--cov-report=term-missing',
            '--cov-report=html'
        ]
    else:
        cmd = [
            'pytest',
            'tests/python/',
            '-v'
        ]
    
    print(f"Running tests from: {project_root}")
    print(f"Command: {' '.join(cmd)}\n")
    
    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            check=False
        )
        
        return result.returncode
        
    except FileNotFoundError:
        print("❌ Error: pytest not found. Install it with:")
        print("   pip install pytest pytest-cov pytest-mock")
        return 1


if __name__ == "__main__":
    with_coverage = '--coverage' in sys.argv or '-c' in sys.argv
    
    exit_code = run_tests(with_coverage)
    
    if exit_code == 0:
        print("\n✅ All tests passed!")
    else:
        print(f"\n❌ Tests failed with exit code {exit_code}")
    
    sys.exit(exit_code)
