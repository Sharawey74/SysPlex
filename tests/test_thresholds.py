"""Unit tests for server.thresholds — threshold evaluation."""

import json
import pytest

from server.thresholds import (
    DEFAULT_THRESHOLDS,
    evaluate,
    evaluate_and_record,
    load_thresholds,
)


def envelope(**groups):
    """Minimal well-formed metrics envelope with the given groups overridden."""
    base = {
        "timestamp": "2026-08-19T18:00:00Z",
        "platform": "linux",
        "system": {"os": "Ubuntu", "hostname": "test", "uptime_seconds": 1, "kernel": "6.6"},
        "cpu": {"usage_percent": 10.0, "status": "ok"},
        "memory": {"usage_percent": 40.0, "status": "ok"},
        "disk": [],
        "network": [],
        "temperature": {"cpu_celsius": 45, "status": "ok"},
        "gpu": {"status": "unavailable", "count": 0, "devices": []},
    }
    base.update(groups)
    return base


class TestNoBreach:
    def test_healthy_system_raises_nothing(self):
        assert evaluate(envelope()) == []

    def test_value_exactly_below_warning_is_quiet(self):
        assert evaluate(envelope(cpu={"usage_percent": 79.9, "status": "ok"})) == []


class TestLevels:
    def test_warning_at_the_boundary(self):
        alerts = evaluate(envelope(cpu={"usage_percent": 80.0, "status": "ok"}))
        assert len(alerts) == 1
        assert alerts[0]["level"] == "warning"
        assert alerts[0]["metric"] == "cpu"
        assert alerts[0]["threshold"] == 80.0

    def test_critical_at_the_boundary(self):
        alerts = evaluate(envelope(cpu={"usage_percent": 90.0, "status": "ok"}))
        assert alerts[0]["level"] == "critical"

    def test_critical_does_not_also_raise_warning(self):
        """A CPU at 96% is one critical alert, not a critical plus a warning."""
        alerts = evaluate(envelope(cpu={"usage_percent": 96.0, "status": "ok"}))
        cpu_alerts = [a for a in alerts if a["metric"] == "cpu"]
        assert len(cpu_alerts) == 1
        assert cpu_alerts[0]["level"] == "critical"

    def test_memory_and_temperature_evaluated_independently(self):
        alerts = evaluate(envelope(
            memory={"usage_percent": 97.0, "status": "ok"},
            temperature={"cpu_celsius": 95, "status": "ok"},
        ))
        by_metric = {a["metric"]: a["level"] for a in alerts}
        assert by_metric == {"memory": "critical", "temperature": "critical"}


class TestUnavailableReadings:
    """
    The regression this guards: an unavailable sensor reports a placeholder 0.
    Treating that as a measurement means a failing sensor looks healthy, and a
    CPU that stops reporting at 95 C silently stops alerting.
    """

    def test_unavailable_temperature_raises_nothing(self):
        alerts = evaluate(envelope(temperature={"cpu_celsius": 0, "status": "unavailable"}))
        assert alerts == []

    def test_restricted_status_raises_nothing(self):
        alerts = evaluate(envelope(cpu={"usage_percent": 99.0, "status": "restricted"}))
        assert alerts == []

    def test_missing_group_raises_nothing(self):
        payload = envelope()
        del payload["cpu"]
        assert evaluate(payload) == []

    def test_non_numeric_value_raises_nothing(self):
        assert evaluate(envelope(cpu={"usage_percent": "high", "status": "ok"})) == []

    def test_boolean_is_not_treated_as_a_number(self):
        assert evaluate(envelope(cpu={"usage_percent": True, "status": "ok"})) == []


class TestPerDevice:
    def test_each_mount_evaluated_separately(self):
        """A full /boot must not be hidden by a mostly empty /home."""
        alerts = evaluate(envelope(disk=[
            {"device": "/dev/sda1", "used_percent": 12.0},
            {"device": "/dev/sda2", "used_percent": 97.0},
        ]))
        assert len(alerts) == 1
        assert alerts[0]["level"] == "critical"
        assert "/dev/sda2" in alerts[0]["message"]

    def test_gpu_utilization_and_temperature_are_separate_alerts(self):
        alerts = evaluate(envelope(gpu={
            "status": "ok", "count": 1,
            "devices": [{"model": "RTX 4090", "utilization_percent": 99,
                         "temperature_celsius": 94}],
        }))
        assert {a["metric"] for a in alerts} == {"gpu", "gpu_temp"}
        assert all("RTX 4090" in a["message"] for a in alerts)

    def test_gpu_temperature_of_zero_is_ignored(self):
        alerts = evaluate(envelope(gpu={
            "status": "ok", "count": 1,
            "devices": [{"model": "GPU", "utilization_percent": 5, "temperature_celsius": 0}],
        }))
        assert alerts == []


class TestConfiguration:
    def test_defaults_cover_every_evaluated_metric(self):
        for metric in ("cpu", "memory", "disk", "temperature", "gpu", "gpu_temp"):
            assert metric in DEFAULT_THRESHOLDS
            assert DEFAULT_THRESHOLDS[metric]["warning"] < DEFAULT_THRESHOLDS[metric]["critical"]

    def test_environment_override(self, monkeypatch):
        monkeypatch.setenv("SYSPLEX_THRESHOLD_CPU_CRITICAL", "95")
        assert load_thresholds()["cpu"]["critical"] == 95.0

    def test_malformed_environment_value_falls_back(self, monkeypatch):
        """A typo in a deployment variable must not stop collection."""
        monkeypatch.setenv("SYSPLEX_THRESHOLD_CPU_CRITICAL", "ninety")
        assert load_thresholds()["cpu"]["critical"] == DEFAULT_THRESHOLDS["cpu"]["critical"]

    def test_explicit_override_wins(self):
        alerts = evaluate(envelope(cpu={"usage_percent": 50.0, "status": "ok"}),
                          thresholds={"cpu": {"warning": 40.0, "critical": 60.0}})
        assert alerts[0]["level"] == "warning"


class TestPersistence:
    def test_evaluate_and_record_writes_alerts(self, tmp_path):
        path = tmp_path / "alerts.json"
        raised = evaluate_and_record(
            envelope(cpu={"usage_percent": 99.0, "status": "ok"}),
            path=str(path),
        )
        assert len(raised) == 1

        stored = json.loads(path.read_text())["alerts"]
        assert len(stored) == 1
        assert stored[0]["level"] == "critical"
        assert stored[0]["metric"] == "cpu"
        assert stored[0]["threshold"] == 90.0

    def test_nothing_written_when_healthy(self, tmp_path):
        path = tmp_path / "alerts.json"
        assert evaluate_and_record(envelope(), path=str(path)) == []
        assert not path.exists() or json.loads(path.read_text())["alerts"] == []


class TestRobustness:
    @pytest.mark.parametrize("payload", [None, [], "", 0, {"cpu": None}, {"disk": None}])
    def test_malformed_input_does_not_raise(self, payload):
        """Collection must survive whatever an agent emits."""
        assert evaluate(payload) == []

    def test_real_fixture_evaluates(self):
        """The committed demo payloads must run through evaluation cleanly."""
        from pathlib import Path
        for name in ("linux-wsl.json", "windows.json"):
            fixture = Path(__file__).parent.parent / "fixtures" / "demo" / name
            if fixture.exists():
                assert isinstance(evaluate(json.loads(fixture.read_text())), list)
