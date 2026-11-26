# Machine Learning Anti-Cheat GPS Anomaly Detection: Evaluation Report (GPS-Only)

> [!NOTE]
> **Evaluation Scope & Integrity Disclosure**: This report contains cross-validation results produced strictly on public labeled GPS trajectories from the Microsoft Research GeoLife dataset. **Zero accelerometer features were synthesized from labels.** Because the GeoLife dataset does not contain accelerometer data and 0 validated team-collected app traces are present in the repository, all models evaluated here operate strictly on **GPS kinematic telemetry**. The accelerometer cadence model is disabled.

## 1. Provenance & Feature Status Disclosure

| Attribute | Status / Specification |
| :--- | :--- |
| **Primary Data Source** | Microsoft Research GeoLife Trajectories 1.3 (Public GNSS benchmark) |
| **Team-Collected App Traces** | **0 traces** (directory `ml/data/app_traces/` contains no validated logs) |
| **Evaluated Features (GPS-Only)** | **22 kinematic features** (speed stats, accel stats, jerk stats, heading rates, entropy, sinuosity, stop ratio, accuracy stats, dt regularity) |
| **Real Features** | **22 / 22 (100%)** — computed strictly from raw `(latitude, longitude, timestamp)` |
| **Simulated / Synthesized Features** | **0 (0%)** — prior label-to-cadence synthesis has been completely eliminated |
| **Accelerometer Cadence Model** | **DISABLED** — requires real synchronized accelerometer logs (see Task M2) |
| **Evaluated Volume** | 311,383 kinematic windows across 61 distinct user profiles |
| **Cross-Validation Scheme** | Grouped Leave-One-User-Out (`GroupKFold` by `user_id`, zero user leakage) |
| **Statistical Significance** | 1,000 bootstrap iterations (95% CI reported as `[lower, upper]`) |

## 2. Dataset Cohorts & Class Distribution

| Transport Mode | Ground Truth Category | Windows Count | % of Dataset | Distinct Users |
| :--- | :--- | :---: | :---: | :---: |
| **walk** | Legitimate | 83,663 | 26.87% | 57 |
| **bus** | Anomaly (Vehicle) | 76,964 | 24.72% | 39 |
| **bike** | Legitimate | 49,615 | 15.93% | 30 |
| **train** | Anomaly (Vehicle) | 36,877 | 11.84% | 13 |
| **car** | Anomaly (Vehicle) | 32,529 | 10.45% | 35 |
| **subway** | Anomaly (Vehicle) | 17,458 | 5.61% | 25 |
| **taxi** | Anomaly (Vehicle) | 13,306 | 4.27% | 29 |
| **airplane** | Anomaly (Vehicle) | 595 | 0.19% | 5 |
| **boat** | Anomaly (Vehicle) | 229 | 0.07% | 4 |
| **run** | Legitimate | 127 | 0.04% | 3 |
| **motorcycle** | Anomaly (Vehicle) | 20 | 0.01% | 2 |

---

## 3. GPS-Only Model Benchmark Comparison (LOUO-CV)

Evaluated across 5-fold Leave-One-User-Out cross-validation using strictly 22 GPS kinematic features (zero cadence input):

| Model Architecture | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Thresh @ 1% FPR | Recall @ 5% FPR (95% CI) | Thresh @ 5% FPR | Expected Calibration Error (ECE) | Latency (µs/window) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.9129 `[0.9082, 0.9170]` | **39.17%** `[37.18%, 40.47%]` | `0.9985` | 53.61% `[52.48%, 54.67%]` | `0.8582` | 0.1285 | 26.2 µs |
| **Logistic Regression** | 0.9377 `[0.9339, 0.9412]` | **47.18%** `[42.63%, 52.13%]` | `0.9668` | 79.37% `[78.30%, 80.38%]` | `0.5216` | 0.0493 | 24.4 µs |
| **LightGBM** | 0.9456 `[0.9421, 0.9488]` | **55.36%** `[51.21%, 59.90%]` | `0.9450` | 81.20% `[80.32%, 81.99%]` | `0.5394` | 0.0352 | 8.9 µs |
| **1D-CNN + GRU** | 0.9361 `[0.9324, 0.9395]` | **52.85%** `[48.31%, 57.14%]` | `0.9364` | 79.14% `[78.08%, 80.08%]` | `0.5287` | 0.0378 | 4.3 µs |

---

## 4. Per-Modality Detection & False Positive Breakdown

Breakdown evaluated at the **1% False Positive Rate operating point** determined via cross-validation:

- **Vehicles (Positive Class)**: Recall represents true positive detection rate of motorized transit.
- **Athletic Disciplines (Negative Class)**: FPR represents false positive rejection rate of legitimate athletes.

| Modality Metric | Ground Truth Class | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :--- | :---: | :---: | :---: | :---: |
| Recall on `train` | True Positive Recall | 86.60% | 79.22% | 92.80% | 93.89% |
| FPR on `walk` | False Positive Rate | 1.04% | 1.17% | 1.21% | 1.16% |
| Recall on `taxi` | True Positive Recall | 38.17% | 48.42% | 60.78% | 56.86% |
| Recall on `bus` | True Positive Recall | 11.44% | 26.18% | 31.04% | 30.27% |
| Recall on `subway` | True Positive Recall | 56.20% | 59.16% | 60.80% | 59.18% |
| Recall on `airplane` | True Positive Recall | 62.02% | 61.34% | 56.13% | 66.05% |
| Recall on `car` | True Positive Recall | 41.96% | 53.46% | 65.46% | 54.65% |
| FPR on `bike` | False Positive Rate | 0.93% | 0.71% | 0.64% | 0.73% |
| Recall on `boat` | True Positive Recall | 31.88% | 32.75% | 31.44% | 32.75% |
| FPR on `run` | False Positive Rate | 0.00% | 0.00% | 0.00% | 0.00% |
| Recall on `motorcycle` | True Positive Recall | 0.00% | 10.00% | 50.00% | 45.00% |

> [!WARNING]
> **GPS-Only Urban Vehicle Blindspot**: Notice that vehicles operating at moderate speeds in urban traffic (such as urban buses and city cars in stop-and-go conditions between 10–25 km/h) have kinematics that partially overlap with athletic cycling and sprinting. Without genuine accelerometer cadence, pure GPS features cannot achieve 100% urban vehicle detection at a 1% false-positive ceiling. High-speed rail, subways, and highway cruising are detected with high recall.

---

## 5. Adversarial Cheat Stress Test (Synthetic Held-Out Suite)

> [!NOTE]
> **Adversarial Evaluation Caveat**: The attack vectors below were produced using the in-repo generator (`ml/data/generate_spoofs.py`). High detection rates on these synthetic attacks demonstrate sensitivity to the specific parameterizations of this generator (e.g. median dt thresholds, uniform speed overrides), but **do not constitute evidence of general robustness against unknown human adversaries**.

| Attack Family | Generator Mechanism | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Sparse Sampling** | median dt > 5s (8–20s gaps) | 100.0% | 52.0% | **100.0%** | 100.0% |
| **Speed-Field Telemetry Spoofing** | Client reports 2.5 m/s, coordinate delta = 50–85 km/h | 100.0% | 96.0% | **44.0%** | 100.0% |
| **Timestamp Stretching / Teleportation** | Warped timestamps or sudden position displacements | 48.0% | 0.0% | **48.0%** | 28.0% |
| **Replay Attack with Shifted Offsets** | Recorded traces shifted by geographic delta | 50.0% | 0.0% | **0.0%** | 0.0% |
| **Overall Adversarial Detection Rate** | Weighted mean across all 1,200 synthetic attack windows | 74.5% | 37.0% | **48.0%** | 57.0% |

---

## 6. Visual Artifacts & Diagnostic Curves

### Precision-Recall Curves (GPS-Only LOUO-CV)
![Precision-Recall Curves](figures/pr_curves.png)

### Calibration Reliability Diagram (GPS-Only LOUO-CV)
![Calibration Curves](figures/calibration_curves.png)

### Confusion Matrices (1% FPR Operating Point)
![Confusion Matrices](figures/confusion_matrices.png)

