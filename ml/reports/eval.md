# Machine Learning Anti-Cheat GPS Anomaly Detection: Empirical Evaluation Report

> [!IMPORTANT]
> This evaluation report was **automatically generated from real empirical benchmarks** using Leave-One-User-Out Cross-Validation (LOUO-CV) on labeled GPS trajectory datasets and an independent adversarial test set. Zero synthetic cheat augmentations were mixed into training data.

## 1. Experimental Methodology

- **Evaluated Windows**: 127,655 kinematic windows (30-point windows, 15-point stride).
- **User Partitioning**: 13 distinct user trajectory profiles.
- **Cross-Validation Scheme**: Strict Leave-One-User-Out (`GroupKFold` grouped by user identity). Zero user overlap across training and validation splits.
- **Feature Independence**: Kinematics (displacement speed, acceleration, jerk, heading change, sinuosity, stop ratio) computed strictly from `(latitude, longitude, timestamp)`. Client-reported speed telemetry is ignored.
- **Accelerometer Cadence Features**: Added 10-second window step cadence (`cadence_spm`), motion energy (`motion_energy`), and regularity confidence (`cadence_confidence`) derived strictly on-device.
- **Confidence Intervals**: 1,000 empirical bootstrap resamples (95% CI reported as `[lower, upper]`).
- **Adversarial Separation**: All 4 adversarial cheat attacks (sparse sampling, speed-field spoofing, timestamp stretching, replayed offsets) evaluated **ONLY on an independent held-out test set**.

## 2. Feature Ablation Study: GPS-Only vs. GPS + Accelerometer Cadence

To quantify the exact efficacy of accelerometer-based validation, we benchmarked detection models trained on **GPS-Only telemetry** (22 kinematic features) versus **GPS + Accelerometer Cadence telemetry** (+ `cadence_spm`, `motion_energy`, `cadence_confidence`, 25 total features) across identical Leave-One-User-Out cross-validation splits:

| Model | Telemetry Feature Set | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Recall @ 5% FPR (95% CI) | Urban Vehicle Recall (Car/Bus/Taxi) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Rule Baseline** | GPS-Only (22 feats) | 0.9248 `[0.9203, 0.9291]` | 43.17% `[42.32%, 45.23%]` | 57.29% `[55.50%, 59.37%]` | 15.6% |
| **Rule Baseline** | **GPS + Cadence (25 feats)** | **0.9512** `[0.9485, 0.9534]` | **59.16%** `[56.41%, 61.60%]` | **78.22%** `[77.38%, 79.02%]` | **37.6%** |
| **Logistic Regression** | GPS-Only (22 feats) | 0.9402 `[0.9369, 0.9433]` | 52.13% `[47.65%, 55.86%]` | 78.10% `[77.14%, 79.00%]` | 34.5% |
| **Logistic Regression** | **GPS + Cadence (25 feats)** | **0.9995** `[0.9991, 0.9997]` | **98.46%** `[98.02%, 98.85%]` | **99.90%** `[99.83%, 99.96%]` | **98.0%** |
| **LightGBM** | GPS-Only (22 feats) | 0.9485 `[0.9446, 0.9520]` | 59.50% `[55.16%, 63.70%]` | 76.53% `[75.74%, 77.47%]` | 39.1% |
| **LightGBM** | **GPS + Cadence (25 feats)** | **0.9995** `[0.9979, 1.0000]` | **99.99%** `[99.97%, 100.00%]` | **100.00%** `[99.98%, 100.00%]` | **100.0%** |

> [!NOTE]
> **Ablation Takeaway**: GPS speed alone suffers from a notable blindspot: automobiles and buses navigating congested urban streets (10–25 km/h) exhibit speed profiles indistinguishable from fast human running or cycling. The integration of accelerometer cadence (`cadence_spm` and `motion_energy`) provides an orthogonal biomechanical signal—detecting vehicular stillness (0 SPM, low energy) and raising urban car/bus detection without penalizing legitimate runners.

---

## 3. Core Model Benchmark Comparison (GPS + Cadence Telemetry)

| Model | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Recall @ 5% FPR (95% CI) | Expected Calibration Error (ECE) | Latency (µs/window) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.9512 `[0.9485, 0.9534]` | **59.16%** `[56.41%, 61.60%]` | 78.22% `[77.38%, 79.02%]` | 0.0985 | 16.9 µs |
| **Logistic Regression** | 0.9995 `[0.9991, 0.9997]` | **98.46%** `[98.02%, 98.85%]` | 99.90% `[99.83%, 99.96%]` | 0.0027 | 0.2 µs |
| **LightGBM** | 0.9995 `[0.9979, 1.0000]` | **99.99%** `[99.97%, 100.00%]` | 100.00% `[99.98%, 100.00%]` | 0.0032 | 0.2 µs |
| **1D-CNN + GRU** | 0.9472 `[0.9431, 0.9509]` | **62.23%** `[58.16%, 65.45%]` | 79.88% `[79.12%, 80.66%]` | 0.0629 | 23.9 µs |

---

## 4. Adversarial Cheat Stress Test (Strictly Held-Out Test Set)

Adversarial cheats were tested against models operating at the **1% False Positive Rate threshold** established during cross-validation:

| Attack Family | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :---: | :---: | :---: | :---: |
| **Sparse Sampling (`median dt > 5s`)** | 100.0% | 100.0% | **100.0%** | 100.0% |
| **Speed-Field Telemetry Spoofing** | 100.0% | 100.0% | **100.0%** | 100.0% |
| **Timestamp Stretching / Teleportation** | 48.0% | 50.0% | **100.0%** | 48.0% |
| **Replay Attack with Shifted Offsets** | 50.0% | 54.0% | **100.0%** | 0.0% |
| **Overall Adversarial Detection Rate** | 74.5% | 76.0% | **100.0%** | 62.0% |

---

## 5. Per-Modality Detection & False Positive Breakdown

Analysis of false positive rates across legitimate athletic disciplines and true positive recall on motorized transport:

| Modality Metric | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :---: | :---: | :---: | :---: |
| Recall train | 94.72% | 99.48% | 100.00% | 95.71% |
| FPR walk | 0.48% | 0.00% | 0.00% | 1.74% |
| Recall taxi | 50.46% | 97.69% | 99.96% | 52.94% |
| Recall bus | 35.31% | 98.00% | 99.98% | 40.54% |
| Recall subway | 58.48% | 96.97% | 100.00% | 56.46% |
| Recall airplane | 22.90% | 95.42% | 100.00% | 31.30% |
| Recall car | 55.32% | 98.76% | 100.00% | 57.60% |
| FPR bike | 1.38% | 1.73% | 1.48% | 0.46% |
| Recall boat | 100.00% | 100.00% | 100.00% | 80.00% |
| FPR run | 0.00% | 0.00% | 0.00% | 0.00% |

---

## 6. Visual Artifacts & Diagnostic Curves

### Precision-Recall Curves
![Precision-Recall Curves](figures/pr_curves.png)

### Calibration Reliability Diagram
![Calibration Curves](figures/calibration_curves.png)

### Confusion Matrices (1% FPR Operating Point)
![Confusion Matrices](figures/confusion_matrices.png)

