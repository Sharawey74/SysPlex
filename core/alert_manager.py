"""
Alert Manager Module

Manages system alerts by reading from alerts.json and providing
filtering and sorting capabilities.
"""

import json
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Default paths
DEFAULT_ALERTS_PATH = "data/alerts/alerts.json"

# Alert levels
ALERT_LEVELS = ['info', 'warning', 'critical']


def load_alerts(
    path: str = DEFAULT_ALERTS_PATH,
    level_filter: Optional[str] = None,
    limit: Optional[int] = None
) -> List[Dict[str, Any]]:
    """
    Load system alerts from alerts.json.
    
    Args:
        path: Path to the alerts.json file
        level_filter: Optional filter by alert level ('info', 'warning', 'critical')
        limit: Optional limit on number of alerts to return
        
    Returns:
        list: List of alert dicts sorted by timestamp (newest first),
              empty list if no alerts or file missing
              
    Alert Structure:
        {
            "level": "warning|critical|info",
            "metric": "cpu|memory|disk|temperature|...",
            "message": "CPU usage above 80%",
            "value": 85.5,
            "threshold": 80.0,
            "timestamp": "2025-12-05T10:30:00Z"
        }
        
    Example:
        >>> alerts = load_alerts(level_filter='critical')
        >>> warning_alerts = load_alerts(level_filter='warning', limit=5)
    """
    alerts_path = Path(path)
    
    try:
        # Create empty file if it doesn't exist
        if not alerts_path.exists():
            logger.info(f"Alerts file not found. Creating empty file: {alerts_path}")
            create_empty_alerts_file(path)
            return []
        
        with alerts_path.open('r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Extract alerts list
        alerts = data.get('alerts', [])
        
        if not isinstance(alerts, list):
            logger.warning(f"Invalid alerts format in {alerts_path}")
            return []
        
        # Filter by level if specified
        if level_filter and level_filter in ALERT_LEVELS:
            alerts = [a for a in alerts if a.get('level') == level_filter]
        
        # Sort by timestamp (newest first)
        alerts = _sort_alerts_by_timestamp(alerts)
        
        # Apply limit if specified
        if limit and limit > 0:
            alerts = alerts[:limit]
        
        logger.debug(f"Loaded {len(alerts)} alerts from {alerts_path}")
        return alerts
        
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in {alerts_path}: {e}")
        return []
        
    except PermissionError as e:
        logger.error(f"Permission denied reading {alerts_path}: {e}")
        return []
        
    except Exception as e:
        logger.error(f"Unexpected error reading {alerts_path}: {e}")
        return []


def create_empty_alerts_file(path: str = DEFAULT_ALERTS_PATH) -> bool:
    """
    Create empty alerts.json file with proper schema.
    
    Args:
        path: Path where the alerts.json file should be created
        
    Returns:
        bool: True if file created successfully, False otherwise
        
    Example:
        >>> create_empty_alerts_file("data/alerts/alerts.json")
        True
    """
    alerts_path = Path(path)
    
    try:
        # Ensure parent directory exists
        alerts_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Create empty alerts structure
        empty_structure = {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "alerts": []
        }
        
        with alerts_path.open('w', encoding='utf-8') as f:
            json.dump(empty_structure, f, indent=2)
        
        logger.info(f"Created empty alerts file: {alerts_path}")
        return True
        
    except PermissionError as e:
        logger.error(f"Permission denied creating {alerts_path}: {e}")
        return False
        
    except Exception as e:
        logger.error(f"Error creating alerts file {alerts_path}: {e}")
        return False


def add_alert(
    metric: str,
    level: str,
    message: str,
    value: Optional[float] = None,
    threshold: Optional[float] = None,
    path: str = DEFAULT_ALERTS_PATH
) -> bool:
    """
    Add a new alert to alerts.json.
    
    Args:
        metric: Metric type (cpu, memory, disk, etc.)
        level: Alert level (info, warning, critical)
        message: Human-readable alert message
        value: Current metric value
        threshold: Threshold that triggered the alert
        path: Path to alerts.json file
        
    Returns:
        bool: True if alert added successfully, False otherwise
        
    Example:
        >>> add_alert('cpu', 'warning', 'CPU usage above 80%', 85.5, 80.0)
        True
    """
    if level not in ALERT_LEVELS:
        logger.error(f"Invalid alert level: {level}. Must be one of {ALERT_LEVELS}")
        return False
    
    alerts_path = Path(path)
    
    try:
        # Load existing alerts
        if alerts_path.exists():
            with alerts_path.open('r', encoding='utf-8') as f:
                data = json.load(f)
        else:
            data = {"timestamp": "", "alerts": []}
        
        # Create new alert
        new_alert = {
            "level": level,
            "metric": metric,
            "message": message,
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        }
        
        if value is not None:
            new_alert["value"] = value
        if threshold is not None:
            new_alert["threshold"] = threshold
        
        # Add to alerts list
        data["alerts"].append(new_alert)
        data["timestamp"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        
        # Write back to file
        with alerts_path.open('w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        
        logger.info(f"Added {level} alert for {metric}: {message}")
        return True
        
    except Exception as e:
        logger.error(f"Error adding alert: {e}")
        return False


def clear_alerts(path: str = DEFAULT_ALERTS_PATH) -> bool:
    """
    Clear all alerts from alerts.json.
    
    Args:
        path: Path to alerts.json file
        
    Returns:
        bool: True if cleared successfully, False otherwise
        
    Example:
        >>> clear_alerts()
        True
    """
    return create_empty_alerts_file(path)


def get_alert_counts(alerts: List[Dict[str, Any]]) -> Dict[str, int]:
    """
    Get count of alerts by level.
    
    Args:
        alerts: List of alert dictionaries
        
    Returns:
        dict: Count of alerts by level
        
    Example:
        >>> counts = get_alert_counts(alerts)
        >>> print(counts)
        {'info': 2, 'warning': 5, 'critical': 1}
    """
    counts = {'info': 0, 'warning': 0, 'critical': 0}
    
    for alert in alerts:
        level = alert.get('level', 'info')
        if level in counts:
            counts[level] += 1
    
    return counts


def _sort_alerts_by_timestamp(alerts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Sort alerts by timestamp (newest first).
    
    Args:
        alerts: List of alert dictionaries
        
    Returns:
        list: Sorted alerts
    """
    def get_timestamp(alert: Dict[str, Any]) -> str:
        """Get timestamp for sorting, with fallback."""
        return alert.get('timestamp', '1970-01-01T00:00:00Z')
    
    try:
        return sorted(alerts, key=get_timestamp, reverse=True)
    except Exception as e:
        logger.warning(f"Error sorting alerts: {e}. Returning unsorted.")
        return alerts


def filter_alerts_by_metric(
    alerts: List[Dict[str, Any]],
    metric: str
) -> List[Dict[str, Any]]:
    """
    Filter alerts by metric type.
    
    Args:
        alerts: List of alert dictionaries
        metric: Metric type to filter by (cpu, memory, disk, etc.)
        
    Returns:
        list: Filtered alerts
        
    Example:
        >>> cpu_alerts = filter_alerts_by_metric(alerts, 'cpu')
    """
    return [a for a in alerts if a.get('metric') == metric]


def get_latest_alert(alerts: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """
    Get the most recent alert.
    
    Args:
        alerts: List of alert dictionaries
        
    Returns:
        dict or None: Most recent alert or None if no alerts
        
    Example:
        >>> latest = get_latest_alert(alerts)
    """
    if not alerts:
        return None
    
    sorted_alerts = _sort_alerts_by_timestamp(alerts)
    return sorted_alerts[0] if sorted_alerts else None
