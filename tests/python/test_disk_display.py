#!/usr/bin/env python3
"""Quick test to see what disks are being parsed"""

import sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from core.metrics_collector import load_current_metrics

metrics = load_current_metrics()
disks = metrics.get('disk', [])

print(f"\nTotal disks parsed: {len(disks)}")
print("-" * 60)

for i, disk in enumerate(disks, 1):
    print(f"\nDisk {i}:")
    print(f"  Device: {disk.get('device', 'N/A')}")
    print(f"  Usage: {disk.get('usage_percent', 'N/A')}%")
    print(f"  Used/Total: {disk.get('used_gb', 'N/A')}/{disk.get('total_gb', 'N/A')} GB")
    print(f"  Filesystem: {disk.get('filesystem', 'N/A')}")

print("\n" + "=" * 60)
print(f"Memory usage: {metrics.get('memory', {}).get('usage_percent', 'N/A')}%")
print(f"GPU vendor: {metrics.get('temperature', {}).get('gpu_vendor', 'N/A')}")

# Handle network being either a list or dict
network = metrics.get('network', [])
if isinstance(network, list):
    print(f"Network interfaces: {len(network)}")
else:
    print(f"Network interfaces: {len(network.get('interfaces', []))}")
