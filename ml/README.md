# Territory Runner ML Anti-Cheat Pipeline

This directory contains the machine learning subsystem for **Territory Runner**, dedicated to detecting GPS kinematic spoofing and motorized vehicle anomalies with empirical rigor.

---

## 1. Architecture & Design Principles

1. **Raw Spatial Kinematics (Zero Client Trust)**:
   - Client-reported speed telemetry is intentionally ignored during feature extraction.
   - All kinematic features (speed, acceleration, jerk, heading change, sinuosity, stop ratio) are computed directly from raw `(latitude, longitude, timestamp)` breadcrumbs.

2. **Strict Dataset Hygiene & Zero Data Leakage**:
   - **Cross-Validation**: Leave-One-User-Out Cross-Validation (`LOUO-CV`) grouped by user and session (`GroupKFold` / `LeaveOneGroupOut`). No user trajectory ever spans across train and validation splits.
   - **Adversarial Spoof Separation**: Synthetic and adversarial cheat augmentations (sparse sampling, speed-field spoofing, timestamp stretching, replayed traces with shifted offsets) are maintained **ONLY as a separate held-out test set**. They are NEVER injected into training data, preventing optimistic overfitting to synthetic artifacts.

3. **Deterministic Reproducibility (Seed Policy)**:
   - A global seed `SEED = 42` is explicitly set and propagated across Python `random`, `numpy.random`, PyTorch (`torch.manual_seed`), `scikit-learn`, and `LightGBM`.

---

## 2. Directory Layout

```
ml/
├── requirements.txt            # Pinned package versions
├── README.md                   # This specification and guide
├── run_pipeline.py             # End-to-end orchestration CLI
│
├── data/
│   ├── prepare_geolife.py      # GeoLife GPS download & transport-mode preprocessor
│   ├── collect_app_traces.md   # Field collection guide for team members (20+ runs, 10+ rides)
│   ├── generate_spoofs.py      # Adversarial cheat generator (strictly held-out test set)
│   ├── app_traces/             # Team-collected in-app JSON trace recordings
│   └── raw/                    # Downloaded GeoLife zip and extracted labeled users
│
├── features/
│   ├── __init__.py
│   └── extract.py              # Windowed kinematic feature extractor (from raw lat/lon/time)
│
├── models/
│   ├── __init__.py
│   ├── baseline.py             # Deterministic physical ceiling rule baseline
│   ├── classical.py            # LogisticRegression & LightGBM classifiers
│   ├── neural.py               # Lightweight PyTorch 1D-CNN + GRU model
│   └── evaluate.py             # LOUO-CV, PR-AUC, Recall @ 1% & 5% FPR, bootstrap CIs, plots
│
└── reports/
    ├── figures/                # PR curves, confusion matrices, calibration plots
    └── eval.md                 # Empirical verification report generated from real run numbers
```

---

## 3. Quickstart & Execution

### Setup
```bash
cd ml
pip install -r requirements.txt
```

### Full Pipeline Run (End-to-End)
```bash
# Downloads GeoLife, prepares datasets, extracts features, trains models, evaluates with LOUO-CV, and generates eval.md
python run_pipeline.py --all
```

### Step-by-Step Execution

1. **Download & Process GeoLife**:
   ```bash
   python data/prepare_geolife.py
   ```
   *Downloads GeoLife 1.3, extracts labeled users (010-179), and maps modes to `{legit_walk_run, legit_cycle, vehicle}`.*

2. **Generate Adversarial Test Set (Held-Out Cheats)**:
   ```bash
   python data/generate_spoofs.py
   ```
   *Generates sparse sampling, speed-field spoofing, timestamp stretching, and replay attack test traces.*

3. **Extract Kinematic Window Features**:
   ```bash
   python features/extract.py
   ```
   *Extracts displacement speed, acceleration, jerk, heading entropy, sinuosity, and stop ratio from raw lat/lon/time.*

4. **Train, Cross-Validate & Evaluate Models**:
   ```bash
   python models/evaluate.py
   ```
   *Executes LOUO-CV across Rule Baseline, Logistic Regression, LightGBM, and PyTorch 1D-CNN/GRU. Computes bootstrap 95% CIs, generates PR curves and confusion matrices, and writes `reports/eval.md`.*

---

## 4. Evaluation Metrics

- **PR-AUC**: Area Under the Precision-Recall Curve (unbalanced class baseline).
- **Recall @ 1% FPR**: Target operating point for zero-tolerance false flag suppression.
- **Recall @ 5% FPR**: Relaxed operational surveillance threshold.
- **Per-Modality Breakdown**: Specific recall across `bus`, `car_taxi`, and `train`, and specificity on `walk_run` and `cycle`.
- **Expected Calibration Error (ECE)**: Reliability of predicted cheat probabilities.
- **Bootstrap 95% Confidence Intervals**: 1,000 empirical resamples for statistical significance.
- **Adversarial Stress Test**: Independent detection rate across the 4 spoof cheat families.
