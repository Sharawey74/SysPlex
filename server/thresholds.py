"""
Threshold evaluation.

Turns a metrics envelope into alerts. This is the piece that decides *when*
something is wrong; `alerts.py` only stores and queries the result.

Evaluation is pure -- `evaluate()` takes a metrics dict and returns a list of
alert dicts without touching the filesystem. Persisting them is a separate,
explicit step (`evaluate_and_record`), so the rules can be tested without I/O
and re-evaluated over historical samples if needed.

Thresholds are two-level. Crossing the warning bound raises `warning`; crossing
the critical bound raises `critical`. Only the highest level that applies is
raised for a given metric, so a CPU at 96% produces one critical alert rather
than a critical and a warning.
"""

import os
import logging
from typing import Any, Dict, List, Optional

# Importable both as `server.thresholds` (from the app / tests) and as a
# top-level module (when server/ is on sys.path, as in the container).
try:
    from alerts import add_alert, DEFAULT_ALERTS_PATH
except ImportError:  # pragma: no cover
    from server.alerts import add_alert, DEFAULT_ALERTS_PATH

logger = logging.getLogger(__name__)

# Defaults. Every bound is overridable by environment variable so an operator
# can tune them per machine without editing code -- a fanless mini PC and a
# workstation do not agree on what a hot CPU is.
DEFAULT_THRESHOLDS: Dict[str, Dict[str, float]] = {
    "cpu":         {"warning": 80.0, "critical": 90.0},   # usage percent
    "memory":      {"warning": 85.0, "critical": 95.0},   # usage percent
    "disk":        {"warning": 85.0, "critical": 95.0},   # used percent, per mount
    "temperature": {"warning": 75.0, "critical": 90.0},   # celsius, CPU package
    "gpu":         {"warning": 85.0, "critical": 95.0},   # utilization percent
    "gpu_temp":    {"warning": 80.0, "critical": 92.0},   # celsius, per device
}

_ENV_PREFIX = "SYSPLEX_THRESHOLD_"


def load_thresholds(overrides: Optional[Dict[str, Dict[str, float]]] = None) -> Dict[str, Dict[str, float]]:
    """
    Resolve the active thresholds.

    Precedence: explicit `overrides` argument, then environment
    (`SYSPLEX_THRESHOLD_CPU_CRITICAL=95`), then the defaults above.

    A malformed environment value is logged and ignored rather than raising --
    a typo in a deployment variable should not stop metric collection.
    """
    resolved = {metric: dict(bounds) for metric, bounds in DEFAULT_THRESHOLDS.items()}

    for metric, bounds in resolved.items():
        for level in bounds:
            raw = os.getenv(f"{_ENV_PREFIX}{metric.upper()}_{level.upper()}")
            if raw is None:
                continue
            try:
                bounds[level] = float(raw)
            except ValueError:
                logger.warning(
                    "Ignoring %s%s_%s=%r: not a number",
                    _ENV_PREFIX, metric.upper(), level.upper(), raw,
                )

    if overrides:
        for metric, bounds in overrides.items():
            resolved.setdefault(metric, {}).update(bounds)

    return resolved


def _level_for(value: float, bounds: Dict[str, float]) -> Optional[str]:
    """Highest breached level, or None. Critical wins over warning."""
    if value >= bounds.get("critical", float("inf")):
        return "critical"
    if value >= bounds.get("warning", float("inf")):
        return "warning"
    return None


def _alert(metric: str, level: str, message: str, value: float, threshold: float) -> Dict[str, Any]:
    return {
        "metric": metric,
        "level": level,
        "message": message,
        "value": round(float(value), 1),
        "threshold": threshold,
    }


def _reading(group: Dict[str, Any], key: str) -> Optional[float]:
    """
    Read a numeric field, but only when the group claims a usable reading.

    A group reporting `status: "unavailable"` carries placeholder zeros. Treating
    those as measurements would mean a CPU at 0 degrees looks perfectly healthy,
    and worse, a sensor that fails at 95 degrees would silently stop alerting.
    Absent data raises nothing; it is not the same as a good reading.
    """
    if not isinstance(group, dict):
        return None
    if group.get("status") in ("unavailable", "restricted", "error"):
        return None
    value = group.get(key)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return None
    return float(value)


def evaluate(metrics: Dict[str, Any],
             thresholds: Optional[Dict[str, Dict[str, float]]] = None) -> List[Dict[str, Any]]:
    """
    Evaluate a metrics envelope against thresholds.

    Args:
        metrics: a metrics envelope as emitted by any agent
        thresholds: optional override, otherwise resolved from env + defaults

    Returns:
        A list of alert dicts, empty when nothing is breached. Pure -- no I/O.
    """
    if not isinstance(metrics, dict):
        return []

    bounds = thresholds or load_thresholds()
    alerts: List[Dict[str, Any]] = []

    def check(metric_key: str, value: Optional[float], message: str) -> None:
        if value is None:
            return
        limits = bounds.get(metric_key)
        if not limits:
            return
        level = _level_for(value, limits)
        if level:
            alerts.append(_alert(metric_key, level, message.format(value=value), value, limits[level]))

    # CPU
    check("cpu", _reading(metrics.get("cpu", {}), "usage_percent"),
          "CPU usage at {value:.1f}%")

    # Memory
    check("memory", _reading(metrics.get("memory", {}), "usage_percent"),
          "Memory usage at {value:.1f}%")

    # CPU temperature
    check("temperature", _reading(metrics.get("temperature", {}), "cpu_celsius"),
          "CPU temperature at {value:.0f} C")

    # Disk -- per mount, so a full /boot is not hidden by a mostly empty /home
    for entry in metrics.get("disk", []) or []:
        if not isinstance(entry, dict):
            continue
        used = entry.get("used_percent")
        if not isinstance(used, (int, float)) or isinstance(used, bool):
            continue
        limits = bounds.get("disk", {})
        level = _level_for(float(used), limits)
        if level:
            device = entry.get("device", "unknown")
            alerts.append(_alert(
                "disk", level,
                f"Disk {device} at {float(used):.1f}% used",
                float(used), limits[level],
            ))

    # GPU -- per device, utilization and temperature separately
    gpu = metrics.get("gpu", {})
    if isinstance(gpu, dict) and gpu.get("status") not in ("unavailable", "restricted", "error"):
        for device in gpu.get("devices", []) or []:
            if not isinstance(device, dict):
                continue
            name = device.get("model") or device.get("vendor") or "GPU"

            util = device.get("utilization_percent")
            if isinstance(util, (int, float)) and not isinstance(util, bool):
                limits = bounds.get("gpu", {})
                level = _level_for(float(util), limits)
                if level:
                    alerts.append(_alert("gpu", level, f"{name} utilization at {float(util):.0f}%",
                                         float(util), limits[level]))

            temp = device.get("temperature_celsius")
            if isinstance(temp, (int, float)) and not isinstance(temp, bool) and temp > 0:
                limits = bounds.get("gpu_temp", {})
                level = _level_for(float(temp), limits)
                if level:
                    alerts.append(_alert("gpu_temp", level, f"{name} temperature at {float(temp):.0f} C",
                                         float(temp), limits[level]))

    return alerts


def evaluate_and_record(metrics: Dict[str, Any],
                        thresholds: Optional[Dict[str, Dict[str, float]]] = None,
                        path: str = DEFAULT_ALERTS_PATH) -> List[Dict[str, Any]]:
    """
    Evaluate and persist any resulting alerts.

    Returns the alerts that were raised so a caller can log or surface them
    without re-reading the file.
    """
    raised = evaluate(metrics, thresholds)

    for alert in raised:
        add_alert(
            metric=alert["metric"],
            level=alert["level"],
            message=alert["message"],
            value=alert["value"],
            threshold=alert["threshold"],
            path=path,
        )

    if raised:
        logger.info("Raised %d alert(s): %s", len(raised),
                    ", ".join(f"{a['level']}/{a['metric']}" for a in raised))

    return raised
