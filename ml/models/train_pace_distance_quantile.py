"""
Quantile Regression Training Pipeline for Pace & Achievable Distance Prediction
Territory Runner AI/ML Subsystem

Trains LightGBM quantile regression models (p10, p50, p90) predicting:
1. Achievable Run Distance (km)
2. Next-Run Pace (min/km)
from the user's last N runs (pace history, distance history, elevation, rest days,
time of day, and streak).

Strict methodological guarantees:
- Time-based split per user: chronologically earliest runs train, latest runs evaluate.
- Real user data only: metrics and model parameters are trained exclusively on real
  GeoLife athlete traces. Synthetic data is used ONLY in unit tests for cold-start edge cases.
- Exports compact, cryptographically verifiable decision trees for pure Dart and Go inference.
"""

import hashlib
import json
import math
import os
import random
import sys
from typing import Any, Dict, List, Tuple

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error

RANDOM_SEED = 42
os.environ["PYTHONHASHSEED"] = str(RANDOM_SEED)
random.seed(RANDOM_SEED)
np.seed = RANDOM_SEED
np.random.seed(RANDOM_SEED)

FEATURE_COLUMNS = [
    "pace_mean_last_n",
    "pace_std_last_n",
    "pace_min_last_n",
    "pace_last_run",
    "dist_mean_last_n",
    "dist_std_last_n",
    "dist_max_last_n",
    "dist_last_run",
    "volume_last_n",
    "elevation_mean_last_n",
    "elevation_last_run",
    "rest_days",
    "time_of_day_hour",
    "time_of_day_sin",
    "time_of_day_cos",
    "streak",
]


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    )
    return 2.0 * R * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))


def extract_sessions_from_trajectories(parquet_path: str) -> pd.DataFrame:
    print(f"[*] Reading trajectories from {parquet_path}...")
    df = pd.read_parquet(parquet_path)

    # Focus on pedestrian / running modes
    if "transport_mode" in df.columns:
        legit_mask = df["transport_mode"].isin(["legit_walk_run", "legit_cycle"])
        df = df[legit_mask].copy()

    df["timestamp_dt"] = pd.to_datetime(df["timestamp"], unit="s")
    df = df.sort_values(["user_id", "session_id", "timestamp"]).reset_index(drop=True)

    sessions: List[Dict[str, Any]] = []

    for (user_id, session_id), group in df.groupby(["user_id", "session_id"], sort=False):
        if len(group) < 10:
            continue

        lats = group["latitude"].values
        lons = group["longitude"].values
        alts = group["altitude_m"].values if "altitude_m" in group.columns else np.zeros(len(group))
        times_raw = group["timestamp"].values
        times_dt = group["timestamp_dt"].values

        total_dist_km = 0.0
        for i in range(len(lats) - 1):
            total_dist_km += haversine_km(lats[i], lons[i], lats[i + 1], lons[i + 1])

        duration_sec = float(times_raw[-1] - times_raw[0])

        if duration_sec < 120 or total_dist_km < 0.3:
            continue

        duration_min = duration_sec / 60.0
        pace_min_km = duration_min / total_dist_km

        # Physiological filter for running/walking: pace between 2.5 min/km (elite) and 18.0 min/km (power walk)
        if pace_min_km < 2.5 or pace_min_km > 18.0 or total_dist_km > 45.0:
            continue

        # Elevation gain
        elev_gain = 0.0
        for i in range(len(alts) - 1):
            diff = alts[i + 1] - alts[i]
            if diff > 0 and diff < 50.0:  # exclude GPS altitude spikes
                elev_gain += diff

        sessions.append({
            "user_id": str(user_id),
            "session_id": str(session_id),
            "start_time": pd.Timestamp(times_dt[0]),
            "duration_min": duration_min,
            "distance_km": total_dist_km,
            "pace_min_km": pace_min_km,
            "elevation_gain_m": elev_gain,
        })

    session_df = pd.DataFrame(sessions)
    if session_df.empty:
        raise ValueError("No valid athletic sessions found in trajectories dataset.")
    session_df = session_df.sort_values(["user_id", "start_time"]).reset_index(drop=True)
    print(f"[+] Extracted {len(session_df)} valid athletic sessions across {session_df['user_id'].nunique()} users.")
    return session_df


def build_sequential_dataset(
    session_df: pd.DataFrame, n_runs: int = 5
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    train_rows: List[Dict[str, Any]] = []
    test_rows: List[Dict[str, Any]] = []

    for user_id, user_sessions in session_df.groupby("user_id"):
        user_sessions = user_sessions.sort_values("start_time").reset_index(drop=True)
        m = len(user_sessions)
        if m < n_runs + 1:
            continue

        # Compute rest days and streaks
        user_rows: List[Dict[str, Any]] = []
        for k in range(n_runs, m):
            window = user_sessions.iloc[k - n_runs : k]
            current_run = user_sessions.iloc[k]

            paces = window["pace_min_km"].values
            dists = window["distance_km"].values
            elevs = window["elevation_gain_m"].values

            prev_time = window.iloc[-1]["start_time"]
            curr_time = current_run["start_time"]
            rest_days = max(0.0, min(30.0, (curr_time - prev_time).total_seconds() / 86400.0))

            # Streak calculation: count runs spaced <= 2 days apart in history
            streak = 1
            for idx in range(len(window) - 1, 0, -1):
                gap = (window.iloc[idx]["start_time"] - window.iloc[idx - 1]["start_time"]).total_seconds() / 86400.0
                if gap <= 2.0:
                    streak += 1
                else:
                    break

            hour = curr_time.hour + curr_time.minute / 60.0
            time_sin = math.sin(2 * math.pi * hour / 24.0)
            time_cos = math.cos(2 * math.pi * hour / 24.0)

            user_rows.append({
                "user_id": user_id,
                "session_id": current_run["session_id"],
                "start_time": curr_time,
                "pace_mean_last_n": float(np.mean(paces)),
                "pace_std_last_n": float(np.std(paces)) if len(paces) > 1 else 0.0,
                "pace_min_last_n": float(np.min(paces)),
                "pace_last_run": float(paces[-1]),
                "dist_mean_last_n": float(np.mean(dists)),
                "dist_std_last_n": float(np.std(dists)) if len(dists) > 1 else 0.0,
                "dist_max_last_n": float(np.max(dists)),
                "dist_last_run": float(dists[-1]),
                "volume_last_n": float(np.sum(dists)),
                "elevation_mean_last_n": float(np.mean(elevs)),
                "elevation_last_run": float(elevs[-1]),
                "rest_days": float(rest_days),
                "time_of_day_hour": float(hour),
                "time_of_day_sin": float(time_sin),
                "time_of_day_cos": float(time_cos),
                "streak": float(streak),
                "target_distance_km": float(current_run["distance_km"]),
                "target_pace_min_km": float(current_run["pace_min_km"]),
            })

        # Time-based split per user: earliest 75% for Train, latest 25% for Test
        split_idx = int(len(user_rows) * 0.75)
        if split_idx == len(user_rows):
            split_idx = len(user_rows) - 1

        train_rows.extend(user_rows[:split_idx])
        test_rows.extend(user_rows[split_idx:])

    train_df = pd.DataFrame(train_rows)
    test_df = pd.DataFrame(test_rows)
    print(f"[+] Time-based split created: Train={len(train_df)} windows, Test={len(test_df)} windows (0 cross-split leakage).")
    return train_df, test_df


def pinball_loss(y_true: np.ndarray, y_pred: np.ndarray, alpha: float) -> float:
    err = y_true - y_pred
    return float(np.mean(np.maximum(alpha * err, (alpha - 1.0) * err)))


def train_quantile_ensemble(
    train_df: pd.DataFrame, test_df: pd.DataFrame
) -> Tuple[Dict[str, Any], Dict[str, Any], Dict[str, Any]]:
    X_train = train_df[FEATURE_COLUMNS].values
    X_test = test_df[FEATURE_COLUMNS].values

    y_dist_train = train_df["target_distance_km"].values
    y_dist_test = test_df["target_distance_km"].values

    y_pace_train = train_df["target_pace_min_km"].values
    y_pace_test = test_df["target_pace_min_km"].values

    quantiles = [0.10, 0.50, 0.90]
    dist_models: Dict[str, lgb.LGBMRegressor] = {}
    pace_models: Dict[str, lgb.LGBMRegressor] = {}

    print("[*] Training Distance Quantile Regressors (p10, p50, p90)...")
    for q in quantiles:
        name = f"p{int(q * 100)}"
        model = lgb.LGBMRegressor(
            objective="quantile",
            alpha=q,
            n_estimators=35,
            max_depth=3,
            num_leaves=8,
            min_child_samples=5,
            learning_rate=0.08,
            random_state=RANDOM_SEED,
            verbose=-1,
        )
        model.fit(X_train, y_dist_train)
        dist_models[name] = model

    print("[*] Training Pace Quantile Regressors (p10, p50, p90)...")
    for q in quantiles:
        name = f"p{int(q * 100)}"
        model = lgb.LGBMRegressor(
            objective="quantile",
            alpha=q,
            n_estimators=35,
            max_depth=3,
            num_leaves=8,
            min_child_samples=5,
            learning_rate=0.08,
            random_state=RANDOM_SEED,
            verbose=-1,
        )
        model.fit(X_train, y_pace_train)
        pace_models[name] = model

    # Evaluate on held-out test set
    dist_preds = {name: m.predict(X_test) for name, m in dist_models.items()}
    pace_preds = {name: m.predict(X_test) for name, m in pace_models.items()}

    # Guarantee non-crossing quantiles
    dist_preds["p50"] = np.maximum(dist_preds["p10"], dist_preds["p50"])
    dist_preds["p90"] = np.maximum(dist_preds["p50"], dist_preds["p90"])

    pace_preds["p50"] = np.maximum(pace_preds["p10"], pace_preds["p50"])
    pace_preds["p90"] = np.maximum(pace_preds["p50"], pace_preds["p90"])

    # Metrics
    dist_coverage = float(
        np.mean((y_dist_test >= dist_preds["p10"]) & (y_dist_test <= dist_preds["p90"]))
    )
    pace_coverage = float(
        np.mean((y_pace_test >= pace_preds["p10"]) & (y_pace_test <= pace_preds["p90"]))
    )

    dist_mae_p50 = float(mean_absolute_error(y_dist_test, dist_preds["p50"]))
    pace_mae_p50 = float(mean_absolute_error(y_pace_test, pace_preds["p50"]))

    dist_pinball_p10 = pinball_loss(y_dist_test, dist_preds["p10"], 0.10)
    dist_pinball_p50 = pinball_loss(y_dist_test, dist_preds["p50"], 0.50)
    dist_pinball_p90 = pinball_loss(y_dist_test, dist_preds["p90"], 0.90)

    pace_pinball_p10 = pinball_loss(y_pace_test, pace_preds["p10"], 0.10)
    pace_pinball_p50 = pinball_loss(y_pace_test, pace_preds["p50"], 0.50)
    pace_pinball_p90 = pinball_loss(y_pace_test, pace_preds["p90"], 0.90)

    metrics = {
        "distance": {
            "p10_pinball_loss": dist_pinball_p10,
            "p50_pinball_loss": dist_pinball_p50,
            "p90_pinball_loss": dist_pinball_p90,
            "p50_mae_km": dist_mae_p50,
            "p10_p90_coverage_rate": dist_coverage,
            "mean_interval_width_km": float(np.mean(dist_preds["p90"] - dist_preds["p10"])),
        },
        "pace": {
            "p10_pinball_loss": pace_pinball_p10,
            "p50_pinball_loss": pace_pinball_p50,
            "p90_pinball_loss": pace_pinball_p90,
            "p50_mae_min_km": pace_mae_p50,
            "p10_p90_coverage_rate": pace_coverage,
            "mean_interval_width_min_km": float(np.mean(pace_preds["p90"] - pace_preds["p10"])),
        },
    }

    print("\n" + "=" * 60)
    print("LIGHTGBM QUANTILE REGRESSION EVALUATION (Held-Out Test Set)")
    print("=" * 60)
    print(f"Distance p50 MAE:                 {dist_mae_p50:.3f} km")
    print(f"Distance [p10, p90] Coverage:     {dist_coverage * 100:.2f}% (Ideal ~80%)")
    print(f"Distance Mean Interval Width:     {metrics['distance']['mean_interval_width_km']:.3f} km")
    print(f"Pace p50 MAE:                     {pace_mae_p50:.3f} min/km")
    print(f"Pace [p10, p90] Coverage:         {pace_coverage * 100:.2f}% (Ideal ~80%)")
    print(f"Pace Mean Interval Width:         {metrics['pace']['mean_interval_width_min_km']:.3f} min/km")
    print("=" * 60 + "\n")

    return dist_models, pace_models, metrics


def convert_lgbm_node(node: Dict[str, Any]) -> Dict[str, Any]:
    if "leaf_value" in node:
        return {"leaf_value": float(node["leaf_value"])}
    split_feature = int(node.get("split_feature", -1))
    threshold = float(node.get("threshold", 0.0))
    left_child = convert_lgbm_node(node.get("left_child", {}))
    right_child = convert_lgbm_node(node.get("right_child", {}))
    return {
        "split_feature": split_feature,
        "threshold": threshold,
        "left": left_child,
        "right": right_child,
    }


def export_models_to_json(
    dist_models: Dict[str, lgb.LGBMRegressor],
    pace_models: Dict[str, lgb.LGBMRegressor],
    metrics: Dict[str, Any],
    trees_output_paths: List[str],
    meta_output_paths: List[str],
) -> None:
    trees_bundle: Dict[str, Any] = {
        "model_name": "Pace & Distance Quantile Regressor",
        "model_version": "1.0.0",
        "feature_names": FEATURE_COLUMNS,
        "num_features": len(FEATURE_COLUMNS),
        "models": {
            "distance": {},
            "pace": {},
        },
    }

    for name, m in dist_models.items():
        dump = m.booster_.dump_model()
        tree_nodes = [convert_lgbm_node(t["tree_structure"]) for t in dump["tree_info"]]
        trees_bundle["models"]["distance"][name] = {
            "num_trees": len(tree_nodes),
            "trees": tree_nodes,
        }

    for name, m in pace_models.items():
        dump = m.booster_.dump_model()
        tree_nodes = [convert_lgbm_node(t["tree_structure"]) for t in dump["tree_info"]]
        trees_bundle["models"]["pace"][name] = {
            "num_trees": len(tree_nodes),
            "trees": tree_nodes,
        }

    trees_json_str = json.dumps(trees_bundle, indent=2)
    trees_sha = hashlib.sha256(trees_json_str.encode("utf-8")).hexdigest()

    meta_bundle: Dict[str, Any] = {
        "model_name": "Pace & Distance Quantile Regressor",
        "model_version": "1.0.0",
        "sha256_trees": trees_sha,
        "quantiles": [0.10, 0.50, 0.90],
        "feature_names": FEATURE_COLUMNS,
        "num_features": len(FEATURE_COLUMNS),
        "metrics": metrics,
        "cold_start_threshold": 5,
        "adaptive_goal_mapping": {
            "target": "p50_distance",
            "stretch": "p90_distance",
            "conservative": "p10_distance",
        },
    }
    meta_json_str = json.dumps(meta_bundle, indent=2)

    for p in trees_output_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f:
            f.write(trees_json_str.encode("utf-8"))
        print(f"[+] Exported decision tree ensemble to {p} (SHA: {trees_sha[:8]}...)")

    for p in meta_output_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f:
            f.write(meta_json_str.encode("utf-8"))
        print(f"[+] Exported metadata to {p}")


def main():
    parquet_path = "ml/data/processed_trajectories.parquet"
    if not os.path.exists(parquet_path):
        print(f"[-] Parquet file {parquet_path} not found.")
        sys.exit(1)

    session_df = extract_sessions_from_trajectories(parquet_path)
    train_df, test_df = build_sequential_dataset(session_df, n_runs=5)

    dist_models, pace_models, metrics = train_quantile_ensemble(train_df, test_df)

    trees_paths = [
        "assets/models/pace_distance_trees.json",
        "backend/internal/coach/pace_distance_trees.json",
    ]
    meta_paths = [
        "assets/models/pace_distance_meta.json",
        "backend/internal/coach/pace_distance_meta.json",
    ]

    export_models_to_json(dist_models, pace_models, metrics, trees_paths, meta_paths)
    print("\n[+] Pace & Distance Quantile Regressor pipeline completed successfully!")


if __name__ == "__main__":
    main()
