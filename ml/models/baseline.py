"""
Deterministic Physical Ceiling Rule Baseline Classifier
Territory Runner ML Anti-Cheat Engine

Evaluates physical kinematics against biological human limits:
1. Activity speed ceilings (running > 24 km/h, cycling > 45 km/h, vehicle > 35 km/h avg).
2. Biomechanical acceleration ceiling (> 5.5 m/s^2).
3. Sparse sampling detection (median dt > 5.0 s).
4. Sinuosity and turn rate physics.

Produces calibrated continuous suspicion scores [0.0, 1.0] for PR-curve benchmarking.
"""

import numpy as np
import pandas as pd


class RuleBaselineClassifier:
    """Deterministic rule-based baseline evaluator."""

    def __init__(
        self,
        speed_ceiling_kmh: float = 24.0,
        speed_avg_ceiling_kmh: float = 20.0,
        accel_ceiling_ms2: float = 5.5,
        sparse_sampling_dt_s: float = 5.0,
    ):
        self.speed_ceiling_kmh = speed_ceiling_kmh
        self.speed_avg_ceiling_kmh = speed_avg_ceiling_kmh
        self.accel_ceiling_ms2 = accel_ceiling_ms2
        self.sparse_sampling_dt_s = sparse_sampling_dt_s

    def fit(self, X, y=None):
        """Stateless deterministic baseline (no-op)."""
        return self

    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        """Computes continuous suspicion score in [0.0, 1.0]."""
        if isinstance(X, pd.DataFrame):
            df = X
        else:
            raise ValueError("Input must be a pandas DataFrame containing kinematic features.")

        scores = []
        for _, row in df.iterrows():
            penalty = 0.0

            # 1. Speed ceiling violations
            p95_speed = row.get("speed_p95_kmh", 0.0)
            avg_speed = row.get("speed_mean_kmh", 0.0)

            if p95_speed > self.speed_ceiling_kmh:
                overshoot = (p95_speed - self.speed_ceiling_kmh) / 20.0
                penalty += 1.5 * min(2.0, overshoot)

            if avg_speed > self.speed_avg_ceiling_kmh:
                overshoot = (avg_speed - self.speed_avg_ceiling_kmh) / 15.0
                penalty += 2.0 * min(2.5, overshoot)

            # 2. Acceleration ceiling violation
            max_accel = row.get("accel_max_ms2", 0.0)
            if max_accel > self.accel_ceiling_ms2:
                overshoot = (max_accel - self.accel_ceiling_ms2) / 4.0
                penalty += 1.2 * min(2.0, overshoot)

            # 3. Sparse sampling penalty
            median_dt = row.get("dt_median_s", 1.0)
            if median_dt > self.sparse_sampling_dt_s:
                overshoot = (median_dt - self.sparse_sampling_dt_s) / 5.0
                penalty += 1.5 * min(2.0, overshoot)

            # 4. Highway straight-line movement (low sinuosity + high speed)
            sinuosity = row.get("sinuosity", 1.0)
            if avg_speed > 30.0 and sinuosity < 1.08:
                penalty += 1.0

            # 5. Accelerometer cadence & motion energy rule:
            # GPS speed > 6 km/h with near-zero cadence (< 35 SPM) and low motion energy (< 0.25) => strong vehicle signal
            cadence = row.get("cadence_spm", None)
            energy = row.get("motion_energy", None)
            if cadence is not None and energy is not None:
                if avg_speed > 6.0 and cadence < 35.0 and energy < 0.25:
                    overshoot = (avg_speed - 6.0) / 10.0
                    penalty += 3.0 + min(2.5, overshoot)

            # Sigmoid conversion to probability in [0.0, 1.0]
            prob = 1.0 / (1.0 + np.exp(-1.5 * (penalty - 1.2)))
            scores.append(prob)

        probs = np.array(scores, dtype=np.float64)
        return np.column_stack([1.0 - probs, probs])

    def predict(self, X: pd.DataFrame, threshold: float = 0.5) -> np.ndarray:
        """Binary predictions against decision threshold."""
        prob_anomaly = self.predict_proba(X)[:, 1]
        return (prob_anomaly >= threshold).astype(int)
