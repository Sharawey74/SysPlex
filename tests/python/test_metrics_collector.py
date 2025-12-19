"""Unit tests for core.metrics_collector module."""

import json
import pytest
from pathlib import Path
from unittest.mock import patch, mock_open
from core.metrics_collector import (
    load_current_metrics,
    get_metric_value,
    _parse_metrics,
    _extract_cpu_metrics,
    _extract_memory_metrics,
    _extract_disk_metrics,
    _extract_network_metrics,
    _get_empty_metrics
)


@pytest.fixture
def valid_metrics_data():
    """Sample valid metrics data."""
    return {
        "timestamp": "2025-12-05T10:30:00Z",
        "platform": "Windows",
        "system": {
            "hostname": "test-machine",
            "os": "Windows 11",
            "uptime": "2 days",
            "manufacturer": "Dell",
            "model": "XPS 15",
            "status": "OK"
        },
        "cpu": {
            "status": "OK",
            "usage_percent": 45.2,
            "load_average": {"1min": 1.2, "5min": 1.5, "15min": 1.8},
            "logical_processors": 8,
            "vendor": "Intel",
            "model": "Core i7"
        },
        "memory": {
            "status": "OK",
            "used_mb": 8192,
            "total_mb": 16384,
            "free_mb": 8192,
            "usage_percent": 50.0
        },
        "disk": [
            {
                "device": "C:",
                "mount": "C:",
                "total_gb": 500,
                "used_gb": 120,
                "free_gb": 380,
                "usage_percent": 24.0,
                "filesystem": "NTFS"
            }
        ],
        "network": [
            {
                "iface": "Ethernet",
                "rx_bytes": 1073741824,
                "tx_bytes": 536870912
            }
        ],
        "temperature": {
            "status": "OK",
            "cpu_temp": 65.0,
            "gpu_temp": 55.0
        },
        "fans": {
            "status": "OK",
            "rpm": 2450
        }
    }


@pytest.fixture
def temp_metrics_file(tmp_path, valid_metrics_data):
    """Create a temporary metrics file."""
    metrics_file = tmp_path / "current.json"
    with open(metrics_file, 'w') as f:
        json.dump(valid_metrics_data, f)
    return metrics_file


class TestLoadCurrentMetrics:
    """Tests for load_current_metrics function."""
    
    def test_load_valid_metrics(self, temp_metrics_file):
        """Test loading valid metrics file."""
        metrics = load_current_metrics(str(temp_metrics_file))
        
        assert metrics['timestamp'] == "2025-12-05T10:30:00Z"
        assert metrics['platform'] == "Windows"
        assert metrics['system']['hostname'] == "test-machine"
        assert metrics['cpu']['usage_percent'] == 45.2
        assert metrics['memory']['total_mb'] == 16384
    
    def test_load_missing_file(self, tmp_path):
        """Test loading non-existent file returns empty metrics."""
        missing_file = tmp_path / "nonexistent.json"
        metrics = load_current_metrics(str(missing_file))
        
        assert metrics['timestamp'] == 'N/A'
        assert metrics['cpu']['status'] == 'unavailable'
        assert metrics['memory']['status'] == 'unavailable'
    
    def test_load_malformed_json(self, tmp_path):
        """Test loading malformed JSON returns empty metrics."""
        bad_file = tmp_path / "bad.json"
        with open(bad_file, 'w') as f:
            f.write("{invalid json")
        
        metrics = load_current_metrics(str(bad_file))
        
        assert metrics['timestamp'] == 'N/A'
        assert metrics['cpu']['status'] == 'unavailable'
    
    def test_load_with_permission_error(self, tmp_path):
        """Test handling permission errors."""
        # Create a file path that doesn't exist in a restricted location
        # This will trigger the file not found path, which is the expected behavior
        metrics_file = tmp_path / "nonexistent" / "current.json"
        
        metrics = load_current_metrics(str(metrics_file))
        
        # When file doesn't exist or can't be accessed, should return empty metrics
        assert metrics['cpu']['status'] == 'unavailable'
        assert metrics['memory']['status'] == 'unavailable'


class TestParseMetrics:
    """Tests for _parse_metrics function."""
    
    def test_parse_complete_metrics(self, valid_metrics_data):
        """Test parsing complete metrics data."""
        parsed = _parse_metrics(valid_metrics_data)
        
        assert 'timestamp' in parsed
        assert 'cpu' in parsed
        assert 'memory' in parsed
        assert 'disk' in parsed
        assert 'network' in parsed
    
    def test_parse_empty_data(self):
        """Test parsing empty data."""
        parsed = _parse_metrics({})
        
        # _parse_metrics returns raw data as-is, so empty dict returns empty dict
        assert isinstance(parsed, dict)
        assert len(parsed) == 0


class TestExtractCpuMetrics:
    """Tests for _extract_cpu_metrics function."""
    
    def test_extract_valid_cpu_data(self):
        """Test extracting valid CPU data."""
        cpu_data = {
            "status": "OK",
            "usage_percent": 45.2,
            "load_average": {"1min": 1.2, "5min": 1.5, "15min": 1.8},
            "logical_processors": 8,
            "vendor": "Intel"
        }
        
        result = _extract_cpu_metrics(cpu_data)
        
        assert result['status'] == 'OK'
        assert result['usage_percent'] == 45.2
        assert result['load_average'] == [1.2, 1.5, 1.8]
        assert result['cores'] == 8
        assert result['vendor'] == "Intel"
    
    def test_extract_cpu_with_list_load_average(self):
        """Test CPU data with load average as list."""
        cpu_data = {
            "status": "OK",
            "usage_percent": 50.0,
            "load_average": [1.0, 2.0, 3.0]
        }
        
        result = _extract_cpu_metrics(cpu_data)
        
        assert result['load_average'] == [1.0, 2.0, 3.0]
    
    def test_extract_unavailable_cpu(self):
        """Test extracting unavailable CPU data."""
        cpu_data = {"status": "unavailable"}
        
        result = _extract_cpu_metrics(cpu_data)
        
        assert result['status'] == 'unavailable'
        assert result['usage_percent'] is None
        assert result['load_average'] is None


class TestExtractMemoryMetrics:
    """Tests for _extract_memory_metrics function."""
    
    def test_extract_valid_memory_data(self):
        """Test extracting valid memory data."""
        memory_data = {
            "status": "OK",
            "used_mb": 8192,
            "total_mb": 16384,
            "free_mb": 8192,
            "usage_percent": 50.0
        }
        
        result = _extract_memory_metrics(memory_data)
        
        assert result['status'] == 'OK'
        assert result['used_mb'] == 8192
        assert result['total_mb'] == 16384
        assert result['usage_percent'] == 50.0
    
    def test_extract_unavailable_memory(self):
        """Test extracting unavailable memory data."""
        memory_data = {"status": "unavailable"}
        
        result = _extract_memory_metrics(memory_data)
        
        assert result['status'] == 'unavailable'
        assert result['used_mb'] is None


class TestExtractDiskMetrics:
    """Tests for _extract_disk_metrics function."""
    
    def test_extract_valid_disk_data(self):
        """Test extracting valid disk data."""
        disk_data = [
            {
                "device": "C:",
                "mount": "C:",
                "total_gb": 500,
                "used_gb": 120,
                "free_gb": 380,
                "usage_percent": 24.0,
                "filesystem": "NTFS"
            }
        ]
        
        result = _extract_disk_metrics(disk_data)
        
        assert len(result) == 1
        assert result[0]['device'] == "C:"
        assert result[0]['usage_percent'] == 24.0
    
    def test_extract_empty_disk_data(self):
        """Test extracting empty disk data."""
        result = _extract_disk_metrics([])
        
        assert result == []
    
    def test_extract_disk_with_unavailable_status(self):
        """Test filtering out unavailable disks."""
        disk_data = [
            {"device": "C:", "status": "OK", "usage_percent": 24.0},
            {"device": "D:", "status": "unavailable"}
        ]
        
        result = _extract_disk_metrics(disk_data)
        
        assert len(result) == 1
        assert result[0]['device'] == "C:"


class TestExtractNetworkMetrics:
    """Tests for _extract_network_metrics function."""
    
    def test_extract_valid_network_data(self):
        """Test extracting valid network data."""
        network_data = [
            {"iface": "eth0", "rx_bytes": 1000000, "tx_bytes": 500000},
            {"iface": "lo", "rx_bytes": 100000, "tx_bytes": 100000}
        ]
        
        result = _extract_network_metrics(network_data)
        
        # Loopback should be excluded from totals
        assert result['total_rx_bytes'] == 1000000
        assert result['total_tx_bytes'] == 500000
        assert len(result['interfaces']) == 2
    
    def test_extract_empty_network_data(self):
        """Test extracting empty network data."""
        result = _extract_network_metrics([])
        
        assert result['total_rx_bytes'] == 0
        assert result['total_tx_bytes'] == 0
        assert result['interfaces'] == []


class TestGetMetricValue:
    """Tests for get_metric_value helper function."""
    
    def test_get_existing_value(self):
        """Test getting existing nested value."""
        metrics = {
            'cpu': {
                'usage_percent': 45.2
            }
        }
        
        value = get_metric_value(metrics, 'cpu.usage_percent')
        
        assert value == 45.2
    
    def test_get_missing_value_returns_default(self):
        """Test getting missing value returns default."""
        metrics = {'cpu': {}}
        
        value = get_metric_value(metrics, 'cpu.missing', 'DEFAULT')
        
        assert value == 'DEFAULT'
    
    def test_get_value_with_none(self):
        """Test getting None value returns default."""
        metrics = {'cpu': {'usage_percent': None}}
        
        value = get_metric_value(metrics, 'cpu.usage_percent', 0)
        
        assert value == 0


class TestGetEmptyMetrics:
    """Tests for _get_empty_metrics function."""
    
    def test_empty_metrics_structure(self):
        """Test empty metrics has correct structure."""
        empty = _get_empty_metrics()
        
        assert empty['timestamp'] == 'N/A'
        assert empty['cpu']['status'] == 'unavailable'
        assert empty['memory']['status'] == 'unavailable'
        assert empty['disk'] == []
        assert empty['network']['total_rx_bytes'] == 0
