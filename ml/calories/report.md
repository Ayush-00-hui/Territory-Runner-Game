# Territory Runner Calorie Surrogate Model Evaluation Report

- **Model Version**: `1.0.0`
- **Model SHA-256**: `d00dfa749a3b306c6ff22a738573782b012b723f2006e4b0014a90360615da84`
- **Architecture**: Monotone-Constrained LightGBM Quantile Regressors (P10, P50, P90)
- **Purpose**: Fast, noise-robust on-device estimation with honest uncertainty intervals.

## 1. Global Performance Metrics

| Metric | Surrogate Model (P50) | Legacy Flat Factor Baseline | Relative Improvement |
| :--- | :--- | :--- | :--- |
| **MAE (kcal/min)** | 0.764 | 3.518 | 78.3% |
| **MAPE (%)** | 13.43% | 50.96% | 73.6% |
| **Mean Bias (kcal/min)** | -0.001 | -0.308 | N/A |
| **[P10, P90] Coverage** | 83.35% | N/A (single point) | Ideal: 80.0% |
| **Mean Interval Width** | 4.608 kcal/min | N/A | Balanced uncertainty |

## 2. Stratified Performance Breakdown

| Stratum Category | Band | N (Test Samples) | Surrogate MAE (kcal/min) | Legacy Flat MAE (kcal/min) | Error Reduction |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Speed Band | Rest (0 km/h) | 1430 | 0.466 | 0.000 | **-4658.0%** |
| Speed Band | Walk (0.5 - 6.5 km/h) | 5608 | 0.524 | 2.536 | **79.3%** |
| Speed Band | Jog (6.5 - 10 km/h) | 3525 | 0.688 | 3.669 | **81.2%** |
| Speed Band | Run (10 - 15 km/h) | 4780 | 0.896 | 5.332 | **83.2%** |
| Speed Band | Fast (> 15 km/h) | 2555 | 1.316 | 4.039 | **67.4%** |
| Grade Band | Steep Descent (< -6%) | 4550 | 0.624 | 4.713 | **86.8%** |
| Grade Band | Mild Descent (-6% to -1%) | 3134 | 0.825 | 2.220 | **62.8%** |
| Grade Band | Level (-1% to +1%) | 2681 | 0.641 | 0.319 | **-100.8%** |
| Grade Band | Mild Ascent (+1% to +6%) | 3055 | 0.815 | 2.238 | **63.6%** |
| Grade Band | Steep Ascent (> +6%) | 4478 | 0.904 | 6.000 | **84.9%** |
| Body Mass Band | Light (< 55 kg) | 2553 | 0.811 | 2.308 | **64.8%** |
| Body Mass Band | Standard (55 - 85 kg) | 11614 | 0.661 | 3.414 | **80.6%** |
| Body Mass Band | Heavy (> 85 kg) | 3731 | 1.054 | 4.669 | **77.4%** |

## 3. Scientific Disclaimers & Methodology

1. **Surrogate Nature**: As stated in `docs/CALORIES.md`, this model does NOT claim to represent new ground truth over direct laboratory indirect calorimetry. Instead, it is an efficient, noise-resilient surrogate trained against peer-reviewed ACSM and Minetti physiological equations while absorbing GPS Doppler jitter and altitude noise.
2. **Monotonicity Enforcement**: The model is strictly constrained (`monotone_constraints=[1, 1, 1, 0, 1]`) to guarantee that energy burn rate never decreases as body mass increases, speed increases, or incline increases.
3. **Non-Crossing Quantiles**: The runtime inference pipeline mathematically enforces `P10 <= P50 <= P90` on all evaluations.
