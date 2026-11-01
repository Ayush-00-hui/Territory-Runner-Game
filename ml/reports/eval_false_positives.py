"""
Evaluate Real False Positive Behavior on Clean GeoLife Dataset
Territory Runner ML Anti-Cheat Engine - Task M4

Computes empirical false positive rates (FPR) across legitimate human locomotion:
- Walk (21,240 windows) by speed bracket (< 4 km/h, 4-7 km/h, > 7 km/h)
- Run (18 windows)
- Bike (29,161 windows) by speed bracket (< 15 km/h, 15-25 km/h, > 25 km/h)
- Evaluates Rule Baseline and GPS-Only LightGBM
"""

import sys
import numpy as np
import pandas as pd
from sklearn.model_selection import GroupKFold
import lightgbm as lgb
from pathlib import Path

# Add repo root to sys.path
repo_root = Path(__file__).resolve().parents[2]
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from ml.models.baseline import RuleBaselineClassifier

GPS_FEATURES = [
    "speed_mean_kmh", "speed_std_kmh", "speed_max_kmh", "speed_p95_kmh", "speed_median_kmh",
    "accel_mean_ms2", "accel_std_ms2", "accel_max_ms2", "accel_p95_ms2",
    "jerk_mean_ms3", "jerk_std_ms3", "jerk_max_ms3",
    "heading_turn_mean_degs", "heading_turn_std_degs", "heading_entropy",
    "sinuosity", "stop_ratio",
    "gps_accuracy_mean", "gps_accuracy_std", "gps_accuracy_max",
    "dt_median_s", "dt_std_s",
]

def analyze_false_positives():
    df = pd.read_parquet("ml/data/features_clean.parquet")
    print(f"Total dataset: {len(df):,} windows across {df['user_id'].nunique()} users")

    # Filter legitimate human windows
    legit_mask = df["is_anomaly"] == 0
    df_legit = df[legit_mask].copy()
    print(f"Legitimate human windows: {len(df_legit):,} (walk: {(df_legit['raw_mode']=='walk').sum():,}, bike: {(df_legit['raw_mode']=='bike').sum():,}, run: {(df_legit['raw_mode']=='run').sum():,})")

    # 1. Rule Baseline Evaluation
    baseline = RuleBaselineClassifier()
    df_features = df[GPS_FEATURES]
    rule_probs = baseline.predict_proba(df_features)[:, 1]
    df["rule_prob"] = rule_probs

    # Calibrate rule threshold at 1% and 5% target FPR on legitimate windows
    legit_rule_probs = df.loc[legit_mask, "rule_prob"].values
    t_rule_1pct = float(np.percentile(legit_rule_probs, 99.0))
    t_rule_5pct = float(np.percentile(legit_rule_probs, 95.0))
    t_rule_default = 0.50

    print(f"\n--- Rule Baseline Calibrated Thresholds ---")
    print(f"Target 1% FPR Threshold: {t_rule_1pct:.4f}")
    print(f"Target 5% FPR Threshold: {t_rule_5pct:.4f}")
    print(f"Default (0.50) Threshold: {t_rule_default:.4f}")

    # 2. LightGBM LOUO Cross-Validation Predictions (GPS-Only)
    y = df["is_anomaly"].values.astype(int)
    users = df["user_id"].values
    gkf = GroupKFold(n_splits=5)
    lgb_oof = np.zeros(len(df), dtype=np.float64)

    lgb_params = {
        "objective": "binary",
        "metric": "binary_logloss",
        "boosting_type": "gbdt",
        "n_estimators": 100,
        "learning_rate": 0.05,
        "num_leaves": 31,
        "random_state": 42,
        "verbose": -1,
        "n_jobs": -1,
    }

    for fold, (train_idx, val_idx) in enumerate(gkf.split(df_features, y, groups=users)):
        X_tr, y_tr = df_features.iloc[train_idx], y[train_idx]
        X_va = df_features.iloc[val_idx]
        clf = lgb.LGBMClassifier(**lgb_params)
        clf.fit(X_tr, y_tr)
        lgb_oof[val_idx] = clf.predict_proba(X_va)[:, 1]

    df["lgb_prob"] = lgb_oof
    legit_lgb_probs = df.loc[legit_mask, "lgb_prob"].values
    t_lgb_1pct = float(np.percentile(legit_lgb_probs, 99.0))
    t_lgb_5pct = float(np.percentile(legit_lgb_probs, 95.0))
    t_lgb_default = 0.50

    print(f"\n--- LightGBM (GPS-Only) Calibrated Thresholds ---")
    print(f"Target 1% FPR Threshold: {t_lgb_1pct:.4f}")
    print(f"Target 5% FPR Threshold: {t_lgb_5pct:.4f}")
    print(f"Default (0.50) Threshold: {t_lgb_default:.4f}")

    # 3. Mode & Speed Breakdown
    print("\n" + "="*80)
    print("DETAILED EMPIRICAL FALSE POSITIVE RATES ACROSS MODES AND SPEED BRACKETS")
    print("="*80)

    subsets = {
        "All Legitimate Human": legit_mask,
        "Walk (All)": (df["raw_mode"] == "walk"),
        "  - Walk Low Speed (< 4 km/h)": (df["raw_mode"] == "walk") & (df["speed_mean_kmh"] < 4.0),
        "  - Walk Normal (4 - 7 km/h)": (df["raw_mode"] == "walk") & (df["speed_mean_kmh"] >= 4.0) & (df["speed_mean_kmh"] <= 7.0),
        "  - Walk Outlier/Fast (> 7 km/h)": (df["raw_mode"] == "walk") & (df["speed_mean_kmh"] > 7.0),
        "Run (All 18 windows)": (df["raw_mode"] == "run"),
        "Bike (All)": (df["raw_mode"] == "bike"),
        "  - Bike Low Speed (< 15 km/h)": (df["raw_mode"] == "bike") & (df["speed_mean_kmh"] < 15.0),
        "  - Bike Cruising (15 - 25 km/h)": (df["raw_mode"] == "bike") & (df["speed_mean_kmh"] >= 15.0) & (df["speed_mean_kmh"] <= 25.0),
        "  - Bike Fast (> 25 km/h)": (df["raw_mode"] == "bike") & (df["speed_mean_kmh"] > 25.0),
    }

    report_rows = []
    for name, mask in subsets.items():
        n = mask.sum()
        if n == 0:
            continue
        sub = df[mask]
        
        # Rule baseline FP counts
        rule_fp_default = (sub["rule_prob"] >= t_rule_default).sum()
        rule_fp_1pct = (sub["rule_prob"] >= t_rule_1pct).sum()
        rule_fpr_default = rule_fp_default / n * 100.0
        rule_fpr_1pct = rule_fp_1pct / n * 100.0

        # LightGBM FP counts
        lgb_fp_default = (sub["lgb_prob"] >= t_lgb_default).sum()
        lgb_fp_1pct = (sub["lgb_prob"] >= t_lgb_1pct).sum()
        lgb_fpr_default = lgb_fp_default / n * 100.0
        lgb_fpr_1pct = lgb_fp_1pct / n * 100.0

        report_rows.append({
            "Cohort": name,
            "N": n,
            "Rule FP (Def 0.50)": f"{rule_fp_default} ({rule_fpr_default:.2f}%)",
            "Rule FP (@1% FPR)": f"{rule_fp_1pct} ({rule_fpr_1pct:.2f}%)",
            "LGB FP (Def 0.50)": f"{lgb_fp_default} ({lgb_fpr_default:.2f}%)",
            "LGB FP (@1% FPR)": f"{lgb_fp_1pct} ({lgb_fpr_1pct:.2f}%)",
        })

    report_df = pd.DataFrame(report_rows)
    print(report_df.to_string(index=False))

    # 4. Root cause analysis for Walker false positives
    walk_mask = df["raw_mode"] == "walk"
    walk_fp_rule = df[walk_mask & (df["rule_prob"] >= t_rule_default)]
    print(f"\n--- Root Cause Breakdown for Rule Baseline Walk False Positives (N={len(walk_fp_rule)}) ---")
    if len(walk_fp_rule) > 0:
        high_accel = (walk_fp_rule["accel_max_ms2"] > 5.5).sum()
        sparse_dt = (walk_fp_rule["dt_median_s"] > 5.0).sum()
        high_p95_spd = (walk_fp_rule["speed_p95_kmh"] > 24.0).sum()
        high_avg_spd = (walk_fp_rule["speed_mean_kmh"] > 20.0).sum()
        print(f"  Max Accel > 5.5 m/s² (GPS jitter/jumps): {high_accel} ({high_accel/len(walk_fp_rule)*100:.1f}%)")
        print(f"  Sparse Sampling (dt > 5.0s):            {sparse_dt} ({sparse_dt/len(walk_fp_rule)*100:.1f}%)")
        print(f"  P95 Speed > 24 km/h (GPS drift jump):   {high_p95_spd} ({high_p95_spd/len(walk_fp_rule)*100:.1f}%)")
        print(f"  Avg Speed > 20 km/h:                    {high_avg_spd} ({high_avg_spd/len(walk_fp_rule)*100:.1f}%)")

if __name__ == "__main__":
    analyze_false_positives()

