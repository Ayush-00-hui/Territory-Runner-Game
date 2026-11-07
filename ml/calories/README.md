# Calorie Engine ML Pipeline

This directory contains the training, verification, and export pipeline for the **Territory Runner Calorie Surrogate Model**.

## Overview
Under Phase 4 of the Calorie Engine:
1. Ground-truth energy expenditure rates ($\text{kcal/min}$) are established from peer-reviewed exercise physiology (ACSM 2021 locomotion equations, Minetti et al. 2002 steep slope polynomial, Mifflin-St Jeor resting metabolic rate).
2. Realistic sensor noise distributions (GPS Doppler jitter $\sigma \approx 0.35\text{ km/h}$, altitude grade jitter $\sigma \approx 0.012$, cadence variations) are modeled based on Phase 2 empirical sensing benchmarks.
3. LightGBM Monotone Quantile Regressors are trained with monotonic constraints:
   - `body_mass_kg`: `+1` (energy expenditure never decreases with mass).
   - `speed_kmh`: `+1` (energy expenditure never decreases with speed).
   - `grade`: `+1` (energy expenditure never decreases with positive grade).
   - `climb_rate_m_min`: `+1` (energy expenditure never decreases with vertical climb rate).
4. Three quantiles are predicted:
   - `P10`: Conservative estimate (economical runner, favorable wind, downward sensor drift).
   - `P50`: Median physiological expectation.
   - `P90`: Elevated estimate (less economical runner, soft terrain, headwind, upward sensor spikes).
5. The model is exported to compact JSON decision trees (`assets/models/calorie_trees.json`) accompanied by a cryptographic SHA-256 integrity hash in `assets/models/calorie_meta.json`.
6. On-device inference in Flutter is executed using pure Dart (zero external C++ dependencies). If asset parsing or SHA-256 validation fails, it gracefully falls back to the Phase 3 analytical equations.

## Running the Training Pipeline

```bash
python ml/calories/train_calorie_surrogate.py
```

This generates:
- `assets/models/calorie_trees.json`
- `assets/models/calorie_meta.json`
- `test/assets/calorie_test_vectors.json`
- `ml/calories/report.md`

