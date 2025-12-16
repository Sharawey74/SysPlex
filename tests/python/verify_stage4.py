#!/usr/bin/env python3
"""
Stage 4 Verification Script
Verify all components for Web Dashboard + Reports
"""

import sys
from pathlib import Path
from datetime import datetime

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def print_header(title):
    """Print section header"""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)

def check_file(filepath, description):
    """Check if a file exists"""
    if filepath.exists():
        size = filepath.stat().st_size
        print(f"✅ {description}")
        print(f"   {filepath.relative_to(project_root)} ({size:,} bytes)")
        return True
    else:
        print(f"❌ {description}")
        print(f"   Missing: {filepath.relative_to(project_root)}")
        return False

def main():
    """Run verification checks"""
    print_header("Stage 4: Web Dashboard + Reports - Verification")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    checks = []
    
    # Check web module files
    print_header("Web Module Files")
    checks.append(check_file(project_root / 'web' / '__init__.py', 'Web module init'))
    checks.append(check_file(project_root / 'web' / 'app.py', 'Flask application'))
    checks.append(check_file(project_root / 'web' / 'report_generator.py', 'Report generator'))
    
    # Check template files
    print_header("Template Files")
    checks.append(check_file(project_root / 'templates' / 'dashboard.html', 'Dashboard template'))
    checks.append(check_file(project_root / 'templates' / 'report_template.html', 'HTML report template'))
    checks.append(check_file(project_root / 'templates' / 'report_template.md', 'Markdown report template'))
    
    # Check static files
    print_header("Static Files")
    checks.append(check_file(project_root / 'static' / 'js' / 'dashboard.js', 'Dashboard JavaScript'))
    checks.append(check_file(project_root / 'static' / 'css' / 'styles.css', 'Dashboard CSS'))
    
    # Check launcher
    print_header("Launcher Files")
    checks.append(check_file(project_root / 'dashboard_web.py', 'Web dashboard launcher'))
    
    # Check directories
    print_header("Report Directories")
    html_dir = project_root / 'reports' / 'html'
    md_dir = project_root / 'reports' / 'markdown'
    
    if html_dir.exists():
        print(f"✅ HTML reports directory: {html_dir.relative_to(project_root)}")
    else:
        print(f"⚠️  HTML reports directory will be created on first report")
    
    if md_dir.exists():
        print(f"✅ Markdown reports directory: {md_dir.relative_to(project_root)}")
    else:
        print(f"⚠️  Markdown reports directory will be created on first report")
    
    # Check dependencies
    print_header("Python Dependencies Check")
    try:
        import flask
        print(f"✅ Flask {flask.__version__}")
    except ImportError:
        print("❌ Flask not installed")
        checks.append(False)
    
    try:
        import jinja2
        print(f"✅ Jinja2 {jinja2.__version__}")
    except ImportError:
        print("❌ Jinja2 not installed")
        checks.append(False)
    
    # Test imports
    print_header("Module Import Test")
    try:
        from web.app import app
        print("✅ Flask app imports successfully")
        checks.append(True)
    except Exception as e:
        print(f"❌ Flask app import failed: {e}")
        checks.append(False)
    
    try:
        from web.report_generator import ReportGenerator
        print("✅ ReportGenerator imports successfully")
        checks.append(True)
    except Exception as e:
        print(f"❌ ReportGenerator import failed: {e}")
        checks.append(False)
    
    # Summary
    print_header("Verification Summary")
    passed = sum(checks)
    total = len(checks)
    percentage = (passed / total * 100) if total > 0 else 0
    
    print(f"Checks passed: {passed}/{total} ({percentage:.1f}%)")
    
    if percentage == 100:
        print("\n✅ Stage 4 verification: COMPLETE")
        print("\n🚀 Next steps:")
        print("   1. Run: python dashboard_web.py")
        print("   2. Open: http://localhost:5000")
        print("   3. Test API: http://localhost:5000/api/metrics")
        print("   4. Generate reports via dashboard button")
        return 0
    elif percentage >= 90:
        print("\n⚠️  Stage 4 verification: MOSTLY COMPLETE")
        print("   Minor issues detected, but should be functional")
        return 0
    else:
        print("\n❌ Stage 4 verification: INCOMPLETE")
        print("   Please fix the errors above")
        return 1

if __name__ == '__main__':
    sys.exit(main())
