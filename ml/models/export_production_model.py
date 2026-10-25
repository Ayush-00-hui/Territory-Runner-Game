"""
Production LightGBM Model Exporter to ONNX & Tree JSON
Territory Runner ML Anti-Cheat Subsystem

Trains the production LightGBM model on full clean feature traces (25 kinematic features),
exports to ONNX format (assets/models/anomaly_detector.onnx) and pure tree representation
(assets/models/anomaly_detector_trees.json), computes SHA256 hashes, and generates a
200-window parity fixture (test_fixtures/parity_200_windows.json) for Dart vs Go vs Python.
"""

import argparse
import hashlib
import json
import os
import random
import sys
import time
from typing import Dict, List, Tuple

import lightgbm as lgb
import numpy as np
import onnxmltools
from onnxmltools.convert.common.data_types import FloatTensorType
import onnxruntime as ort
import pandas as pd

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
from ml.features.extract import FEATURE_COLUMNS

RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

MODEL_VERSION = "3.0.0"


def compute_file_sha256(filepath: str) -> str:
    """Computes SHA256 hex digest of a file."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def train_production_lightgbm(df_clean: pd.DataFrame) -> lgb.LGBMClassifier:
    """Trains the final production LightGBM model on clean trajectory windows."""
    print(f"[*] Training production LightGBM model on {len(df_clean):,} windows (25 features)...")
    X = df_clean[FEATURE_COLUMNS].values.astype(np.float32)
    y = df_clean["is_anomaly"].values.astype(int)

    clf = lgb.LGBMClassifier(
        n_estimators=60,
        max_depth=6,
        num_leaves=31,
        learning_rate=0.08,
        min_child_samples=20,
        subsample=0.85,
        colsample_bytree=0.85,
        random_state=RANDOM_SEED,
        verbose=-1,
    )
    clf.fit(X, y)
    print(f"[+] Fitted LightGBM booster with {clf.n_estimators} trees.")
    return clf


def export_to_onnx(clf: lgb.LGBMClassifier, output_onnx_path: str) -> str:
    """Exports LightGBM model to ONNX format and verifies inference session."""
    os.makedirs(os.path.dirname(output_onnx_path), exist_ok=True)
    initial_type = [("float_input", FloatTensorType([None, len(FEATURE_COLUMNS)]))]
    onnx_model = onnxmltools.convert_lightgbm(clf, initial_types=initial_type, target_opset=12)

    with open(output_onnx_path, "wb") as f:
        f.write(onnx_model.SerializeToString())

    sha256 = compute_file_sha256(output_onnx_path)
    print(f"[+] Exported ONNX model to: {output_onnx_path}")
    print(f"    SHA256: {sha256}")

    # Verify ONNX Runtime can load and run
    sess = ort.InferenceSession(output_onnx_path)
    dummy_input = np.zeros((1, len(FEATURE_COLUMNS)), dtype=np.float32)
    input_name = sess.get_inputs()[0].name
    res = sess.run(None, {input_name: dummy_input})
    assert len(res) >= 2, "ONNX model must output probabilities"
    print("    Verified ONNX inference execution.")
    return sha256


def export_to_tree_json(clf: lgb.LGBMClassifier, output_json_path: str) -> Tuple[dict, str]:
    """Exports LightGBM trees to a compact JSON format for pure Go and pure Dart evaluators."""
    os.makedirs(os.path.dirname(output_json_path), exist_ok=True)
    raw_dump = clf.booster_.dump_model()

    def simplify_node(node: dict) -> dict:
        if "leaf_value" in node:
            return {
                "leaf_value": float(node["leaf_value"]),
            }
        return {
            "split_feature": int(node["split_feature"]),
            "threshold": float(node["threshold"]),
            "left": simplify_node(node["left_child"]),
            "right": simplify_node(node["right_child"]),
        }

    trees = []
    for t_info in raw_dump.get("tree_info", []):
        trees.append(simplify_node(t_info["tree_structure"]))

    payload = {
        "model_version": MODEL_VERSION,
        "feature_names": FEATURE_COLUMNS,
        "num_trees": len(trees),
        "trees": trees,
    }

    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    sha256 = compute_file_sha256(output_json_path)
    print(f"[+] Exported compact Tree JSON to: {output_json_path}")
    print(f"    SHA256: {sha256}")
    return payload, sha256


def generate_parity_fixture(
    clf: lgb.LGBMClassifier,
    df_clean: pd.DataFrame,
    output_fixture_path: str,
    model_sha256: str,
    n_windows: int = 200,
) -> None:
    """Generates a 200-window deterministic parity test fixture across clean and adversarial cases."""
    os.makedirs(os.path.dirname(output_fixture_path), exist_ok=True)
    rng = np.random.RandomState(RANDOM_SEED)

    # 1. 100 legitimate windows (walk, run, bike)
    legit_df = df_clean[df_clean["is_anomaly"] == 0]
    legit_sub = legit_df.sample(n=min(100, len(legit_df)), random_state=rng)

    # 2. 80 vehicle windows (car, bus, taxi, train)
    veh_df = df_clean[df_clean["is_anomaly"] == 1]
    veh_sub = veh_df.sample(n=min(80, len(veh_df)), random_state=rng)

    # 3. 20 synthetic boundary edge cases (borderline speeds, threshold transitions)
    edge_cases = []
    for i in range(20):
        row = legit_sub.iloc[i % len(legit_sub)][FEATURE_COLUMNS].to_dict()
        if i < 7:
            # Borderline jogging speed (14 km/h) with zero cadence
            row["speed_mean_kmh"] = 14.5
            row["cadence_spm"] = 0.0
            row["motion_energy"] = 0.05
        elif i < 14:
            # Extreme high speed highway driving
            row["speed_mean_kmh"] = 85.0
            row["speed_max_kmh"] = 110.0
            row["cadence_spm"] = 5.0
            row["motion_energy"] = 0.08
        else:
            # High acceleration jump
            row["accel_max_ms2"] = 10.5
            row["jerk_max_ms3"] = 15.0
        edge_cases.append(row)
    edge_df = pd.DataFrame(edge_cases)

    combined_df = pd.concat([legit_sub[FEATURE_COLUMNS], veh_sub[FEATURE_COLUMNS], edge_df], ignore_index=True)
    if len(combined_df) > n_windows:
        combined_df = combined_df.iloc[:n_windows]

    X = combined_df[FEATURE_COLUMNS].values.astype(np.float32)
    py_probs = clf.predict_proba(X)[:, 1]

    test_cases = []
    for idx in range(len(combined_df)):
        feats_list = [float(v) for v in X[idx]]
        feats_map = {FEATURE_COLUMNS[j]: float(X[idx, j]) for j in range(len(FEATURE_COLUMNS))}
        prob = float(py_probs[idx])
        test_cases.append({
            "id": f"win_{idx:03d}",
            "features": feats_list,
            "features_map": feats_map,
            "expected_probability": prob,
            "expected_is_anomaly": bool(prob >= 0.5),
        })

    fixture_payload = {
        "model_version": MODEL_VERSION,
        "sha256": model_sha256,
        "feature_names": FEATURE_COLUMNS,
        "total_windows": len(test_cases),
        "test_cases": test_cases,
    }

    with open(output_fixture_path, "w", encoding="utf-8") as f:
        json.dump(fixture_payload, f, indent=2)

    print(f"[+] Generated 200-window parity fixture at: {output_fixture_path}")
    print(f"    Total cases: {len(test_cases)} (Clean Legit, Clean Vehicle, Edge Boundaries)")


def main():
    parser = argparse.ArgumentParser(description="Export production LightGBM model to ONNX and pure tree representations.")
    parser.add_argument("--features", default="ml/data/features_clean.parquet", help="Clean features parquet")
    parser.add_argument("--onnx-out", default="assets/models/anomaly_detector.onnx", help="Path for exported ONNX model")
    parser.add_argument("--tree-json-out", default="assets/models/anomaly_detector_trees.json", help="Path for tree JSON")
    parser.add_argument("--go-tree-json-out", default="backend/internal/anticheat/anomaly_detector_trees.json", help="Path for backend tree JSON")
    parser.add_argument("--meta-out", default="assets/models/anomaly_detector_meta.json", help="Path for model metadata JSON")
    parser.add_argument("--go-meta-out", default="backend/internal/anticheat/anomaly_detector_meta.json", help="Path for backend metadata JSON")
    parser.add_argument("--parity-out", default="test_fixtures/parity_200_windows.json", help="Path for 200-window parity fixture")
    args = parser.parse_args()

    if not os.path.exists(args.features):
        raise FileNotFoundError(f"Clean features missing at {args.features}")

    df_clean = pd.read_parquet(args.features)
    clf = train_production_lightgbm(df_clean)

    # 1. Export ONNX
    sha256_onnx = export_to_onnx(clf, args.onnx_out)

    # 2. Export Tree JSON
    trees_dict, sha256_trees = export_to_tree_json(clf, args.tree_json_out)

    # Also copy to backend directory
    os.makedirs(os.path.dirname(args.go_tree_json_out), exist_ok=True)
    with open(args.go_tree_json_out, "w", encoding="utf-8") as f:
        json.dump(trees_dict, f, indent=2)

    # 3. Export Metadata with Version & SHA256
    meta = {
        "model_name": "LightGBM Anomaly Detector",
        "model_version": MODEL_VERSION,
        "model_type": "LightGBM_Tree_Ensemble",
        "sha256_onnx": sha256_onnx,
        "sha256_trees": sha256_trees,
        "threshold": 0.5,
        "num_trees": trees_dict["num_trees"],
        "num_features": len(FEATURE_COLUMNS),
        "feature_names": FEATURE_COLUMNS,
        "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(args.meta_out, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    with open(args.go_meta_out, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"[+] Saved metadata to: {args.meta_out} and {args.go_meta_out}")

    # 4. Generate 200-window parity test fixture
    generate_parity_fixture(clf, df_clean, args.parity_out, sha256_trees, n_windows=200)

    print("\n" + "=" * 60)
    print("PRODUCTION MODEL EXPORT & FIXTURE GENERATION COMPLETE")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
