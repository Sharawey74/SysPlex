package main

import (
	"encoding/json"
	"runtime"
	"testing"
)

// validStatuses are the only values any *Info.Status field may hold.
var validStatuses = map[string]bool{
	"ok":          true,
	"unavailable": true,
	"restricted":  true,
}

// TestFanInfoShape checks that fan collection always returns a well-formed
// value. It cannot assert on readings: CI runners have no fans, and the
// developer machine is Windows. What it can assert is that the shape never
// degrades, which is what the Bash monitor got wrong.
func TestFanInfoShape(t *testing.T) {
	info := collectFanInfo()

	if !validStatuses[info.Status] {
		t.Errorf("status = %q, want one of ok/unavailable/restricted", info.Status)
	}
	if info.Devices == nil {
		t.Error("Devices is nil; must be an empty slice so it marshals to [] not null")
	}
	if info.Count != len(info.Devices) {
		t.Errorf("Count = %d but len(Devices) = %d", info.Count, len(info.Devices))
	}
	if info.Status == "ok" && len(info.Devices) == 0 {
		t.Error(`status "ok" with no devices: "ok" must mean a reading was taken`)
	}
	if info.Status != "ok" && len(info.Devices) > 0 {
		t.Errorf("status %q with %d devices: devices imply ok", info.Status, len(info.Devices))
	}
	for i, d := range info.Devices {
		if d.RPM <= 0 {
			t.Errorf("device %d (%s): RPM = %d; a stopped or unpopulated header must not be reported", i, d.Label, d.RPM)
		}
		if d.Label == "" {
			t.Errorf("device %d: empty label", i)
		}
	}
	if runtime.GOOS != "linux" && info.Status != "unavailable" {
		t.Errorf("on %s fan collection should report unavailable, got %q", runtime.GOOS, info.Status)
	}
}

// TestSmartInfoShape mirrors TestFanInfoShape. SMART almost always needs
// elevation, so "restricted" is an expected outcome here, not a failure.
func TestSmartInfoShape(t *testing.T) {
	info := collectSmartInfo()

	if !validStatuses[info.Status] {
		t.Errorf("status = %q, want one of ok/unavailable/restricted", info.Status)
	}
	if info.Devices == nil {
		t.Error("Devices is nil; must be an empty slice so it marshals to [] not null")
	}
	if info.Count != len(info.Devices) {
		t.Errorf("Count = %d but len(Devices) = %d", info.Count, len(info.Devices))
	}
	if info.Status == "ok" && len(info.Devices) == 0 {
		t.Error(`status "ok" with no devices`)
	}
	for i, d := range info.Devices {
		if d.Device == "" {
			t.Errorf("device %d: empty device path", i)
		}
		switch d.Health {
		case "PASSED", "FAILED", "UNKNOWN":
		default:
			t.Errorf("device %d (%s): health = %q, want PASSED/FAILED/UNKNOWN", i, d.Device, d.Health)
		}
		if d.PowerOnHours < 0 {
			t.Errorf("device %d: negative power-on hours %d", i, d.PowerOnHours)
		}
	}
}

// TestEnvelopeIncludesFansAndSmart guards the reason this code exists: the Go
// agent became the only agent, so the envelope must still carry the two fields
// that were previously only produced by the Bash monitors.
func TestEnvelopeIncludesFansAndSmart(t *testing.T) {
	metrics, err := collectMetrics()
	if err != nil {
		t.Fatalf("collectMetrics: %v", err)
	}

	raw, err := json.Marshal(metrics)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var envelope map[string]json.RawMessage
	if err := json.Unmarshal(raw, &envelope); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	for _, key := range []string{"fans", "smart"} {
		body, ok := envelope[key]
		if !ok {
			t.Fatalf("envelope is missing %q", key)
		}
		// Must be an object, never a bare array. The Bash monitors emitted an
		// array on success and an object otherwise; that polymorphism is the
		// specific defect this replacement removes.
		if len(body) == 0 || body[0] != '{' {
			t.Errorf("%q must marshal as an object, got: %s", key, body)
		}
	}
}
