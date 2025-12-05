"""Unit tests for core.alert_manager module."""

import json
import pytest
from pathlib import Path
from datetime import datetime
from core.alert_manager import (
    load_alerts,
    create_empty_alerts_file,
    add_alert,
    clear_alerts,
    get_alert_counts,
    filter_alerts_by_metric,
    get_latest_alert,
    _sort_alerts_by_timestamp
)


@pytest.fixture
def valid_alerts_data():
    """Sample valid alerts data."""
    return {
        "timestamp": "2025-12-05T10:30:00Z",
        "alerts": [
            {
                "level": "warning",
                "metric": "cpu",
                "message": "CPU usage above 80%",
                "value": 85.5,
                "threshold": 80.0,
                "timestamp": "2025-12-05T10:30:00Z"
            },
            {
                "level": "critical",
                "metric": "memory",
                "message": "Memory usage critical",
                "value": 95.0,
                "threshold": 90.0,
                "timestamp": "2025-12-05T10:25:00Z"
            },
            {
                "level": "info",
                "metric": "disk",
                "message": "Disk space below 30%",
                "value": 25.0,
                "threshold": 30.0,
                "timestamp": "2025-12-05T10:20:00Z"
            }
        ]
    }


@pytest.fixture
def temp_alerts_file(tmp_path, valid_alerts_data):
    """Create a temporary alerts file."""
    alerts_file = tmp_path / "alerts.json"
    with open(alerts_file, 'w') as f:
        json.dump(valid_alerts_data, f)
    return alerts_file


class TestLoadAlerts:
    """Tests for load_alerts function."""
    
    def test_load_valid_alerts(self, temp_alerts_file):
        """Test loading valid alerts file."""
        alerts = load_alerts(str(temp_alerts_file))
        
        assert len(alerts) == 3
        assert alerts[0]['level'] == 'warning'
        assert alerts[1]['level'] == 'critical'
        assert alerts[2]['level'] == 'info'
    
    def test_load_alerts_creates_empty_file_if_missing(self, tmp_path):
        """Test loading creates empty file if missing."""
        missing_file = tmp_path / "alerts.json"
        alerts = load_alerts(str(missing_file))
        
        assert alerts == []
        assert missing_file.exists()
    
    def test_load_malformed_json(self, tmp_path):
        """Test loading malformed JSON returns empty list."""
        bad_file = tmp_path / "bad.json"
        with open(bad_file, 'w') as f:
            f.write("{invalid json")
        
        alerts = load_alerts(str(bad_file))
        
        assert alerts == []
    
    def test_load_alerts_with_level_filter(self, temp_alerts_file):
        """Test filtering alerts by level."""
        critical_alerts = load_alerts(str(temp_alerts_file), level_filter='critical')
        
        assert len(critical_alerts) == 1
        assert critical_alerts[0]['level'] == 'critical'
    
    def test_load_alerts_with_limit(self, temp_alerts_file):
        """Test limiting number of alerts returned."""
        alerts = load_alerts(str(temp_alerts_file), limit=2)
        
        assert len(alerts) == 2
    
    def test_load_invalid_alerts_format(self, tmp_path):
        """Test handling invalid alerts format."""
        invalid_file = tmp_path / "invalid.json"
        with open(invalid_file, 'w') as f:
            json.dump({"alerts": "not a list"}, f)
        
        alerts = load_alerts(str(invalid_file))
        
        assert alerts == []


class TestCreateEmptyAlertsFile:
    """Tests for create_empty_alerts_file function."""
    
    def test_create_empty_file(self, tmp_path):
        """Test creating empty alerts file."""
        alerts_file = tmp_path / "alerts.json"
        result = create_empty_alerts_file(str(alerts_file))
        
        assert result is True
        assert alerts_file.exists()
        
        # Verify structure
        with open(alerts_file, 'r') as f:
            data = json.load(f)
        
        assert 'timestamp' in data
        assert data['alerts'] == []
    
    def test_create_in_nested_directory(self, tmp_path):
        """Test creating file in nested directory."""
        nested_path = tmp_path / "data" / "alerts" / "alerts.json"
        result = create_empty_alerts_file(str(nested_path))
        
        assert result is True
        assert nested_path.exists()
    
    def test_create_with_permission_error(self, tmp_path):
        """Test handling directory creation errors."""
        # Try to create in a path that would require permissions we don't have
        # On Windows, this might not fail, so we just verify the function handles it
        import os
        if os.name == 'nt':
            # On Windows, skip this test as permission handling is different
            pytest.skip("Permission tests not reliable on Windows")
        
        # On Unix, try to create in /root (typically restricted)
        result = create_empty_alerts_file("/root/test_alerts.json")
        
        # Should return False when unable to create file
        assert result is False


class TestAddAlert:
    """Tests for add_alert function."""
    
    def test_add_alert_to_empty_file(self, tmp_path):
        """Test adding alert to non-existent file."""
        alerts_file = tmp_path / "alerts.json"
        
        result = add_alert(
            metric='cpu',
            level='warning',
            message='CPU usage high',
            value=85.5,
            threshold=80.0,
            path=str(alerts_file)
        )
        
        assert result is True
        
        # Verify alert was added
        alerts = load_alerts(str(alerts_file))
        assert len(alerts) == 1
        assert alerts[0]['metric'] == 'cpu'
        assert alerts[0]['level'] == 'warning'
        assert alerts[0]['value'] == 85.5
    
    def test_add_alert_to_existing_file(self, temp_alerts_file):
        """Test adding alert to existing file."""
        result = add_alert(
            metric='temperature',
            level='critical',
            message='Temperature too high',
            path=str(temp_alerts_file)
        )
        
        assert result is True
        
        # Verify alert was added
        alerts = load_alerts(str(temp_alerts_file))
        assert len(alerts) == 4
    
    def test_add_alert_invalid_level(self, tmp_path):
        """Test adding alert with invalid level."""
        alerts_file = tmp_path / "alerts.json"
        
        result = add_alert(
            metric='cpu',
            level='invalid_level',
            message='Test',
            path=str(alerts_file)
        )
        
        assert result is False
    
    def test_add_alert_without_value_threshold(self, tmp_path):
        """Test adding alert without value/threshold."""
        alerts_file = tmp_path / "alerts.json"
        
        result = add_alert(
            metric='system',
            level='info',
            message='System started',
            path=str(alerts_file)
        )
        
        assert result is True
        
        alerts = load_alerts(str(alerts_file))
        assert 'value' not in alerts[0]
        assert 'threshold' not in alerts[0]


class TestClearAlerts:
    """Tests for clear_alerts function."""
    
    def test_clear_existing_alerts(self, temp_alerts_file):
        """Test clearing existing alerts."""
        # Verify file has alerts
        alerts = load_alerts(str(temp_alerts_file))
        assert len(alerts) > 0
        
        # Clear alerts
        result = clear_alerts(str(temp_alerts_file))
        assert result is True
        
        # Verify alerts cleared
        alerts = load_alerts(str(temp_alerts_file))
        assert alerts == []


class TestGetAlertCounts:
    """Tests for get_alert_counts function."""
    
    def test_count_alerts_by_level(self):
        """Test counting alerts by level."""
        alerts = [
            {"level": "info", "message": "Test 1"},
            {"level": "warning", "message": "Test 2"},
            {"level": "warning", "message": "Test 3"},
            {"level": "critical", "message": "Test 4"}
        ]
        
        counts = get_alert_counts(alerts)
        
        assert counts['info'] == 1
        assert counts['warning'] == 2
        assert counts['critical'] == 1
    
    def test_count_empty_alerts(self):
        """Test counting empty alerts list."""
        counts = get_alert_counts([])
        
        assert counts['info'] == 0
        assert counts['warning'] == 0
        assert counts['critical'] == 0


class TestSortAlertsByTimestamp:
    """Tests for _sort_alerts_by_timestamp function."""
    
    def test_sort_alerts_newest_first(self):
        """Test sorting alerts by timestamp (newest first)."""
        alerts = [
            {"message": "Old", "timestamp": "2025-12-05T10:00:00Z"},
            {"message": "New", "timestamp": "2025-12-05T12:00:00Z"},
            {"message": "Middle", "timestamp": "2025-12-05T11:00:00Z"}
        ]
        
        sorted_alerts = _sort_alerts_by_timestamp(alerts)
        
        assert sorted_alerts[0]['message'] == "New"
        assert sorted_alerts[1]['message'] == "Middle"
        assert sorted_alerts[2]['message'] == "Old"
    
    def test_sort_alerts_with_missing_timestamp(self):
        """Test sorting alerts when some lack timestamps."""
        alerts = [
            {"message": "With timestamp", "timestamp": "2025-12-05T10:00:00Z"},
            {"message": "Without timestamp"}
        ]
        
        # Should not crash
        sorted_alerts = _sort_alerts_by_timestamp(alerts)
        
        assert len(sorted_alerts) == 2


class TestFilterAlertsByMetric:
    """Tests for filter_alerts_by_metric function."""
    
    def test_filter_by_metric(self):
        """Test filtering alerts by metric type."""
        alerts = [
            {"metric": "cpu", "message": "CPU alert"},
            {"metric": "memory", "message": "Memory alert"},
            {"metric": "cpu", "message": "Another CPU alert"}
        ]
        
        cpu_alerts = filter_alerts_by_metric(alerts, 'cpu')
        
        assert len(cpu_alerts) == 2
        assert all(a['metric'] == 'cpu' for a in cpu_alerts)
    
    def test_filter_no_matches(self):
        """Test filtering with no matches."""
        alerts = [
            {"metric": "cpu", "message": "CPU alert"}
        ]
        
        disk_alerts = filter_alerts_by_metric(alerts, 'disk')
        
        assert disk_alerts == []


class TestGetLatestAlert:
    """Tests for get_latest_alert function."""
    
    def test_get_latest_from_multiple_alerts(self):
        """Test getting latest alert from multiple."""
        alerts = [
            {"message": "Old", "timestamp": "2025-12-05T10:00:00Z"},
            {"message": "Latest", "timestamp": "2025-12-05T12:00:00Z"},
            {"message": "Middle", "timestamp": "2025-12-05T11:00:00Z"}
        ]
        
        latest = get_latest_alert(alerts)
        
        assert latest['message'] == "Latest"
    
    def test_get_latest_from_empty_list(self):
        """Test getting latest alert from empty list."""
        latest = get_latest_alert([])
        
        assert latest is None
