"""
GeoLife GPS Trajectories Data Download & Preparation Pipeline
Territory Runner ML Anti-Cheat Engine

Downloads the public Microsoft Research GeoLife Trajectories 1.3 dataset,
extracts ground-truth labeled transport sessions, and maps transportation
modes to:
  - legit_walk_run: walk, run
  - legit_cycle:    bike
  - vehicle:        bus, car, taxi, train, subway, boat, airplane, motorcycle

Outputs processed, clean, session-labeled trajectory breadcrumbs ready for
adversarial test set generation and kinematic window feature extraction.
"""

import argparse
import datetime
import math
import os
import shutil
import sys
import urllib.request
import zipfile
from typing import Dict, List, Optional, Tuple

import pandas as pd
from tqdm import tqdm

# Deterministic seed
RANDOM_SEED = 42

GEOLIFE_DOWNLOAD_URL = (
    "https://download.microsoft.com/download/F/4/8/F4894AA5-FDBC-481E-9285-D5F8C4C4F039/Geolife%20Trajectories%201.3.zip"
)

# Standardized mode mapping according to specification
MODE_MAPPING = {
    "walk": "legit_walk_run",
    "run": "legit_walk_run",
    "bike": "legit_cycle",
    "bus": "vehicle",
    "car": "vehicle",
    "taxi": "vehicle",
    "train": "vehicle",
    "subway": "vehicle",
    "boat": "vehicle",
    "airplane": "vehicle",
    "motorcycle": "vehicle",
}


class DownloadProgressBar(tqdm):
    def update_to(self, b=1, bsize=1, tsize=None):
        if tsize is not None:
            self.total = tsize
        self.update(b * bsize - self.n)


def download_geolife(dest_zip_path: str) -> None:
    """Downloads GeoLife 1.3 zip archive with progress reporting if not already present."""
    if os.path.exists(dest_zip_path) and os.path.getsize(dest_zip_path) > 100 * 1024 * 1024:
        print(f"[*] GeoLife zip archive already present at: {dest_zip_path} ({os.path.getsize(dest_zip_path)/(1024*1024):.1f} MB)")
        return

    os.makedirs(os.path.dirname(dest_zip_path), exist_ok=True)
    print(f"[*] Downloading GeoLife Trajectories 1.3 dataset from Microsoft Research...")
    print(f"    URL: {GEOLIFE_DOWNLOAD_URL}")
    print(f"    Destination: {dest_zip_path}")

    opener = urllib.request.build_opener()
    opener.addheaders = [("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")]
    urllib.request.install_opener(opener)

    with DownloadProgressBar(unit="B", unit_scale=True, miniters=1, desc="GeoLife 1.3") as t:
        urllib.request.urlretrieve(GEOLIFE_DOWNLOAD_URL, filename=dest_zip_path, reporthook=t.update_to)
    print("[+] Download complete.")


def extract_labeled_users(zip_path: str, extract_dir: str, max_users: Optional[int] = None) -> List[str]:
    """Extracts only users who have labels.txt to minimize disk footprint."""
    os.makedirs(extract_dir, exist_ok=True)
    labeled_users = set()

    print(f"[*] Scanning {zip_path} for labeled users...")
    with zipfile.ZipFile(zip_path, "r") as z:
        for name in z.namelist():
            if name.endswith("labels.txt"):
                # Path typically: Geolife Trajectories 1.3/Data/010/labels.txt
                parts = name.replace("\\", "/").split("/")
                for i, p in enumerate(parts):
                    if p == "Data" and i + 1 < len(parts):
                        labeled_users.add(parts[i + 1])
                        break

        labeled_user_list = sorted(list(labeled_users))
        if max_users and max_users > 0:
            labeled_user_list = labeled_user_list[:max_users]

        print(f"[+] Found {len(labeled_users)} labeled users in GeoLife. Extracting {len(labeled_user_list)} target users...")

        members_to_extract = []
        for name in z.namelist():
            norm_name = name.replace("\\", "/")
            for u in labeled_user_list:
                if f"/Data/{u}/" in norm_name:
                    members_to_extract.append(name)
                    break

        for m in tqdm(members_to_extract, desc="Extracting labeled files"):
            z.extract(m, extract_dir)

    return labeled_user_list


def parse_labels_file(labels_path: str, user_id: str) -> List[dict]:
    """Parses user's labels.txt into structured time intervals."""
    intervals = []
    if not os.path.exists(labels_path):
        return intervals

    with open(labels_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    header_skipped = False
    session_idx = 0
    for line in lines:
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            parts = line.split()
            if len(parts) < 3:
                continue

        # Skip header: Start Time, End Time, Transportation Mode
        if "Start Time" in parts[0] or "Transportation" in line:
            header_skipped = True
            continue

        start_str = parts[0].strip()
        end_str = parts[1].strip()
        raw_mode = parts[2].strip().lower()

        mapped_mode = MODE_MAPPING.get(raw_mode)
        if not mapped_mode:
            continue

        try:
            start_dt = datetime.datetime.strptime(start_str, "%Y/%m/%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
            end_dt = datetime.datetime.strptime(end_str, "%Y/%m/%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
        except ValueError:
            try:
                start_dt = datetime.datetime.strptime(start_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
                end_dt = datetime.datetime.strptime(end_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
            except ValueError:
                continue

        if end_dt <= start_dt:
            continue

        session_id = f"geolife_{user_id}_s{session_idx:04d}_{mapped_mode}"
        session_idx += 1

        intervals.append({
            "user_id": user_id,
            "session_id": session_id,
            "start_dt": start_dt,
            "end_dt": end_dt,
            "raw_mode": raw_mode,
            "mapped_mode": mapped_mode,
        })

    return intervals


def parse_plt_file(plt_path: str, intervals: List[dict]) -> List[dict]:
    """Parses a single .plt file and associates points falling within ground-truth intervals."""
    points = []
    if not os.path.exists(plt_path):
        return points

    with open(plt_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()

    if len(lines) <= 6:
        return points

    # Read data points starting from line 7 (index 6)
    for line in lines[6:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split(",")
        if len(parts) < 7:
            continue

        try:
            lat = float(parts[0])
            lon = float(parts[1])
            alt_ft = float(parts[3])
            date_str = parts[5].strip()
            time_str = parts[6].strip()
            pt_dt = datetime.datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc)
        except (ValueError, IndexError):
            continue

        # Spatial sanity checks
        if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
            continue

        alt_m = alt_ft * 0.3048 if alt_ft != -777 else 0.0

        # Match against active interval
        for interval in intervals:
            if interval["start_dt"] <= pt_dt <= interval["end_dt"]:
                points.append({
                    "user_id": interval["user_id"],
                    "session_id": interval["session_id"],
                    "timestamp": pt_dt.timestamp(),
                    "latitude": lat,
                    "longitude": lon,
                    "altitude_m": alt_m,
                    "accuracy_m": 5.0,  # Standard consumer GPS median accuracy estimate
                    "raw_mode": interval["raw_mode"],
                    "transport_mode": interval["mapped_mode"],
                })
                break

    return points


def load_team_app_traces(app_traces_dir: str) -> List[dict]:
    """Loads any real field recordings collected by team members from app_traces_dir."""
    points = []
    if not os.path.exists(app_traces_dir):
        return points

    import json
    for fname in os.listdir(app_traces_dir):
        if not fname.endswith(".json"):
            continue
        fpath = os.path.join(app_traces_dir, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                data = json.load(f)
            user_id = data.get("user_id", "team_member")
            session_id = data.get("session_id", fname.replace(".json", ""))
            raw_mode = data.get("transport_mode", "walk").lower()
            mapped_mode = MODE_MAPPING.get(raw_mode, "legit_walk_run")

            for pt in data.get("points", []):
                points.append({
                    "user_id": user_id,
                    "session_id": session_id,
                    "timestamp": pt["timestamp_ms"] / 1000.0 if pt.get("timestamp_ms") else pt.get("timestamp", 0),
                    "latitude": float(pt["latitude"]),
                    "longitude": float(pt["longitude"]),
                    "altitude_m": float(pt.get("altitude", 0.0)),
                    "accuracy_m": float(pt.get("accuracy", 4.0)),
                    "raw_mode": raw_mode,
                    "transport_mode": mapped_mode,
                })
        except Exception as e:
            print(f"[-] Warning: Failed to parse team trace {fname}: {e}")

    if points:
        print(f"[+] Loaded {len(points)} team field trace points from {app_traces_dir}")
    return points


def prepare_dataset(
    raw_dir: str = "ml/data/raw",
    output_path: str = "ml/data/processed_trajectories.parquet",
    app_traces_dir: str = "ml/data/app_traces",
    max_users: Optional[int] = None,
) -> pd.DataFrame:
    """End-to-end GeoLife download, extraction, parsing, and preparation routine."""
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    os.makedirs(app_traces_dir, exist_ok=True)

    zip_path = os.path.join(raw_dir, "Geolife_Trajectories_1.3.zip")

    # 1. Download GeoLife archive
    download_geolife(zip_path)

    # 2. Extract labeled users
    extract_path = os.path.join(raw_dir, "extracted")
    labeled_users = extract_labeled_users(zip_path, extract_path, max_users=max_users)

    # Locate Data folder
    data_root = os.path.join(extract_path, "Geolife Trajectories 1.3", "Data")
    if not os.path.exists(data_root):
        # Alternative nesting check
        for root, dirs, _ in os.walk(extract_path):
            if "Data" in dirs:
                data_root = os.path.join(root, "Data")
                break

    all_points = []

    print(f"[*] Processing trajectories across {len(labeled_users)} labeled users...")
    for user_id in tqdm(labeled_users, desc="Parsing user trajectories"):
        user_dir = os.path.join(data_root, user_id)
        labels_file = os.path.join(user_dir, "labels.txt")
        traj_dir = os.path.join(user_dir, "Trajectory")

        if not os.path.exists(labels_file) or not os.path.exists(traj_dir):
            continue

        intervals = parse_labels_file(labels_file, user_id)
        if not intervals:
            continue

        for plt_name in os.listdir(traj_dir):
            if not plt_name.endswith(".plt"):
                continue
            plt_path = os.path.join(traj_dir, plt_name)
            pts = parse_plt_file(plt_path, intervals)
            all_points.extend(pts)

    # Merge team field recordings if available
    team_points = load_team_app_traces(app_traces_dir)
    all_points.extend(team_points)

    if not all_points:
        raise RuntimeError("No labeled trajectory points extracted. Check dataset extraction.")

    df = pd.DataFrame(all_points)
    df.sort_values(by=["user_id", "session_id", "timestamp"], inplace=True)
    df.drop_duplicates(subset=["session_id", "timestamp"], inplace=True)
    df.reset_index(drop=True, inplace=True)

    # Save to parquet (and fallback csv.gz)
    print(f"[*] Writing {len(df):,} cleaned trajectory points to {output_path}...")
    df.to_parquet(output_path, index=False)
    csv_fallback = output_path.replace(".parquet", ".csv.gz")
    df.to_csv(csv_fallback, index=False, compression="gzip")

    # Print summary statistics
    print("\n" + "=" * 60)
    print("GeoLife Data Preparation Summary")
    print("=" * 60)
    print(f"Total Points:     {len(df):,}")
    print(f"Total Sessions:   {df['session_id'].nunique():,}")
    print(f"Total Users:      {df['user_id'].nunique():,}")
    print("\nTransportation Mode Breakdown:")
    mode_counts = df.groupby("transport_mode")["session_id"].nunique()
    point_counts = df.groupby("transport_mode").size()
    for mode in mode_counts.index:
        print(f"  - {mode:<15}: {mode_counts[mode]:4d} sessions ({point_counts[mode]:,d} points)")
    print("=" * 60 + "\n")

    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download and preprocess GeoLife GPS trajectory dataset.")
    parser.add_argument("--raw-dir", default="ml/data/raw", help="Directory for raw GeoLife zip and extraction")
    parser.add_argument("--output", default="ml/data/processed_trajectories.parquet", help="Path to save processed parquet")
    parser.add_argument("--app-traces-dir", default="ml/data/app_traces", help="Directory containing team-collected JSON traces")
    parser.add_argument("--max-users", type=int, default=None, help="Maximum number of labeled users to extract (optional)")
    args = parser.parse_args()

    prepare_dataset(
        raw_dir=args.raw_dir,
        output_path=args.output,
        app_traces_dir=args.app_traces_dir,
        max_users=args.max_users,
    )
