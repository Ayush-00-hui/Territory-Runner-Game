"""
Master Pipeline Orchestration Runner
Territory Runner ML Anti-Cheat Subsystem

Executes the end-to-end ML workflow:
1. Data: Download and prepare GeoLife GPS trajectories + merge team app traces.
2. Spoofs: Generate adversarial cheat augmentations strictly as a held-out test set.
3. Features: Extract kinematic window features directly from raw (lat, lon, time).
4. Models & Evaluation: Run LOUO-CV across Rule Baseline, Logistic Regression,
   LightGBM, and PyTorch 1D-CNN+GRU. Compute bootstrap CIs, calibration, and output
   real figures and ml/reports/eval.md.
"""

import argparse
import os
import random
import sys
import time

import numpy as np

# Enforce deterministic seed across the entire process
RANDOM_SEED = 42
os.environ["PYTHONHASHSEED"] = str(RANDOM_SEED)
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from ml.data.generate_spoofs import generate_adversarial_test_set
from ml.data.prepare_geolife import prepare_dataset
from ml.features.extract import extract_features_from_dataframe
from ml.models.evaluate import run_full_evaluation



def main():
    parser = argparse.ArgumentParser(description="End-to-end ML Anti-Cheat Pipeline Runner.")
    parser.add_argument("--all", action="store_true", help="Run the complete end-to-end pipeline")
    parser.add_argument("--prepare", action="store_true", help="Download and prepare GeoLife dataset")
    parser.add_argument("--generate-spoofs", action="store_true", help="Generate adversarial cheat test set")
    parser.add_argument("--extract-features", action="store_true", help="Extract kinematic window features")
    parser.add_argument("--evaluate", action="store_true", help="Train, cross-validate and evaluate models")
    parser.add_argument("--max-users", type=int, default=15, help="Maximum GeoLife labeled users to process (default: 15 for fast high-quality benchmark)")
    parser.add_argument("--raw-dir", default="ml/data/raw", help="Directory for raw data")
    parser.add_argument("--app-traces-dir", default="ml/data/app_traces", help="Directory for team app traces")
    parser.add_argument("--processed-data", default="ml/data/processed_trajectories.parquet", help="Path for processed trajectories")
    parser.add_argument("--adversarial-data", default="ml/data/adversarial_test_set.parquet", help="Path for adversarial test set")
    parser.add_argument("--features-output", default="ml/data/features_clean.parquet", help="Path for clean features")
    parser.add_argument("--sequences-output", default="ml/data/sequences_clean.npy", help="Path for sequence tensors")
    parser.add_argument("--report-output", default="ml/reports/eval.md", help="Path for generated evaluation report")
    parser.add_argument("--figures-dir", default="ml/reports/figures", help="Directory for generated figures")
    args = parser.parse_args()

    # If no specific stage specified, default to running all
    if not (args.prepare or args.generate_spoofs or args.extract_features or args.evaluate or args.all):
        args.all = True

    t_start = time.time()
    print("=" * 70)
    print("  TERRITORY RUNNER — ML ANTI-CHEAT PIPELINE EXECUTION")
    print(f"  Random Seed: {RANDOM_SEED} (Strict Determinism)")
    print("=" * 70)

    # Stage 1: Data Preparation
    if args.prepare or args.all:
        print("\n>>> STAGE 1: Data Preparation & GeoLife Ingestion")
        prepare_dataset(
            raw_dir=args.raw_dir,
            output_path=args.processed_data,
            app_traces_dir=args.app_traces_dir,
            max_users=args.max_users,
        )

    # Stage 2: Adversarial Spoofs (Strictly Held-Out)
    if args.generate_spoofs or args.all:
        print("\n>>> STAGE 2: Adversarial Spoof Generation (Held-Out Test Set)")
        generate_adversarial_test_set(
            output_path=args.adversarial_data,
            sessions_per_attack=25,
            points_per_session=50,
        )

    # Stage 3: Feature Extraction
    if args.extract_features or args.all:
        print("\n>>> STAGE 3: Kinematic Window Feature Extraction (From Raw Lat/Lon/Time)")
        import pandas as pd
        if not os.path.exists(args.processed_data):
            raise FileNotFoundError(f"Processed trajectories not found: {args.processed_data}")
        df_traj = pd.read_parquet(args.processed_data)
        feat_df, seq_arr = extract_features_from_dataframe(df_traj, window_size=30, stride=15)

        os.makedirs(os.path.dirname(args.features_output), exist_ok=True)
        feat_df.to_parquet(args.features_output, index=False)
        np.save(args.sequences_output, seq_arr)
        print(f"[+] Saved clean tabular features to: {args.features_output}")
        print(f"[+] Saved clean sequence tensors to: {args.sequences_output} (shape: {seq_arr.shape})")

    # Stage 4: Models & Evaluation
    if args.evaluate or args.all:
        print("\n>>> STAGE 4: Model Training, LOUO-CV, Bootstrap CIs & Report Generation")
        run_full_evaluation(
            features_clean_path=args.features_output,
            sequences_clean_path=args.sequences_output,
            adversarial_path=args.adversarial_data,
            report_output=args.report_output,
            figures_dir=args.figures_dir,
            n_splits=5,
        )

    elapsed = time.time() - t_start
    print("\n" + "=" * 70)
    print(f"  PIPELINE EXECUTION COMPLETE in {elapsed:.1f}s")
    print(f"  Evaluation Report: {args.report_output}")
    print(f"  Figures Directory: {args.figures_dir}")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
