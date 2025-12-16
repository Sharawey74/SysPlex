"""
Pytest configuration for Docker tests

Supports both Docker methods:
- Method 1: Privileged mode with host PID namespace
- Method 2: Bind mounts with explicit host paths
"""

import pytest
import docker as docker_module


def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line(
        "markers", "docker: marks tests as requiring Docker (deselect with '-m \"not docker\"')"
    )
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers", "method1: marks tests specific to Docker Method 1"
    )
    config.addinivalue_line(
        "markers", "method2: marks tests specific to Docker Method 2"
    )


@pytest.fixture(scope="session", autouse=True)
def check_docker_available():
    """Check if Docker is available before running tests"""
    try:
        client = docker_module.from_env()
        client.ping()
    except Exception as e:
        pytest.skip(f"Docker is not available: {e}", allow_module_level=True)


@pytest.fixture(scope="session")
def docker_client():
    """Provide Docker client for tests"""
    return docker_module.from_env()


@pytest.fixture(scope="session")
def method1_container(docker_client):
    """
    Get Method 1 container (privileged mode)
    Skips test if container not available
    """
    container_name = "system-monitor-method1"
    try:
        container = docker_client.containers.get(container_name)
        if container.status != "running":
            container.start()
            import time
            time.sleep(3)
        return container
    except docker_module.errors.NotFound:
        pytest.skip(f"Method 1 container '{container_name}' not found")


@pytest.fixture(scope="session")
def method2_container(docker_client):
    """
    Get Method 2 container (bind mounts)
    Skips test if container not available
    """
    container_name = "system-monitor-method2"
    try:
        container = docker_client.containers.get(container_name)
        if container.status != "running":
            container.start()
            import time
            time.sleep(3)
        return container
    except docker_module.errors.NotFound:
        pytest.skip(f"Method 2 container '{container_name}' not found")


@pytest.fixture(scope="session")
def any_container(docker_client):
    """
    Get any available container (Method 1 or Method 2)
    Prefers Method 2 if both available
    """
    # Try Method 2 first (more secure)
    for container_name in ["system-monitor-method2", "system-monitor-method1"]:
        try:
            container = docker_client.containers.get(container_name)
            if container.status != "running":
                container.start()
                import time
                time.sleep(3)
            return container
        except docker_module.errors.NotFound:
            continue
    
    pytest.skip("No Docker container found. Start Method 1 or Method 2 container.")
