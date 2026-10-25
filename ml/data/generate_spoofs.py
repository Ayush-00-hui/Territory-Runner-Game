"""
Adversarial GPS Spoofing & Cheat Augmentation Generator
Territory Runner ML Anti-Cheat Engine

Generates adversarial cheat traces ONLY as a separate, strictly held-out test set:
1. Sparse sampling (infrequent breadcrumbs where median dt > 5s).
2. Speed-field spoofing (motorized displacement with forged client speed telemetry).
3. Timestamp stretching / warping (diluted time or sudden teleport jumps).
4. Replayed legitimate traces with shifted geographic offsets and stitched segments.

CRITICAL: Output is written to ml/data/adversarial_test_set.parquet and is NEVER
mixed into the training or validation sets.
"""

import argparse
import copy
import math
import os
import random
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd

# Deterministic seed for scientific reproducibility
RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

DEGREE_LAT_METERS = 111139.0


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in meters between two lat/lon coordinates."""
    r = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    return 2.0 * r * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))


def _meters_to_lat_lon(d_lat_m: float, d_lon_m: float, ref_lat: float) -> Tuple[float, float]:
    d_lat = d_lat_m / DEGREE_LAT_METERS
    d_lon = d_lon_m / (DEGREE_LAT_METERS * math.cos(math.radians(ref_lat)))
    return d_lat, d_lon


def generate_sparse_sampling_cheats(n_sessions: int = 25, points_per_session: int = 50) -> List[dict]:
    """Generates vehicle movement disguised with sparse sampling (median dt > 5s, up to 15-30s gaps)."""
    points = []
    for s_idx in range(n_sessions):
        session_id = f"adv_sparse_{s_idx:03d}"
        lat, lon = 28.5450 + s_idx * 0.005, 77.1920 + s_idx * 0.005
        t = 1792950000.0 + s_idx * 10000
        heading = random.uniform(0.0, 360.0)
        speed_kmh = random.uniform(45.0, 75.0)  # Vehicle speed

        for i in range(points_per_session):
            dt = random.uniform(8.0, 20.0)  # Sparse sampling interval > 5s
            t += dt
            heading = (heading + random.gauss(0.0, 4.0)) % 360.0
            dist_m = (speed_kmh / 3.6) * dt
            d_lat_m = dist_m * math.cos(math.radians(heading))
            d_lon_m = dist_m * math.sin(math.radians(heading))
            d_lat, d_lon = _meters_to_lat_lon(d_lat_m, d_lon_m, lat)
            lat += d_lat
            lon += d_lon

            points.append({
                "user_id": f"adv_user_{s_idx % 5:02d}",
                "session_id": session_id,
                "timestamp": t,
                "latitude": lat,
                "longitude": lon,
                "altitude_m": 210.0 + random.gauss(0.0, 1.0),
                "accuracy_m": random.uniform(3.0, 8.0),
                "reported_speed": (speed_kmh / 3.6),
                "attack_type": "sparse_sampling",
                "transport_mode": "vehicle",
                "is_anomaly": 1,
            })
    return points


def generate_speed_spoofing_cheats(n_sessions: int = 25, points_per_session: int = 50) -> List[dict]:
    """Generates high-speed vehicle movement where client forged reported_speed to running pace (2.5 m/s)."""
    points = []
    for s_idx in range(n_sessions):
        session_id = f"adv_speed_spoof_{s_idx:03d}"
        lat, lon = 28.5500 + s_idx * 0.005, 77.1950 + s_idx * 0.005
        t = 1792950000.0 + s_idx * 10000
        heading = random.uniform(0.0, 360.0)
        actual_speed_kmh = random.uniform(50.0, 85.0)  # Real vehicle speed
        forged_reported_speed_ms = random.uniform(2.2, 3.2)  # Forged to 8-11 km/h running speed

        for i in range(points_per_session):
            dt = 1.0  # 1 Hz sampling
            t += dt
            heading = (heading + random.gauss(0.0, 3.0)) % 360.0
            dist_m = (actual_speed_kmh / 3.6) * dt
            d_lat_m = dist_m * math.cos(math.radians(heading))
            d_lon_m = dist_m * math.sin(math.radians(heading))
            d_lat, d_lon = _meters_to_lat_lon(d_lat_m, d_lon_m, lat)
            lat += d_lat
            lon += d_lon

            points.append({
                "user_id": f"adv_user_{s_idx % 5:02d}",
                "session_id": session_id,
                "timestamp": t,
                "latitude": lat,
                "longitude": lon,
                "altitude_m": 215.0,
                "accuracy_m": 4.0,
                "reported_speed": forged_reported_speed_ms,  # FORGED TELEMETRY
                "attack_type": "speed_field_spoofing",
                "transport_mode": "vehicle",
                "is_anomaly": 1,
            })
    return points


def generate_timestamp_stretching_cheats(n_sessions: int = 25, points_per_session: int = 50) -> List[dict]:
    """Generates stretched timestamps to artificially dilute vehicular speed or sudden teleport jumps."""
    points = []
    for s_idx in range(n_sessions):
        session_id = f"adv_time_warp_{s_idx:03d}"
        lat, lon = 28.5600 + s_idx * 0.005, 77.2000 + s_idx * 0.005
        t = 1792950000.0 + s_idx * 10000
        heading = random.uniform(0.0, 360.0)

        # 50% time stretch, 50% teleportation jump
        is_teleport = (s_idx % 2 == 1)

        for i in range(points_per_session):
            if is_teleport and i == 25:
                # Sudden 2 km teleport jump in 1 second
                dist_m = 2000.0
                dt = 1.0
            else:
                dist_m = random.uniform(10.0, 18.0)
                # Artificially stretched dt (multiplied by 4x to mask distance)
                dt = 4.0 if not is_teleport else 1.0

            t += dt
            heading = (heading + random.gauss(0.0, 2.0)) % 360.0
            d_lat_m = dist_m * math.cos(math.radians(heading))
            d_lon_m = dist_m * math.sin(math.radians(heading))
            d_lat, d_lon = _meters_to_lat_lon(d_lat_m, d_lon_m, lat)
            lat += d_lat
            lon += d_lon

            points.append({
                "user_id": f"adv_user_{s_idx % 5:02d}",
                "session_id": session_id,
                "timestamp": t,
                "latitude": lat,
                "longitude": lon,
                "altitude_m": 210.0,
                "accuracy_m": 3.5,
                "reported_speed": dist_m / dt,
                "attack_type": "timestamp_stretching",
                "transport_mode": "vehicle",
                "is_anomaly": 1,
            })
    return points


def generate_replay_offset_cheats(n_sessions: int = 25, points_per_session: int = 50) -> List[dict]:
    """Clones legitimate athletic routes and applies spatial offsets, jitter, and unnatural stitched seams."""
    points = []
    for s_idx in range(n_sessions):
        session_id = f"adv_replay_{s_idx:03d}"
        # Shifted origin
        lat = 28.5700 + random.uniform(0.05, 0.20)
        lon = 77.2100 + random.uniform(0.05, 0.20)
        t = 1792950000.0 + s_idx * 10000
        heading = random.uniform(0.0, 360.0)
        speed_ms = random.uniform(2.6, 3.2)  # Running speed

        for i in range(points_per_session):
            dt = 1.0
            t += dt
            # Replay with unnatural coordinate jitter and a stitched splice seam at i=30
            if i == 30:
                lat += 0.005  # 550m splice seam jump
                lon += 0.005
            else:
                heading = (heading + random.gauss(0.0, 5.0)) % 360.0
                dist_m = speed_ms * dt
                d_lat_m = dist_m * math.cos(math.radians(heading)) + random.gauss(0.0, 0.5)
                d_lon_m = dist_m * math.sin(math.radians(heading)) + random.gauss(0.0, 0.5)
                d_lat, d_lon = _meters_to_lat_lon(d_lat_m, d_lon_m, lat)
                lat += d_lat
                lon += d_lon

            points.append({
                "user_id": f"adv_user_{s_idx % 5:02d}",
                "session_id": session_id,
                "timestamp": t,
                "latitude": lat,
                "longitude": lon,
                "altitude_m": 205.0,
                "accuracy_m": 1.0,  # Unnaturally perfect GPS accuracy
                "reported_speed": speed_ms,
                "attack_type": "replay_shifted_offset",
                "transport_mode": "vehicle",  # Cheat classification
                "is_anomaly": 1,
            })
    return points


def generate_adversarial_test_set(
    output_path: str = "ml/data/adversarial_test_set.parquet",
    sessions_per_attack: int = 25,
    points_per_session: int = 50,
) -> pd.DataFrame:
    """Generates all 4 adversarial cheat attack families and saves strictly to held-out test set."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    all_points = []

    print("[*] Generating adversarial cheat test set (strictly held-out)...")
    sparse_pts = generate_sparse_sampling_cheats(sessions_per_attack, points_per_session)
    all_points.extend(sparse_pts)
    print(f"    - Sparse sampling: {len(sparse_pts):,} points across {sessions_per_attack} sessions")

    speed_pts = generate_speed_spoofing_cheats(sessions_per_attack, points_per_session)
    all_points.extend(speed_pts)
    print(f"    - Speed field spoofing: {len(speed_pts):,} points across {sessions_per_attack} sessions")

    time_pts = generate_timestamp_stretching_cheats(sessions_per_attack, points_per_session)
    all_points.extend(time_pts)
    print(f"    - Timestamp stretching/jumps: {len(time_pts):,} points across {sessions_per_attack} sessions")

    replay_pts = generate_replay_offset_cheats(sessions_per_attack, points_per_session)
    all_points.extend(replay_pts)
    print(f"    - Replayed shifted offsets: {len(replay_pts):,} points across {sessions_per_attack} sessions")

    df = pd.DataFrame(all_points)
    df.sort_values(by=["session_id", "timestamp"], inplace=True)
    df.reset_index(drop=True, inplace=True)

    df.to_parquet(output_path, index=False)
    csv_fallback = output_path.replace(".parquet", ".csv.gz")
    df.to_csv(csv_fallback, index=False, compression="gzip")

    print(f"[+] Total adversarial test points: {len(df):,} across {df['session_id'].nunique()} attack sessions.")
    print(f"[+] Saved strictly to held-out test set: {output_path} (NEVER mixed into training).\n")

    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate adversarial GPS cheat test set.")
    parser.add_argument("--output", default="ml/data/adversarial_test_set.parquet", help="Path to save adversarial parquet")
    parser.add_argument("--sessions-per-attack", type=int, default=25, help="Number of sessions per cheat family")
    parser.add_argument("--points-per-session", type=int, default=50, help="Points per session")
    args = parser.parse_args()

    generate_adversarial_test_set(
        output_path=args.output,
        sessions_per_attack=args.sessions_per_attack,
        points_per_session=args.points_per_session,
    )
