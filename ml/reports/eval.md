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
| **Evaluated Volume** | 127,655 kinematic windows across 13 distinct user profiles |
| **Cross-Validation Scheme** | Grouped Leave-One-User-Out (`GroupKFold` by `user_id`, zero user leakage) |
| **Statistical Significance** | 1,000 bootstrap iterations (95% CI reported as `[lower, upper]`) |

## 2. Dataset Cohorts & Class Distribution

| Transport Mode | Ground Truth Category | Windows Count | % of Dataset | Distinct Users |
| :--- | :--- | :---: | :---: | :---: |
| **bus** | Anomaly (Vehicle) | 38,735 | 30.34% | 10 |
| **bike** | Legitimate | 29,161 | 22.84% | 8 |
| **train** | Anomaly (Vehicle) | 27,523 | 21.56% | 4 |
| **walk** | Legitimate | 21,240 | 16.64% | 13 |
| **taxi** | Anomaly (Vehicle) | 4,766 | 3.73% | 8 |
| **subway** | Anomaly (Vehicle) | 4,458 | 3.49% | 7 |
| **car** | Anomaly (Vehicle) | 1,618 | 1.27% | 9 |
| **airplane** | Anomaly (Vehicle) | 131 | 0.10% | 2 |
| **run** | Legitimate | 18 | 0.01% | 1 |
| **boat** | Anomaly (Vehicle) | 5 | 0.00% | 1 |

---

## 3. GPS-Only Model Benchmark Comparison (LOUO-CV)

Evaluated across 5-fold Leave-One-User-Out cross-validation using strictly 22 GPS kinematic features (zero cadence input):

| Model Architecture | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Thresh @ 1% FPR | Recall @ 5% FPR (95% CI) | Thresh @ 5% FPR | Expected Calibration Error (ECE) | Latency (µs/window) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.9248 `[0.9203, 0.9291]` | **43.17%** `[42.32%, 45.23%]` | `0.9982` | 57.29% `[55.50%, 59.37%]` | `0.8125` | 0.1334 | 29.5 µs |
| **Logistic Regression** | 0.9402 `[0.9369, 0.9433]` | **52.13%** `[47.65%, 55.86%]` | `0.9511` | 78.10% `[77.14%, 79.00%]` | `0.5214` | 0.0626 | 25.6 µs |
| **LightGBM** | 0.9485 `[0.9446, 0.9520]` | **59.50%** `[55.16%, 63.70%]` | `0.9181` | 76.53% `[75.74%, 77.47%]` | `0.7176` | 0.0567 | 34.7 µs |
| **1D-CNN + GRU** | 0.9472 `[0.9431, 0.9509]` | **62.23%** `[58.16%, 65.45%]` | `0.9183` | 79.88% `[79.12%, 80.66%]` | `0.3213` | 0.0629 | 53.6 µs |

---

## 4. Per-Modality Detection & False Positive Breakdown

Breakdown evaluated at the **1% False Positive Rate operating point** determined via cross-validation:

- **Vehicles (Positive Class)**: Recall represents true positive detection rate of motorized transit.
- **Athletic Disciplines (Negative Class)**: FPR represents false positive rejection rate of legitimate athletes.

| Modality Metric | Ground Truth Class | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :--- | :---: | :---: | :---: | :---: |
| Recall on `train` | True Positive Recall | 87.62% | 81.90% | 93.83% | 95.71% |
| FPR on `walk` | False Positive Rate | 0.89% | 1.47% | 1.64% | 1.74% |
| Recall on `taxi` | True Positive Recall | 29.27% | 37.24% | 53.44% | 52.94% |
| Recall on `bus` | True Positive Recall | 13.26% | 33.55% | 36.81% | 40.54% |
| Recall on `subway` | True Positive Recall | 48.21% | 48.41% | 55.11% | 56.46% |
| Recall on `airplane` | True Positive Recall | 9.16% | 8.40% | 35.11% | 31.30% |
| Recall on `car` | True Positive Recall | 32.51% | 48.15% | 50.37% | 57.60% |
| FPR on `bike` | False Positive Rate | 0.86% | 0.65% | 0.53% | 0.46% |
| Recall on `boat` | True Positive Recall | 80.00% | 80.00% | 80.00% | 80.00% |
| FPR on `run` | False Positive Rate | 0.00% | 0.00% | 0.00% | 0.00% |

> [!WARNING]
> **GPS-Only Urban Vehicle Blindspot**: Notice that vehicles operating at moderate speeds in urban traffic (such as urban buses and city cars in stop-and-go conditions between 10–25 km/h) have kinematics that partially overlap with athletic cycling and sprinting. Without genuine accelerometer cadence, pure GPS features cannot achieve 100% urban vehicle detection at a 1% false-positive ceiling. High-speed rail, subways, and highway cruising are detected with high recall.

---

## 5. Adversarial Cheat Stress Test (Synthetic Held-Out Suite)

> [!NOTE]
> **Adversarial Evaluation Caveat**: The attack vectors below were produced using the in-repo generator (`ml/data/generate_spoofs.py`). High detection rates on these synthetic attacks demonstrate sensitivity to the specific parameterizations of this generator (e.g. median dt thresholds, uniform speed overrides), but **do not constitute evidence of general robustness against unknown human adversaries**.

| Attack Family | Generator Mechanism | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Sparse Sampling** | median dt > 5s (8–20s gaps) | 100.0% | 86.0% | **56.0%** | 100.0% |
| **Speed-Field Telemetry Spoofing** | Client reports 2.5 m/s, coordinate delta = 50–85 km/h | 100.0% | 100.0% | **58.0%** | 100.0% |
| **Timestamp Stretching / Teleportation** | Warped timestamps or sudden position displacements | 48.0% | 48.0% | **48.0%** | 48.0% |
| **Replay Attack with Shifted Offsets** | Recorded traces shifted by geographic delta | 50.0% | 0.0% | **0.0%** | 0.0% |
| **Overall Adversarial Detection Rate** | Weighted mean across all 1,200 synthetic attack windows | 74.5% | 58.5% | **40.5%** | 62.0% |

---

## 6. Visual Artifacts & Diagnostic Curves

### Precision-Recall Curves (GPS-Only LOUO-CV)
![Precision-Recall Curves](figures/pr_curves.png)

### Calibration Reliability Diagram (GPS-Only LOUO-CV)
![Calibration Curves](figures/calibration_curves.png)

### Confusion Matrices (1% FPR Operating Point)
![Confusion Matrices](figures/confusion_matrices.png)

