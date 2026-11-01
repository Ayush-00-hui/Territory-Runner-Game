"""
Unit Tests for Team App Trace Importer & Hardware Sensor Validator
Territory Runner ML Anti-Cheat Subsystem

Tests:
1. Rejection of malformed JSON and missing schema keys.
2. Rejection of invalid coordinates, non-monotonic timestamps, and teleport jumps.
3. Validation of motion windows (cadence, energy, confidence).
4. Strict threshold enforcement: cadence model disabled when traces < 30 or users < 3.
5. Verification that ml/data/app_traces/ has 0 fabricated traces.
"""

import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

repo_root = Path(__file__).resolve().parents[2]
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from ml.data.import_app_traces import (
    MIN_POINTS_PER_TRACE,
    MIN_VALID_TRACES_THRESHOLD,
    MIN_DISTINCT_USERS_THRESHOLD,
    AuditStatus,
    haversine_distance_meters,
    import_all_team_traces,
    validate_single_trace,
    write_status_manifest,
)


class TestAppTraceImporter(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="test_app_traces_")

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def _create_mock_trace_file(
        self,
        fname: str,
        session_id: str = "sess_001",
        user_id: str = "user_a",
        transport_mode: str = "run",
        num_points: int = 35,
        start_lat: float = 28.545,
        start_lon: float = 77.192,
        dt: float = 1.0,
        dx: float = 0.00003,  # ~3 m/s jogging
        has_motion: bool = True,
        cadence_spm: float = 165.0,
        motion_energy: float = 1.4,
        confidence: float = 0.9,
    ) -> str:
        pts = []
        base_t = 1700000000.0
        for i in range(num_points):
            pts.append({
                "latitude": start_lat + (i * dx),
                "longitude": start_lon + (i * dx),
                "timestamp_ms": int((base_t + (i * dt)) * 1000),
                "altitude": 200.0,
                "accuracy": 4.5,
                "speed_mps": 3.0,
            })

        payload = {
            "version": "1.0",
            "session_id": session_id,
            "user_id": user_id,
            "transport_mode": transport_mode,
            "recorded_at": "2026-11-01T10:00:00Z",
            "duration_seconds": int(num_points * dt),
            "distance_meters": 100.0,
            "points": pts,
        }

        if has_motion:
            payload["motion_windows"] = [
                {
                    "start_time_iso": "2026-11-01T10:00:00Z",
                    "duration_sec": 10.0,
                    "cadence_spm": cadence_spm,
                    "motion_energy": motion_energy,
                    "cadence_confidence": confidence,
                }
            ]

        fpath = os.path.join(self.test_dir, fname)
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        return fpath

    def test_empty_directory_disables_cadence_model(self):
        pts, motion, audit = import_all_team_traces(self.test_dir)
        self.assertEqual(len(pts), 0)
        self.assertEqual(len(motion), 0)
        self.assertEqual(audit.valid_traces_count, 0)
        self.assertFalse(audit.cadence_model_enabled)
        self.assertFalse(audit.min_threshold_met)
        self.assertIn("THRESHOLD UNMET", audit.status_message)

    def test_missing_schema_keys_rejected(self):
        fpath = os.path.join(self.test_dir, "bad_schema.json")
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump({"session_id": "test"}, f)

        res, pts, motion = validate_single_trace(fpath)
        self.assertFalse(res.is_valid)
        self.assertTrue(any("Missing required" in e for e in res.errors))

    def test_trace_below_minimum_points_rejected(self):
        fpath = self._create_mock_trace_file("short_trace.json", num_points=10)
        res, pts, motion = validate_single_trace(fpath)
        self.assertFalse(res.is_valid)
        self.assertTrue(any("Trace too short" in e for e in res.errors))

    def test_invalid_transport_mode_rejected(self):
        fpath = self._create_mock_trace_file("bad_mode.json", transport_mode="rocket_ship")
        res, pts, motion = validate_single_trace(fpath)
        self.assertFalse(res.is_valid)
        self.assertTrue(any("Invalid transport_mode" in e for e in res.errors))

    def test_non_monotonic_timestamps_rejected(self):
        fpath = self._create_mock_trace_file("time_travel.json")
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Invert timestamp on 10th point
        data["points"][10]["timestamp_ms"] = data["points"][9]["timestamp_ms"] - 5000
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(data, f)

        res, pts, motion = validate_single_trace(fpath)
        self.assertFalse(res.is_valid)
        self.assertTrue(any("Non-monotonic timestamp" in e for e in res.errors))

    def test_impossible_instant_teleport_rejected(self):
        fpath = self._create_mock_trace_file("teleport.json")
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Teleport point 15 by 2 degrees (~222 km in 1 second)
        data["points"][15]["latitude"] += 2.0
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(data, f)

        res, pts, motion = validate_single_trace(fpath)
        self.assertFalse(res.is_valid)
        self.assertTrue(any("Impossible instant velocity" in e for e in res.errors))

    def test_valid_trace_accepted_with_motion(self):
        fpath = self._create_mock_trace_file("valid_run.json")
        res, pts, motion = validate_single_trace(fpath)
        self.assertTrue(res.is_valid)
        self.assertEqual(res.transport_mode, "run")
        self.assertEqual(res.mapped_mode, "legit_walk_run")
        self.assertEqual(len(pts), 35)
        self.assertEqual(len(motion), 1)
        self.assertEqual(motion[0]["cadence_spm"], 165.0)

    def test_threshold_gate_below_minimum_keeps_cadence_disabled(self):
        # Create 5 valid traces across 2 users (< 30 traces, < 3 users)
        for i in range(3):
            self._create_mock_trace_file(f"trace_u1_{i}.json", session_id=f"s_1_{i}", user_id="user_1")
        for i in range(2):
            self._create_mock_trace_file(f"trace_u2_{i}.json", session_id=f"s_2_{i}", user_id="user_2")

        pts, motion, audit = import_all_team_traces(self.test_dir)
        self.assertEqual(audit.valid_traces_count, 5)
        self.assertEqual(len(audit.distinct_users), 2)
        self.assertFalse(audit.cadence_model_enabled)
        self.assertFalse(audit.min_threshold_met)
        self.assertIn("THRESHOLD UNMET", audit.status_message)

    def test_threshold_gate_satisfied_enables_cadence(self):
        # Create 30 valid traces across 3 users (10 each)
        for u_idx, uid in enumerate(["user_alpha", "user_beta", "user_gamma"]):
            for i in range(10):
                self._create_mock_trace_file(
                    f"trace_{uid}_{i}.json",
                    session_id=f"sess_{uid}_{i}",
                    user_id=uid,
                    transport_mode="run" if i % 2 == 0 else "bus",
                )

        pts, motion, audit = import_all_team_traces(self.test_dir)
        self.assertEqual(audit.valid_traces_count, 30)
        self.assertEqual(len(audit.distinct_users), 3)
        self.assertTrue(audit.cadence_model_enabled)
        self.assertTrue(audit.min_threshold_met)
        self.assertIn("VALIDATED", audit.status_message)

    def test_real_repo_app_traces_dir_has_zero_fabricated_traces(self):
        repo_traces_dir = "ml/data/app_traces"
        pts, motion, audit = import_all_team_traces(repo_traces_dir)
        self.assertEqual(audit.valid_traces_count, 0, "No traces should be fabricated in ml/data/app_traces/")
        self.assertFalse(audit.cadence_model_enabled)


if __name__ == "__main__":
    unittest.main()

