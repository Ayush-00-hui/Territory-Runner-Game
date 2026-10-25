"""
Classical Machine Learning Classifiers (Logistic Regression & LightGBM)
Territory Runner ML Anti-Cheat Engine

Trains and exposes:
1. LogisticRegression (standardized linear baseline with balanced class weights).
2. LightGBM (gradient boosted decision trees with histogram binning and balanced loss).
"""

from typing import Dict, List, Optional

import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

RANDOM_SEED = 42


def build_logistic_regression_model(c: float = 1.0) -> Pipeline:
    """Constructs a calibrated Logistic Regression pipeline with feature scaling."""
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(
            C=c,
            class_weight="balanced",
            random_state=RANDOM_SEED,
            max_iter=1000,
            solver="lbfgs",
        )),
    ])


def build_lightgbm_model(
    n_estimators: int = 100,
    learning_rate: float = 0.05,
    max_depth: int = 5,
    num_leaves: int = 31,
) -> lgb.LGBMClassifier:
    """Constructs a LightGBM gradient boosted decision tree classifier."""
    return lgb.LGBMClassifier(
        n_estimators=n_estimators,
        learning_rate=learning_rate,
        max_depth=max_depth,
        num_leaves=num_leaves,
        class_weight="balanced",
        random_state=RANDOM_SEED,
        verbose=-1,
        n_jobs=-1,
        min_child_samples=10,
    )
