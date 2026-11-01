# Territory Runner ML Anti-Cheat Pipeline

This directory contains the machine learning subsystem for **Territory Runner**, dedicated to evaluating GPS kinematic anomaly detection and vehicle spoofing classification with empirical rigor.

---

## 1. Architecture & Design Principles

1. **Server-Audited Spatial Kinematics (Client Speeds Untrusted)**:
   - **GPS Speed Discarded**: Client-reported `speed` telemetry is intentionally ignored during feature extraction and backend evaluation. All kinematic metrics (speed, acceleration, jerk, heading change, sinuosity, stop ratio) are calculated independently on the server from raw `(latitude, longitude, timestamp)` fixes.
   - **Client-Supplied Motion Auditing**: Accelerometer cadence and motion energy are client-supplied telemetry. While a modified client can alter or omit these windows, the server executes strict sanity checks (`SanityCheckMotionWindows`) covering duration inflation, value bounds ($[0, 300]\text{ SPM}$), and bot repeat signatures.
   - **Verification States**: Runs with valid motion are marked `verified_human`. Runs with missing or implausible motion are accepted under physical rules as `unverified_motion` (territory captured, but competitive duel progress and weak-territory $1.5\times$ bonuses are restricted). Gross physics violations are `rejected`.

2. **Primary Defense vs Experimental Tier 2**:
   - **Tier 1 Physical Constraints (Primary Defense)**: Activity speed ceilings, instantaneous acceleration bounds ($\le 8.0\text{ m/s}^2$), teleportation limits, and sustained vehicle stillness heuristics ($> 6\text{ km/h}$ with zero cadence and low vibration for $> 30\text{s}$) serve as the authoritative production gate.
   - **Tier 2 ML Ensemble (Experimental / Disabled by Default)**: The LightGBM decision tree ensemble is currently experimental and disabled by default in server configuration (`EnableMLTier2: false`). It remains disabled until the minimum threshold of real team-collected app traces ($\ge 30$ traces across $\ge 3$ users) is met.

3. **Strict Dataset Hygiene & Zero Data Leakage**:
   - **Cross-Validation**: Leave-One-User-Out Cross-Validation (`LOUO-CV`) grouped by user (`GroupKFold` / `LeaveOneGroupOut`). No user trajectory ever spans across train and validation splits.
   - **Feature Truth**: Real accelerometer features are **never synthesized from ground-truth labels**. Because GeoLife lacks accelerometer logs, GeoLife benchmarks evaluate strictly on GPS-only kinematics (22 features).
   - **Adversarial Test Separation**: Synthetic cheat augmentations (sparse sampling, speed spoofing, timestamp stretching, replayed traces) are maintained **ONLY as a separate held-out test set**. They are NEVER injected into training sets.

4. **Deterministic Reproducibility (Seed Policy)**:
   - A global seed `SEED = 42` is explicitly set and propagated across Python `random`, `numpy.random`, PyTorch (`torch.manual_seed`), `scikit-learn`, and `LightGBM`.

---

## 2. Directory Layout

```
ml/
├── requirements.txt                # Pinned package versions
├── README.md                       # Subsystem specification and operational guide
├── run_pipeline.py                 # End-to-end orchestration CLI
│
├── data/
│   ├── prepare_geolife.py          # GeoLife GPS download & transport-mode preprocessor
│   ├── collect_app_traces.md       # Field collection guide for team members (20+ runs, 10+ rides)
│   ├── import_app_traces.py        # Team trace validator, importer, and threshold manifest manager
│   ├── test_trace_importer.py      # Unit tests for team trace import and validation rules
│   ├── app_traces_manifest.json    # Real trace count and cadence-model enablement status
│   ├── generate_spoofs.py          # Adversarial cheat generator (strictly held-out test set)
│   ├── app_traces/                 # Team-collected in-app JSON trace recordings (empty initially)
│   └── raw/                        # Downloaded GeoLife zip and extracted labeled users
│
├── features/
│   ├── __init__.py
│   └── extract.py                  # Windowed kinematic feature extractor (GPS-only; no label leakage)
│
├── models/
│   ├── __init__.py
│   ├── baseline.py                 # Deterministic physical ceiling rule baseline
│   ├── classical.py                # LogisticRegression & LightGBM classifiers
│   ├── neural.py                   # Lightweight PyTorch 1D-CNN + GRU model
│   └── evaluate.py                 # LOUO-CV, PR-AUC, Recall @ 1% & 5% FPR, bootstrap CIs, plots
│
└── reports/
    ├── figures/                    # PR curves, confusion matrices, calibration plots
    ├── eval.md                     # Empirical verification report generated from clean GPS-only run
    └── eval_false_positives.py     # Real false positive analysis across speed cohorts
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
   *Downloads GeoLife 1.3, extracts labeled users (010-179), audits team traces, and writes `app_traces_manifest.json`.*

2. **Import & Validate Team Traces**:
   ```bash
   python data/import_app_traces.py
   ```
   *Audits `ml/data/app_traces/` against schema, coordinates, duration ($\ge 180\text{s}$), and speed bounds. Enforces the 30-trace threshold.*

3. **Generate Adversarial Test Set (Held-Out Cheats)**:
   ```bash
   python data/generate_spoofs.py
   ```
   *Generates sparse sampling, speed-field spoofing, timestamp stretching, and replay attack test traces.*

4. **Extract Kinematic Window Features (GPS-Only)**:
   ```bash
   python features/extract.py
   ```
   *Extracts 22 real displacement features from raw lat/lon/time. Sets cadence features to NaN for GPS-only GeoLife.*

5. **Train, Cross-Validate & Evaluate Models**:
   ```bash
   python models/evaluate.py
   ```
   *Executes LOUO-CV across Rule Baseline, Logistic Regression, LightGBM, and PyTorch 1D-CNN/GRU. Computes bootstrap 95% CIs and writes `reports/eval.md`.*

6. **Evaluate Real False-Positive Behavior**:
   ```bash
   python reports/eval_false_positives.py
   ```
   *Evaluates empirical false positive rates across 50,419 legitimate human windows broken down by walking, cycling, and running speed cohorts.*

---

## 4. Evaluation Metrics

- **PR-AUC**: Area Under the Precision-Recall Curve (unbalanced class baseline).
- **Recall @ 1% FPR**: Target operating point for zero-tolerance false flag suppression.
- **Recall @ 5% FPR**: Relaxed operational surveillance threshold.
- **Per-Modality Breakdown**: Specific recall across `bus`, `car_taxi`, and `train`, and specificity on `walk_run` and `cycle`.
- **Expected Calibration Error (ECE)**: Reliability of predicted cheat probabilities.
- **Bootstrap 95% Confidence Intervals**: 1,000 empirical resamples for statistical significance.
- **Adversarial Stress Test**: Independent detection rate across the 4 spoof cheat families.
