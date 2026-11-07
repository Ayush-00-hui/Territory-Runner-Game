# Territory Runner Calorie Surrogate Model Evaluation Report

- **Model Version**: `1.0.0`
- **Model SHA-256**: `6ef0429cf529b8267a635631ffec9e3bab027423f1376519739eda47071037e4`
- **Architecture**: Monotone-Constrained LightGBM Quantile Regressors (P10, P50, P90)
- **Purpose**: Fast, noise-robust on-device estimation with honest uncertainty intervals.

## 1. Global Performance Metrics

| Metric | Surrogate Model (P50) | Legacy Flat Factor Baseline | Relative Improvement |
| :--- | :--- | :--- | :--- |
| **MAE (kcal/min)** | 1.387 | 3.486 | 60.2% |
| **MAPE (%)** | 26.69% | 50.42% | 47.1% |
| **Mean Bias (kcal/min)** | -0.048 | -0.317 | N/A |
| **[P10, P90] Coverage** | 81.46% | N/A (single point) | Ideal: 80.0% |
| **Mean Interval Width** | 7.310 kcal/min | N/A | Balanced uncertainty |

## 2. Stratified Performance Breakdown

| Stratum Category | Band | N (Test Samples) | Surrogate MAE (kcal/min) | Legacy Flat MAE (kcal/min) | Error Reduction |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Speed Band | Rest (0 km/h) | 315 | 1.370 | 0.000 | **-13698.0%** |
| Speed Band | Walk (0.5 - 6.5 km/h) | 1761 | 1.006 | 2.578 | **61.0%** |
| Speed Band | Jog (6.5 - 10 km/h) | 1389 | 1.105 | 3.508 | **68.5%** |
| Speed Band | Run (10 - 15 km/h) | 1701 | 1.507 | 4.813 | **68.7%** |
| Speed Band | Fast (> 15 km/h) | 805 | 2.458 | 3.993 | **38.4%** |
| Grade Band | Steep Descent (< -6%) | 1447 | 1.231 | 4.692 | **73.8%** |
| Grade Band | Mild Descent (-6% to -1%) | 1149 | 1.285 | 2.223 | **42.2%** |
| Grade Band | Level (-1% to +1%) | 753 | 1.362 | 0.478 | **-185.2%** |
| Grade Band | Mild Ascent (+1% to +6%) | 1136 | 1.531 | 2.333 | **34.4%** |
| Grade Band | Steep Ascent (> +6%) | 1486 | 1.519 | 5.694 | **73.3%** |
| Body Mass Band | Light (< 55 kg) | 833 | 1.440 | 2.248 | **35.9%** |
| Body Mass Band | Standard (55 - 85 kg) | 3836 | 1.207 | 3.455 | **65.1%** |
| Body Mass Band | Heavy (> 85 kg) | 1302 | 1.882 | 4.368 | **56.9%** |

## 3. Scientific Disclaimers & Methodology

1. **Surrogate Nature**: As stated in `docs/CALORIES.md`, this model does NOT claim to represent new ground truth over direct laboratory indirect calorimetry. Instead, it is an efficient, noise-resilient surrogate trained against peer-reviewed ACSM and Minetti physiological equations while absorbing GPS Doppler jitter and altitude noise.
2. **Monotonicity Enforcement**: The model is strictly constrained (`monotone_constraints=[1, 1, 1, 0, 1]`) to guarantee that energy burn rate never decreases as body mass increases, speed increases, or incline increases.
3. **Non-Crossing Quantiles**: The runtime inference pipeline mathematically enforces `P10 <= P50 <= P90` on all evaluations.
