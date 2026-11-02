"""
Team App Trace Importer & Hardware Sensor Validator
Territory Runner ML Anti-Cheat Subsystem

Validates real-world GPS + Accelerometer telemetry traces exported from the Territory
Runner mobile application (via Export ML Debug Trace). Enforces strict data hygiene:
1. Schema & type verification (coordinates, timestamps, speeds, accuracy).
2. Monotonicity & physical kinematic plausibility (no teleportation, positive delta-t).
3. Synchronized motion window verification (cadence_spm, motion_energy, cadence_confidence).
4. Minimum sample threshold gate: The accelerometer cadence model CANNOT be enabled
   unless at least MIN_VALID_TRACES (default: 30) across at least MIN_DISTINCT_USERS (default: 3)
   valid real-world traces are present in ml/data/app_traces/.

Strict Integrity Guarantee:
- DO NOT FABRICATE TRACES. If real traces are missing, the cadence model stays disabled.
"""

import argparse
import json
import math
import os
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

DEGREE_LAT_METERS = 111139.0

# Stated Minimum Thresholds (aligned with ml/data/collect_app_traces.md target of 32+ sessions across 3 members)
MIN_VALID_TRACES_THRESHOLD = 30
MIN_DISTINCT_USERS_THRESHOLD = 3
MIN_POINTS_PER_TRACE = 30
MIN_DURATION_SECONDS = 180.0  # At least 3 minutes of continuous tracking

VALID_MODALITIES = {
    "walk": "legit_walk_run",
    "run": "legit_walk_run",
    "cycle": "legit_cycle",
    "bike": "legit_cycle",
    "bus": "vehicle",
    "auto": "vehicle",
    "car": "vehicle",
    "taxi": "vehicle",
    "subway": "vehicle",
    "train": "vehicle",
    "airplane": "vehicle",
    "boat": "vehicle",
}

VALID_PLACEMENTS = {
    "pocket": "pocket",
    "hand": "hand",
    "bag": "bag",
    "backpack": "bag",
    "waistpack": "pocket",
    "armband": "hand",
    "unknown": "unknown",
}


@dataclass
class ValidationResult:
    file_name: str
    is_valid: bool
    session_id: str = ""
    user_id: str = ""
    transport_mode: str = ""
    mapped_mode: str = ""
    phone_placement: str = "unknown"
    points_count: int = 0
    motion_windows_count: int = 0
    duration_seconds: float = 0.0
    has_valid_motion: bool = False
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


@dataclass
class AuditStatus:
    total_files_examined: int = 0
    valid_traces_count: int = 0
    rejected_traces_count: int = 0
    distinct_users: List[str] = field(default_factory=list)
    user_counts: Dict[str, int] = field(default_factory=dict)
    modality_counts: Dict[str, int] = field(default_factory=dict)
    placement_counts: Dict[str, int] = field(default_factory=dict)
    rejected_traces_details: List[Dict[str, Any]] = field(default_factory=list)
    traces_with_valid_motion: int = 0
    min_threshold_met: bool = False
    cadence_model_enabled: bool = False
    min_required_traces: int = MIN_VALID_TRACES_THRESHOLD
    min_required_users: int = MIN_DISTINCT_USERS_THRESHOLD
    status_message: str = ""
    timestamp_utc: str = ""


def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Computes great-circle distance in meters between two coordinates."""
    r = 6371000.0  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c


def validate_single_trace(file_path: str) -> Tuple[ValidationResult, List[dict], List[dict]]:
    """
    Validates a single team app trace JSON file against physical integrity rules.
    Returns (ValidationResult, extracted_points, extracted_motion_windows).
    """
    fname = os.path.basename(file_path)
    res = ValidationResult(file_name=fname, is_valid=False)

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        res.errors.append(f"JSON parse error: {e}")
        return res, [], []

    # 1. Required Top-Level Schema Checks
    required_keys = ["session_id", "user_id", "transport_mode", "points"]
    for k in required_keys:
        if k not in data:
            res.errors.append(f"Missing required top-level key: '{k}'")

    if res.errors:
        return res, [], []

    session_id = str(data["session_id"]).strip()
    user_id = str(data["user_id"]).strip()
    raw_mode = str(data["transport_mode"]).strip().lower()

    if not session_id:
        res.errors.append("Empty 'session_id'")
    if not user_id:
        res.errors.append("Empty 'user_id'")
    if raw_mode not in VALID_MODALITIES:
        res.errors.append(f"Invalid transport_mode: '{raw_mode}'. Must be one of: {list(VALID_MODALITIES.keys())}")

    # Phone Placement validation
    raw_placement = str(data.get("phone_placement", "unknown")).strip().lower()
    if raw_placement not in VALID_PLACEMENTS:
        res.errors.append(
            f"Invalid or suspicious phone_placement: '{raw_placement}'. "
            f"Must be one of: {sorted(list(VALID_PLACEMENTS.keys()))}"
        )
    elif "phone_placement" not in data:
        res.warnings.append("Missing 'phone_placement'; defaulted to 'unknown'")

    res.session_id = session_id
    res.user_id = user_id
    res.transport_mode = raw_mode
    res.mapped_mode = VALID_MODALITIES.get(raw_mode, "unknown")
    res.phone_placement = VALID_PLACEMENTS.get(raw_placement, "unknown")

    raw_points = data.get("points", [])
    if not isinstance(raw_points, list):
        res.errors.append("'points' must be a JSON array")
        return res, [], []

    if len(raw_points) < MIN_POINTS_PER_TRACE:
        res.errors.append(f"Trace too short: {len(raw_points)} points (minimum required: {MIN_POINTS_PER_TRACE})")
        return res, [], []

    # 2. GPS Breadcrumbs Kinematic & Monotonicity Validation
    extracted_points = []
    prev_time = None
    prev_lat = None
    prev_lon = None

    for i, pt in enumerate(raw_points):
        if not isinstance(pt, dict):
            res.errors.append(f"Point {i} is not a valid JSON object")
            return res, [], []

        # Parse coordinates
        try:
            lat = float(pt["latitude"])
            lon = float(pt["longitude"])
        except (KeyError, ValueError, TypeError):
            res.errors.append(f"Point {i}: Invalid or missing latitude/longitude")
            return res, [], []

        if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
            res.errors.append(f"Point {i}: Coordinates out of physical bounds ({lat}, {lon})")
            return res, [], []

        if lat == 0.0 and lon == 0.0:
            res.errors.append(f"Point {i}: Null Island (0.0, 0.0) coordinates are suspicious/invalid")
            return res, [], []

        # Parse timestamp
        t_sec = None
        if "timestamp_ms" in pt:
            try:
                t_sec = float(pt["timestamp_ms"]) / 1000.0
            except (ValueError, TypeError):
                pass
        elif "timestamp" in pt:
            try:
                t_sec = float(pt["timestamp"])
            except (ValueError, TypeError):
                pass

        if t_sec is None or t_sec <= 0:
            res.errors.append(f"Point {i}: Invalid timestamp ({pt.get('timestamp_ms') or pt.get('timestamp')})")
            return res, [], []

        # Temporal monotonicity check
        if prev_time is not None:
            dt = t_sec - prev_time
            if dt < 0:
                res.errors.append(f"Point {i}: Non-monotonic timestamp (dt = {dt:.3f}s)")
                return res, [], []
            if dt == 0:
                res.warnings.append(f"Point {i}: Duplicate timestamp {t_sec}")
            elif dt > 120.0:
                res.warnings.append(f"Point {i}: Large time gap between fixes ({dt:.1f}s)")

            # Kinematic velocity sanity check
            dist = haversine_distance_meters(prev_lat, prev_lon, lat, lon)
            if dt > 0:
                instant_v = dist / dt
                if instant_v > 120.0:  # > 432 km/h (impossible terrestrial movement without teleportation)
                    res.errors.append(f"Point {i}: Impossible instant velocity ({instant_v * 3.6:.1f} km/h over {dist:.1f}m in {dt:.2f}s)")
                    return res, [], []

        alt = float(pt.get("altitude", 0.0)) if pt.get("altitude") is not None else 0.0
        acc = float(pt.get("accuracy", 5.0)) if pt.get("accuracy") is not None else 5.0
        if acc <= 0 or acc > 200.0:
            res.warnings.append(f"Point {i}: Suspicious accuracy estimate ({acc:.1f}m)")

        speed_mps = float(pt.get("speed_mps", 0.0)) if pt.get("speed_mps") is not None else 0.0

        extracted_points.append({
            "user_id": user_id,
            "session_id": session_id,
            "timestamp": t_sec,
            "latitude": lat,
            "longitude": lon,
            "altitude_m": alt,
            "accuracy_m": acc,
            "reported_speed": speed_mps,
            "raw_mode": raw_mode,
            "transport_mode": res.mapped_mode,
            "phone_placement": res.phone_placement,
            "is_anomaly": 1 if res.mapped_mode == "vehicle" else 0,
        })

        prev_time = t_sec
        prev_lat = lat
        prev_lon = lon

    # Duration check
    total_duration = extracted_points[-1]["timestamp"] - extracted_points[0]["timestamp"]
    res.duration_seconds = total_duration
    res.points_count = len(extracted_points)

    if total_duration < MIN_DURATION_SECONDS:
        res.warnings.append(f"Session duration ({total_duration:.1f}s) is shorter than recommended minimum ({MIN_DURATION_SECONDS}s)")

    # 3. Motion Windows Validation (Accelerometer Telemetry)
    extracted_motion_windows = []
    raw_motion = data.get("motion_windows", [])
    if isinstance(raw_motion, list) and len(raw_motion) > 0:
        valid_windows = 0
        for j, mw in enumerate(raw_motion):
            if not isinstance(mw, dict):
                continue
            cadence = mw.get("cadence_spm")
            energy = mw.get("motion_energy")
            conf = mw.get("cadence_confidence")
            dur = mw.get("duration_sec", 10.0)

            # Plausibility checks
            if cadence is None or energy is None:
                continue
            try:
                c_val = float(cadence)
                e_val = float(energy)
                conf_val = float(conf) if conf is not None else 0.5
                dur_val = float(dur)
            except (ValueError, TypeError):
                continue

            # Physical ranges
            if not (0.0 <= c_val <= 300.0):
                res.warnings.append(f"Motion window {j}: Cadence out of range ({c_val} SPM)")
                continue
            if not (0.0 <= e_val <= 50.0):
                res.warnings.append(f"Motion window {j}: Motion energy out of range ({e_val})")
                continue
            if not (0.0 <= conf_val <= 1.0):
                conf_val = max(0.0, min(1.0, conf_val))

            extracted_motion_windows.append({
                "session_id": session_id,
                "window_idx": j,
                "duration_sec": dur_val,
                "cadence_spm": c_val,
                "motion_energy": e_val,
                "cadence_confidence": conf_val,
            })
            valid_windows += 1

        res.motion_windows_count = valid_windows
        res.has_valid_motion = valid_windows > 0
    else:
        res.has_valid_motion = False

    res.is_valid = len(res.errors) == 0
    return res, extracted_points, extracted_motion_windows


def import_all_team_traces(
    app_traces_dir: str = "ml/data/app_traces",
    min_traces_threshold: int = MIN_VALID_TRACES_THRESHOLD,
    min_users_threshold: int = MIN_DISTINCT_USERS_THRESHOLD,
) -> Tuple[List[dict], List[dict], AuditStatus]:
    """
    Scans app_traces_dir, validates every file, and evaluates the threshold status.
    Returns (all_validated_points, all_validated_motion_windows, AuditStatus).
    """
    audit = AuditStatus(
        min_required_traces=min_traces_threshold,
        min_required_users=min_users_threshold,
        timestamp_utc=datetime.now(timezone.utc).isoformat(),
    )

    if not os.path.exists(app_traces_dir):
        audit.status_message = f"App traces directory '{app_traces_dir}' does not exist on disk."
        audit.cadence_model_enabled = False
        audit.min_threshold_met = False
        return [], [], audit

    fnames = [
        f for f in sorted(os.listdir(app_traces_dir))
        if f.endswith(".json") and not f.startswith("manifest") and not f.startswith("status")
    ]
    audit.total_files_examined = len(fnames)

    all_points = []
    all_motion = []
    seen_users = set()
    seen_sessions = set()
    user_counts = {}
    modality_counts = {}
    placement_counts = {}

    for fname in fnames:
        fpath = os.path.join(app_traces_dir, fname)
        res, pts, motion = validate_single_trace(fpath)

        if res.is_valid:
            if res.session_id in seen_sessions:
                res.is_valid = False
                res.errors.append(f"Duplicate session_id '{res.session_id}' already seen in batch")
                audit.rejected_traces_count += 1
                audit.rejected_traces_details.append({
                    "file_name": fname,
                    "session_id": res.session_id,
                    "errors": res.errors,
                })
                print(f"[-] Rejected suspicious duplicate app trace '{fname}': {', '.join(res.errors)}")
                continue

            seen_sessions.add(res.session_id)
            audit.valid_traces_count += 1
            seen_users.add(res.user_id)
            user_counts[res.user_id] = user_counts.get(res.user_id, 0) + 1
            modality_counts[res.transport_mode] = modality_counts.get(res.transport_mode, 0) + 1
            placement_counts[res.phone_placement] = placement_counts.get(res.phone_placement, 0) + 1
            if res.has_valid_motion:
                audit.traces_with_valid_motion += 1
            all_points.extend(pts)
            all_motion.extend(motion)
        else:
            audit.rejected_traces_count += 1
            audit.rejected_traces_details.append({
                "file_name": fname,
                "session_id": res.session_id,
                "errors": res.errors,
            })
            print(f"[-] Rejected invalid app trace '{fname}': {', '.join(res.errors)}")

    audit.distinct_users = sorted(list(seen_users))
    audit.user_counts = user_counts
    audit.modality_counts = modality_counts
    audit.placement_counts = placement_counts

    # Evaluate minimum threshold requirement
    has_min_traces = audit.valid_traces_count >= min_traces_threshold
    has_min_users = len(audit.distinct_users) >= min_users_threshold

    if has_min_traces and has_min_users and audit.traces_with_valid_motion >= min_traces_threshold:
        audit.min_threshold_met = True
        audit.cadence_model_enabled = True
        audit.status_message = (
            f"VALIDATED: {audit.valid_traces_count} real traces across {len(audit.distinct_users)} users. "
            f"Cadence model training is ENABLED."
        )
    else:
        audit.min_threshold_met = False
        audit.cadence_model_enabled = False
        missing_reasons = []
        if not has_min_traces:
            missing_reasons.append(f"traces {audit.valid_traces_count}/{min_traces_threshold}")
        if not has_min_users:
            missing_reasons.append(f"users {len(audit.distinct_users)}/{min_users_threshold}")
        if audit.traces_with_valid_motion < min_traces_threshold:
            missing_reasons.append(f"traces with motion {audit.traces_with_valid_motion}/{min_traces_threshold}")

        audit.status_message = (
            f"THRESHOLD UNMET: {', '.join(missing_reasons)}. "
            f"Cadence model MUST stay DISABLED. Anti-cheat pipeline evaluates GPS-only."
        )

    return all_points, all_motion, audit


def write_status_manifest(audit: AuditStatus, manifest_path: str = "ml/data/app_traces_manifest.json") -> None:
    """Writes JSON manifest describing validated app traces status."""
    os.makedirs(os.path.dirname(manifest_path) if os.path.dirname(manifest_path) else ".", exist_ok=True)
    payload = asdict(audit)
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    print(f"[+] Wrote trace audit manifest to: {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description="Validate & import real-world team app traces.")
    parser.add_argument("--dir", default="ml/data/app_traces", help="Directory containing app trace JSONs")
    parser.add_argument("--manifest", default="ml/data/app_traces_manifest.json", help="Path to output status manifest")
    parser.add_argument("--min-traces", type=int, default=MIN_VALID_TRACES_THRESHOLD, help="Minimum required valid traces")
    parser.add_argument("--min-users", type=int, default=MIN_DISTINCT_USERS_THRESHOLD, help="Minimum required distinct users")
    args = parser.parse_args()

    print("=" * 70)
    print("  TEAM APP TRACES VALIDATOR & INGESTION AUDITOR")
    print("=" * 70)

    pts, motion, audit = import_all_team_traces(
        app_traces_dir=args.dir,
        min_traces_threshold=args.min_traces,
        min_users_threshold=args.min_users,
    )

    print(f"[*] Files Examined:            {audit.total_files_examined}")
    print(f"[*] Valid Traces:              {audit.valid_traces_count} (Required: {audit.min_required_traces})")
    print(f"[*] Rejected Traces:           {audit.rejected_traces_count}")
    print(f"[*] Distinct Users:            {len(audit.distinct_users)} {audit.distinct_users} (Required: {audit.min_required_users})")
    print(f"[*] Counts Per User:           {audit.user_counts}")
    print(f"[*] Counts Per Activity:       {audit.modality_counts}")
    print(f"[*] Counts Per Phone Placement:{audit.placement_counts}")
    print(f"[*] Traces with Valid Motion:  {audit.traces_with_valid_motion}")
    print(f"[*] Cadence Model Active:      {audit.cadence_model_enabled}")
    print(f"[*] Status:                    {audit.status_message}")
    print("=" * 70)

    write_status_manifest(audit, args.manifest)


if __name__ == "__main__":
    main()
