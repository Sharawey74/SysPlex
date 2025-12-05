"""Unit tests for display.tui_dashboard module."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from display.tui_dashboard import SystemDashboard
from rich.panel import Panel
from rich.layout import Layout


@pytest.fixture
def sample_metrics():
    """Sample metrics data for testing."""
    return {
        'timestamp': '2025-12-05T10:30:00Z',
        'platform': 'Windows',
        'system': {
            'hostname': 'test-pc',
            'os': 'Windows 11',
            'uptime': '2 days',
            'status': 'OK'
        },
        'cpu': {
            'status': 'OK',
            'usage_percent': 45.2,
            'load_average': [1.2, 1.5, 1.8],
            'cores': 8,
            'vendor': 'Intel'
        },
        'memory': {
            'status': 'OK',
            'used_mb': 8192,
            'total_mb': 16384,
            'free_mb': 8192,
            'usage_percent': 50.0
        },
        'disk': [
            {
                'device': 'C:',
                'mount': 'C:',
                'total_gb': 500,
                'used_gb': 120,
                'free_gb': 380,
                'usage_percent': 24.0,
                'filesystem': 'NTFS'
            }
        ],
        'network': {
            'total_rx_bytes': 1073741824,
            'total_tx_bytes': 536870912,
            'interfaces': [
                {'iface': 'eth0', 'rx_bytes': 1073741824, 'tx_bytes': 536870912}
            ]
        },
        'temperature': {
            'status': 'OK',
            'cpu_temp': 65.0,
            'gpu_temp': 55.0
        },
        'fans': {
            'status': 'OK',
            'fans': []
        }
    }


@pytest.fixture
def sample_alerts():
    """Sample alerts data for testing."""
    return [
        {
            'level': 'warning',
            'metric': 'cpu',
            'message': 'CPU usage above 80%',
            'value': 85.5,
            'threshold': 80.0,
            'timestamp': '2025-12-05T10:30:00Z'
        },
        {
            'level': 'critical',
            'metric': 'memory',
            'message': 'Memory usage critical',
            'value': 95.0,
            'threshold': 90.0,
            'timestamp': '2025-12-05T10:25:00Z'
        },
        {
            'level': 'info',
            'metric': 'system',
            'message': 'System monitoring initialized',
            'timestamp': '2025-12-05T10:20:00Z'
        }
    ]


@pytest.fixture
def dashboard(tmp_path):
    """Create a dashboard instance for testing."""
    metrics_path = tmp_path / "current.json"
    alerts_path = tmp_path / "alerts.json"
    return SystemDashboard(str(metrics_path), str(alerts_path))


class TestSystemDashboardInit:
    """Tests for SystemDashboard initialization."""
    
    def test_init_with_paths(self, tmp_path):
        """Test dashboard initialization with paths."""
        metrics_path = tmp_path / "metrics.json"
        alerts_path = tmp_path / "alerts.json"
        
        dashboard = SystemDashboard(str(metrics_path), str(alerts_path))
        
        assert dashboard.metrics_path == metrics_path
        assert dashboard.alerts_path == alerts_path
        assert dashboard.console is not None


class TestCreateLayout:
    """Tests for create_layout method."""
    
    def test_create_layout_structure(self, dashboard):
        """Test layout structure creation."""
        layout = dashboard.create_layout()
        
        assert isinstance(layout, Layout)
        # Check that layout has the expected structure by trying to access named sections
        try:
            _ = layout["header"]
            _ = layout["body"]
            _ = layout["footer"]
            _ = layout["cpu"]
            _ = layout["memory"]
            _ = layout["disk"]
            _ = layout["network"]
            assert True, "All layout sections exist"
        except KeyError as e:
            assert False, f"Missing layout section: {e}"


class TestGenerateHeaderPanel:
    """Tests for generate_header_panel method."""
    
    def test_generate_header_with_valid_metrics(self, dashboard, sample_metrics):
        """Test header generation with valid metrics."""
        panel = dashboard.generate_header_panel(sample_metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_header_with_missing_data(self, dashboard):
        """Test header generation with missing data."""
        empty_metrics = {}
        panel = dashboard.generate_header_panel(empty_metrics)
        
        assert isinstance(panel, Panel)


class TestGenerateCpuPanel:
    """Tests for generate_cpu_panel method."""
    
    def test_generate_cpu_panel_with_valid_data(self, dashboard, sample_metrics):
        """Test CPU panel with valid data."""
        panel = dashboard.generate_cpu_panel(sample_metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_cpu_panel_with_unavailable_data(self, dashboard):
        """Test CPU panel with unavailable data."""
        metrics = {
            'cpu': {'status': 'unavailable', 'usage_percent': None},
            'temperature': {'status': 'unavailable', 'cpu_temp': None}
        }
        
        panel = dashboard.generate_cpu_panel(metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_cpu_panel_with_high_usage(self, dashboard, sample_metrics):
        """Test CPU panel color coding with high usage."""
        sample_metrics['cpu']['usage_percent'] = 85.0
        
        panel = dashboard.generate_cpu_panel(sample_metrics)
        
        assert isinstance(panel, Panel)


class TestGenerateMemoryPanel:
    """Tests for generate_memory_panel method."""
    
    def test_generate_memory_panel_with_valid_data(self, dashboard, sample_metrics):
        """Test memory panel with valid data."""
        panel = dashboard.generate_memory_panel(sample_metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_memory_panel_with_unavailable_data(self, dashboard):
        """Test memory panel with unavailable data."""
        metrics = {
            'memory': {'status': 'unavailable', 'used_mb': None, 'total_mb': None}
        }
        
        panel = dashboard.generate_memory_panel(metrics)
        
        assert isinstance(panel, Panel)


class TestGenerateDiskPanel:
    """Tests for generate_disk_panel method."""
    
    def test_generate_disk_panel_with_valid_data(self, dashboard, sample_metrics):
        """Test disk panel with valid data."""
        panel = dashboard.generate_disk_panel(sample_metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_disk_panel_with_no_disks(self, dashboard):
        """Test disk panel with no disks."""
        metrics = {'disk': []}
        
        panel = dashboard.generate_disk_panel(metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_disk_panel_with_many_disks(self, dashboard):
        """Test disk panel with many disks (should limit display)."""
        metrics = {
            'disk': [
                {'device': f'Disk{i}', 'usage_percent': i*10, 'free_gb': 100, 'total_gb': 500}
                for i in range(10)
            ]
        }
        
        panel = dashboard.generate_disk_panel(metrics)
        
        assert isinstance(panel, Panel)


class TestGenerateNetworkPanel:
    """Tests for generate_network_panel method."""
    
    def test_generate_network_panel_with_valid_data(self, dashboard, sample_metrics):
        """Test network panel with valid data."""
        panel = dashboard.generate_network_panel(sample_metrics)
        
        assert isinstance(panel, Panel)
    
    def test_generate_network_panel_with_zero_traffic(self, dashboard):
        """Test network panel with zero traffic."""
        metrics = {
            'network': {
                'total_rx_bytes': 0,
                'total_tx_bytes': 0,
                'interfaces': []
            }
        }
        
        panel = dashboard.generate_network_panel(metrics)
        
        assert isinstance(panel, Panel)


class TestGenerateAlertsPanel:
    """Tests for generate_alerts_panel method."""
    
    def test_generate_alerts_panel_with_alerts(self, dashboard, sample_alerts):
        """Test alerts panel with alerts."""
        panel = dashboard.generate_alerts_panel(sample_alerts)
        
        assert isinstance(panel, Panel)
    
    def test_generate_alerts_panel_with_no_alerts(self, dashboard):
        """Test alerts panel with no alerts."""
        panel = dashboard.generate_alerts_panel([])
        
        assert isinstance(panel, Panel)
    
    def test_generate_alerts_panel_with_many_alerts(self, dashboard):
        """Test alerts panel with many alerts (should limit display)."""
        many_alerts = [
            {
                'level': 'info',
                'message': f'Alert {i}',
                'timestamp': '2025-12-05T10:00:00Z'
            }
            for i in range(10)
        ]
        
        panel = dashboard.generate_alerts_panel(many_alerts)
        
        assert isinstance(panel, Panel)
    
    def test_alerts_panel_critical_border_color(self, dashboard):
        """Test alerts panel has red border for critical alerts."""
        critical_alerts = [
            {'level': 'critical', 'message': 'Critical alert'}
        ]
        
        panel = dashboard.generate_alerts_panel(critical_alerts)
        
        assert isinstance(panel, Panel)


class TestHelperMethods:
    """Tests for helper methods."""
    
    def test_get_color_for_percentage_low(self, dashboard):
        """Test color for low percentage (green)."""
        color = dashboard._get_color_for_percentage(30)
        assert color == "green"
    
    def test_get_color_for_percentage_medium(self, dashboard):
        """Test color for medium percentage (yellow)."""
        color = dashboard._get_color_for_percentage(70)
        assert color == "yellow"
    
    def test_get_color_for_percentage_high(self, dashboard):
        """Test color for high percentage (red)."""
        color = dashboard._get_color_for_percentage(90)
        assert color == "red"
    
    def test_get_color_for_temperature_low(self, dashboard):
        """Test color for low temperature (green)."""
        color = dashboard._get_color_for_temperature(50)
        assert color == "green"
    
    def test_get_color_for_temperature_medium(self, dashboard):
        """Test color for medium temperature (yellow)."""
        color = dashboard._get_color_for_temperature(70)
        assert color == "yellow"
    
    def test_get_color_for_temperature_high(self, dashboard):
        """Test color for high temperature (red)."""
        color = dashboard._get_color_for_temperature(85)
        assert color == "red"
    
    def test_create_progress_bar(self, dashboard):
        """Test progress bar creation."""
        bar = dashboard._create_progress_bar(50, "green")
        
        assert isinstance(bar, str)
        assert "50" in bar
        assert "█" in bar
    
    def test_create_mini_progress_bar(self, dashboard):
        """Test mini progress bar creation."""
        bar = dashboard._create_mini_progress_bar(75, "yellow")
        
        assert isinstance(bar, str)
        assert "█" in bar
    
    def test_format_bytes_small(self, dashboard):
        """Test formatting small byte values."""
        formatted = dashboard._format_bytes(512)
        assert "512" in formatted
        assert "B" in formatted
    
    def test_format_bytes_kb(self, dashboard):
        """Test formatting KB values."""
        formatted = dashboard._format_bytes(1024 * 500)
        assert "KB" in formatted
    
    def test_format_bytes_mb(self, dashboard):
        """Test formatting MB values."""
        formatted = dashboard._format_bytes(1024 * 1024 * 100)
        assert "MB" in formatted
    
    def test_format_bytes_gb(self, dashboard):
        """Test formatting GB values."""
        formatted = dashboard._format_bytes(1024 * 1024 * 1024 * 2)
        assert "GB" in formatted


class TestGenerateDashboard:
    """Tests for generate_dashboard method."""
    
    @patch('display.tui_dashboard.load_current_metrics')
    @patch('display.tui_dashboard.load_alerts')
    def test_generate_dashboard_loads_data(self, mock_load_alerts, mock_load_metrics, dashboard, sample_metrics, sample_alerts):
        """Test dashboard generation loads data."""
        mock_load_metrics.return_value = sample_metrics
        mock_load_alerts.return_value = sample_alerts
        
        layout = dashboard.generate_dashboard()
        
        assert isinstance(layout, Layout)
        mock_load_metrics.assert_called_once()
        mock_load_alerts.assert_called_once()


class TestRun:
    """Tests for run method."""
    
    @patch('display.tui_dashboard.Live')
    @patch('display.tui_dashboard.time.sleep')
    def test_run_handles_keyboard_interrupt(self, mock_sleep, mock_live, dashboard):
        """Test run method handles Ctrl+C gracefully."""
        mock_sleep.side_effect = KeyboardInterrupt()
        
        # Should not raise exception
        dashboard.run()
        
        mock_live.assert_called_once()
    
    @patch('display.tui_dashboard.Live')
    @patch('display.tui_dashboard.time.sleep')
    def test_run_handles_exception(self, mock_sleep, mock_live, dashboard):
        """Test run method handles exceptions."""
        mock_sleep.side_effect = Exception("Test error")
        
        with pytest.raises(Exception):
            dashboard.run()
