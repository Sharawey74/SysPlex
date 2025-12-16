#!/usr/bin/env python3
"""Quick test to verify GPU data reading"""
import sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

import json
import pytest

def test_gpu_data_reading():
    """Test that GPU data can be read from current.json"""
    metrics_file = project_root / 'data' / 'metrics' / 'current.json'
    
    # Skip if metrics file doesn't exist
    if not metrics_file.exists():
        pytest.skip("Metrics file not found")
    
    try:
        with open(metrics_file, 'r', encoding='utf-8-sig') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        pytest.skip("Invalid JSON in metrics file")
    
    # Test temperature data exists
    assert 'temperature' in data, "No temperature data in metrics"
    temp = data.get('temperature', {})
    
    # GPUs are optional, but if present should be valid
    gpus = temp.get('gpus', [])
    
    print(f'\nGPU count: {len(gpus)}')
    
    for i, gpu in enumerate(gpus):
        print(f'\nGPU [{i}]:')
        print(f'  Vendor: {gpu.get("vendor")}')
        print(f'  Model: {gpu.get("model")}')
        print(f'  Type: {gpu.get("type")}')
        print(f'  Temp: {gpu.get("temperature_celsius")}°C')
        print(f'  VRAM: {gpu.get("vram_used_mb")}/{gpu.get("vram_total_mb")} MB')
        
        # Validate GPU structure
        assert 'vendor' in gpu, f"GPU {i} missing vendor"
        assert 'model' in gpu, f"GPU {i} missing model"
    
    # Test dashboard code logic
    print("\nTesting dashboard logic:")
    primary_gpu = None
    if gpus:
        # First try to find a dedicated GPU
        for gpu in gpus:
            if gpu.get('type') == 'Dedicated':
                primary_gpu = gpu
                break
        # If no dedicated GPU, use the first one
        if not primary_gpu:
            primary_gpu = gpus[0]
    
    if primary_gpu:
        print(f"Primary GPU selected: {primary_gpu.get('vendor')} {primary_gpu.get('model')}")
        print(f"Temperature: {primary_gpu.get('temperature_celsius')}°C")
    else:
        print("No GPU found!")
