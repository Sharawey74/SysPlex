"""
Bash Script Validation Tests for Docker Container

Tests individual bash scripts for:
- Execution without errors
- Valid JSON output
- Required fields present
- Graceful handling of missing tools
- Environment variable usage
"""

import pytest
import docker
import json
import time


@pytest.fixture(scope="module")
def docker_client():
    """Create Docker client"""
    return docker.from_env()


@pytest.fixture(scope="module")
def container(docker_client):
    """Get or start the system monitor container"""
    container_name = "system-monitor-method2"
    
    try:
        container = docker_client.containers.get(container_name)
        if container.status != "running":
            container.start()
            time.sleep(3)
        return container
    except docker.errors.NotFound:
        pytest.skip(f"Container {container_name} not found. Run docker-compose up first.")


class TestMainMonitor:
    """Test main monitor script"""
    
    def test_main_monitor_exists(self, container):
        """Check main monitor script exists"""
        exit_code, output = container.exec_run("test -f /app/scripts/main_monitor.sh")
        assert exit_code == 0, "main_monitor.sh not found"
    
    def test_main_monitor_executable(self, container):
        """Check main monitor is executable"""
        exit_code, output = container.exec_run("test -x /app/scripts/main_monitor.sh")
        assert exit_code == 0, "main_monitor.sh is not executable"
    
    def test_main_monitor_execution(self, container):
        """Test main monitor executes without errors"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/main_monitor.sh",
            workdir="/app"
        )
        
        # Script should complete successfully
        assert exit_code == 0, f"main_monitor.sh failed: {output.decode()}"
    
    def test_main_monitor_creates_json(self, container):
        """Test main monitor creates current.json"""
        # Run monitor
        container.exec_run("bash /app/scripts/main_monitor.sh", workdir="/app")
        
        # Check JSON exists
        exit_code, output = container.exec_run("test -f /app/data/metrics/current.json")
        assert exit_code == 0, "current.json not created"
    
    def test_main_monitor_uses_host_proc(self, container):
        """Test main monitor uses HOST_PROC environment variable"""
        # Run with custom HOST_PROC
        exit_code, output = container.exec_run(
            "bash -c 'export HOST_PROC=/host/proc && bash /app/scripts/main_monitor.sh'",
            workdir="/app"
        )
        
        assert exit_code == 0, "Failed to use HOST_PROC"


class TestCPUMonitor:
    """Test CPU monitoring script"""
    
    def test_cpu_monitor_exists(self, container):
        """Check CPU monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/cpu_monitor.sh")
        assert exit_code == 0
    
    def test_cpu_monitor_execution(self, container):
        """Test CPU monitor executes"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/cpu_monitor.sh",
            workdir="/app"
        )
        
        assert exit_code == 0, f"cpu_monitor.sh failed: {output.decode()}"
    
    def test_cpu_monitor_output(self, container):
        """Test CPU monitor produces valid JSON output"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/cpu_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        # Should output JSON
        try:
            data = json.loads(output_str)
            assert "usage_percent" in data, "Missing usage_percent"
            assert "load_average" in data, "Missing load_average"
            assert "cores" in data, "Missing cores"
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON output: {e}\nOutput: {output_str}")


class TestMemoryMonitor:
    """Test memory monitoring script"""
    
    def test_memory_monitor_exists(self, container):
        """Check memory monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/memory_monitor.sh")
        assert exit_code == 0
    
    def test_memory_monitor_execution(self, container):
        """Test memory monitor executes"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/memory_monitor.sh",
            workdir="/app"
        )
        
        assert exit_code == 0, f"memory_monitor.sh failed: {output.decode()}"
    
    def test_memory_monitor_output(self, container):
        """Test memory monitor produces valid JSON"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/memory_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert "total_mb" in data
            assert "used_mb" in data
            assert "available_mb" in data
            assert "percent_used" in data
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestDiskMonitor:
    """Test disk monitoring script"""
    
    def test_disk_monitor_exists(self, container):
        """Check disk monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/disk_monitor.sh")
        assert exit_code == 0
    
    def test_disk_monitor_execution(self, container):
        """Test disk monitor executes"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/disk_monitor.sh",
            workdir="/app"
        )
        
        assert exit_code == 0, f"disk_monitor.sh failed: {output.decode()}"
    
    def test_disk_monitor_output(self, container):
        """Test disk monitor produces valid JSON array"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/disk_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert isinstance(data, list), "Expected array of disk partitions"
            
            if data:
                disk = data[0]
                assert "partition" in disk
                assert "total_gb" in disk
                assert "used_gb" in disk
                assert "available_gb" in disk
                assert "percent_used" in disk
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestNetworkMonitor:
    """Test network monitoring script"""
    
    def test_network_monitor_exists(self, container):
        """Check network monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/network_monitor.sh")
        assert exit_code == 0
    
    def test_network_monitor_execution(self, container):
        """Test network monitor executes"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/network_monitor.sh",
            workdir="/app"
        )
        
        assert exit_code == 0, f"network_monitor.sh failed: {output.decode()}"
    
    def test_network_monitor_output(self, container):
        """Test network monitor produces valid JSON"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/network_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert "interfaces" in data
            assert isinstance(data["interfaces"], list)
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestProcessMonitor:
    """Test process monitoring script"""
    
    def test_process_monitor_exists(self, container):
        """Check process monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/process_monitor.sh")
        assert exit_code == 0
    
    def test_process_monitor_execution(self, container):
        """Test process monitor executes"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/process_monitor.sh",
            workdir="/app"
        )
        
        assert exit_code == 0, f"process_monitor.sh failed: {output.decode()}"
    
    def test_process_monitor_output(self, container):
        """Test process monitor produces valid JSON"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/process_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert "total" in data
            assert "running" in data
            assert "sleeping" in data
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestTemperatureMonitor:
    """Test temperature monitoring script"""
    
    def test_temperature_monitor_exists(self, container):
        """Check temperature monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/temperature_monitor.sh")
        assert exit_code == 0
    
    def test_temperature_monitor_execution(self, container):
        """Test temperature monitor executes (may return empty if sensors unavailable)"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/temperature_monitor.sh",
            workdir="/app"
        )
        
        # Should not crash even if sensors unavailable
        assert exit_code == 0, f"temperature_monitor.sh failed: {output.decode()}"
    
    def test_temperature_monitor_output(self, container):
        """Test temperature monitor produces valid JSON or empty array"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/temperature_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert isinstance(data, list), "Expected array of temperature sensors"
            
            # If sensors available, check format
            if data:
                sensor = data[0]
                assert "sensor" in sensor
                assert "temperature_c" in sensor
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestGPUMonitor:
    """Test GPU monitoring script"""
    
    def test_gpu_monitor_exists(self, container):
        """Check GPU monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/gpu_monitor.sh")
        assert exit_code == 0
    
    def test_gpu_monitor_execution(self, container):
        """Test GPU monitor executes (gracefully handles missing nvidia-smi)"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/gpu_monitor.sh",
            workdir="/app"
        )
        
        # Should not crash even if nvidia-smi unavailable
        assert exit_code == 0, f"gpu_monitor.sh failed: {output.decode()}"
    
    def test_gpu_monitor_output(self, container):
        """Test GPU monitor produces valid JSON or empty array"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/gpu_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert isinstance(data, list), "Expected array of GPUs"
            
            # If GPU available, check format
            if data:
                gpu = data[0]
                assert "name" in gpu
                assert "temperature_c" in gpu or "utilization_percent" in gpu
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestSmartMonitor:
    """Test SMART disk health monitoring script"""
    
    def test_smart_monitor_exists(self, container):
        """Check SMART monitor exists"""
        exit_code, _ = container.exec_run("test -f /app/scripts/monitors/unix/smart_monitor.sh")
        assert exit_code == 0
    
    def test_smart_monitor_execution(self, container):
        """Test SMART monitor executes (gracefully handles missing smartctl)"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/smart_monitor.sh",
            workdir="/app"
        )
        
        # Should not crash even if smartctl unavailable
        assert exit_code == 0, f"smart_monitor.sh failed: {output.decode()}"
    
    def test_smart_monitor_output(self, container):
        """Test SMART monitor produces valid JSON or empty array"""
        exit_code, output = container.exec_run(
            "bash /app/scripts/monitors/unix/smart_monitor.sh",
            workdir="/app"
        )
        
        output_str = output.decode().strip()
        
        try:
            data = json.loads(output_str)
            assert isinstance(data, list), "Expected array of disks"
            
            # If disks available, check format
            if data:
                disk = data[0]
                assert "device" in disk
                assert "health" in disk or "temperature_c" in disk
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}\nOutput: {output_str}")


class TestEnvironmentVariables:
    """Test environment variable usage in scripts"""
    
    def test_host_proc_variable(self, container):
        """Test scripts use HOST_PROC variable"""
        # Run with custom HOST_PROC
        exit_code, output = container.exec_run(
            "bash -c 'export HOST_PROC=/host/proc && bash /app/scripts/monitors/unix/cpu_monitor.sh'",
            workdir="/app"
        )
        
        assert exit_code == 0, "Failed to use HOST_PROC"
        
        # Output should be valid JSON
        output_str = output.decode().strip()
        try:
            json.loads(output_str)
        except json.JSONDecodeError:
            pytest.fail("Script failed to produce valid JSON with HOST_PROC")
    
    def test_host_sys_variable(self, container):
        """Test scripts can use HOST_SYS variable"""
        # Run with custom HOST_SYS
        exit_code, output = container.exec_run(
            "bash -c 'export HOST_SYS=/host/sys && bash /app/scripts/monitors/unix/temperature_monitor.sh'",
            workdir="/app"
        )
        
        # Should complete without error
        assert exit_code == 0
    
    def test_host_dev_variable(self, container):
        """Test scripts can use HOST_DEV variable"""
        # Run with custom HOST_DEV
        exit_code, output = container.exec_run(
            "bash -c 'export HOST_DEV=/host/dev && bash /app/scripts/monitors/unix/smart_monitor.sh'",
            workdir="/app"
        )
        
        # Should complete without error
        assert exit_code == 0


class TestErrorHandling:
    """Test graceful error handling in scripts"""
    
    def test_missing_proc_directory(self, container):
        """Test scripts handle missing /proc gracefully"""
        # Run with invalid HOST_PROC
        exit_code, output = container.exec_run(
            "bash -c 'export HOST_PROC=/nonexistent && bash /app/scripts/monitors/unix/cpu_monitor.sh'",
            workdir="/app"
        )
        
        # Should not crash (exit code 0) but may return empty/default JSON
        assert exit_code == 0, "Script crashed with missing /proc"
    
    def test_invalid_json_recovery(self, container):
        """Test main monitor handles invalid JSON from sub-monitors"""
        # This is more of an integration test
        # The main monitor should not crash if a sub-monitor fails
        
        exit_code, output = container.exec_run(
            "bash /app/scripts/main_monitor.sh",
            workdir="/app"
        )
        
        # Main monitor should complete successfully
        assert exit_code == 0
        
        # Should create a valid current.json
        exit_code, cat_output = container.exec_run("cat /app/data/metrics/current.json")
        assert exit_code == 0
        
        try:
            json.loads(cat_output.decode())
        except json.JSONDecodeError:
            pytest.fail("main_monitor created invalid current.json")


class TestScriptPermissions:
    """Test all scripts have correct permissions"""
    
    def test_all_monitors_executable(self, container):
        """Check all monitor scripts are executable"""
        monitors = [
            "/app/scripts/monitors/unix/cpu_monitor.sh",
            "/app/scripts/monitors/unix/memory_monitor.sh",
            "/app/scripts/monitors/unix/disk_monitor.sh",
            "/app/scripts/monitors/unix/network_monitor.sh",
            "/app/scripts/monitors/unix/process_monitor.sh",
            "/app/scripts/monitors/unix/temperature_monitor.sh",
            "/app/scripts/monitors/unix/gpu_monitor.sh",
            "/app/scripts/monitors/unix/smart_monitor.sh"
        ]
        
        for monitor in monitors:
            exit_code, _ = container.exec_run(f"test -x {monitor}")
            assert exit_code == 0, f"{monitor} is not executable"
    
    def test_main_monitor_executable(self, container):
        """Check main monitor is executable"""
        exit_code, _ = container.exec_run("test -x /app/scripts/main_monitor.sh")
        assert exit_code == 0, "main_monitor.sh is not executable"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
