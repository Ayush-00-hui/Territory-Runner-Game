"""
Training Script: Loop Closure Intent Classifier (ML Model)
Classifies whether a runner is actively attempting to close a territory polygon.
Used for proactive GPU shader buffer pre-warming, closure proximity radar, and tactile ticks.
"""

import json
import math
import os
import random
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, roc_auc_score, confusion_matrix

def generate_synthetic_dataset(num_samples=4000, random_seed=42):
    random.seed(random_seed)
    np.random.seed(random_seed)

    X = []
    y = []

    for _ in range(num_samples):
        # 50% loop closure trajectories, 50% linear / out-and-back / wander routes
        is_closing = random.random() < 0.5
        
        speed_kmh = random.uniform(6.0, 18.0)
        total_path_m = random.uniform(400.0, 5000.0)

        if is_closing:
            # Runner is near the end of a loop
            # Distance to origin is small compared to total path
            dist_to_origin = random.uniform(5.0, 150.0)
            closure_ratio = dist_to_origin / (total_path_m + 1.0)
            
            # Heading divergence is typically small (< 45 deg) or aligned towards origin
            heading_divergence = random.uniform(5.0, 50.0)
            
            # Path curvature is steady or curving towards start
            curvature = random.uniform(0.8, 4.5)
            
            # Aspect ratio of bounding box is balanced (~1.0 to 2.2)
            aspect_ratio = random.uniform(0.9, 2.2)
            
            # Rate of closure (closing speed in m/s)
            closing_rate = random.uniform(1.5, 4.5)
        else:
            # Runner is running away, straight, or out-and-back
            is_linear = random.random() < 0.6
            if is_linear:
                dist_to_origin = total_path_m * random.uniform(0.6, 0.98)
                closure_ratio = dist_to_origin / (total_path_m + 1.0)
                heading_divergence = random.uniform(70.0, 175.0)
                curvature = random.uniform(0.05, 0.9)
                aspect_ratio = random.uniform(2.5, 8.0)
                closing_rate = random.uniform(-4.0, 0.5)
            else:
                # Mid-loop or meandering
                dist_to_origin = random.uniform(180.0, total_path_m * 0.7)
                closure_ratio = dist_to_origin / (total_path_m + 1.0)
                heading_divergence = random.uniform(45.0, 140.0)
                curvature = random.uniform(0.2, 2.5)
                aspect_ratio = random.uniform(1.2, 4.0)
                closing_rate = random.uniform(-2.0, 1.2)

        # Add realistic sensor noise
        dist_to_origin = max(1.0, dist_to_origin + random.gauss(0, 3.0))
        closure_ratio = max(0.001, closure_ratio + random.gauss(0, 0.01))
        heading_divergence = max(0.0, min(180.0, heading_divergence + random.gauss(0, 4.0)))
        curvature = max(0.0, curvature + random.gauss(0, 0.1))
        aspect_ratio = max(0.5, aspect_ratio + random.gauss(0, 0.1))

        feature_vector = [
            round(dist_to_origin, 2),
            round(total_path_m, 2),
            round(closure_ratio, 4),
            round(heading_divergence, 2),
            round(curvature, 3),
            round(aspect_ratio, 2),
            round(speed_kmh, 2),
            round(closing_rate, 2),
        ]

        X.append(feature_vector)
        y.append(1 if is_closing else 0)

    return np.array(X), np.array(y)

def train_and_export():
    print("=" * 65)
    print("  TERRITORY RUNNER - LOOP CLOSURE INTENT ML ENGINE")
    print("  Architecture: Calibrated Gradient-Boosted Forest")
    print("=" * 65)

    feature_names = [
        "dist_to_origin_m",
        "total_path_m",
        "closure_ratio",
        "heading_divergence_deg",
        "curvature_deg_per_m",
        "aspect_ratio",
        "speed_kmh",
        "closing_rate_mps"
    ]

    print(f"\n[1/5] Synthesizing 5,000 realistic GPS athlete trajectory samples...")
    X, y = generate_synthetic_dataset(num_samples=5000)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    print(f"      Training set: {len(X_train)} samples | Validation set: {len(X_test)} samples")

    print("\n[2/5] Training Gradient-Boosted Decision Forest (20 estimators, depth=4)...")
    clf = GradientBoostingClassifier(
        n_estimators=20,
        max_depth=4,
        learning_rate=0.15,
        random_state=42
    )
    clf.fit(X_train, y_train)

    print("\n[3/5] Evaluating Model Validation Metrics:")
    y_pred = clf.predict(X_test)
    y_proba = clf.predict_proba(X_test)[:, 1]

    acc = np.mean(y_pred == y_test)
    roc_auc = roc_auc_score(y_test, y_proba)
    cm = confusion_matrix(y_test, y_pred)

    print(f"      Accuracy:  {acc * 100:.2f}%")
    print(f"      ROC-AUC:   {roc_auc:.4f}")
    print(f"      Confusion Matrix:\n        TN={cm[0][0]}  FP={cm[0][1]}\n        FN={cm[1][0]}  TP={cm[1][1]}")

    print("\n[4/5] Feature Importances:")
    importances = clf.feature_importances_
    sorted_idx = np.argsort(importances)[::-1]
    for idx in sorted_idx:
        print(f"      - {feature_names[idx]:<24}: {importances[idx] * 100:.2f}%")

    print("\n[5/5] Exporting Lightweight Inference Weights for On-Device Mobile...")
    
    # Serialize tree structure for deterministic zero-dependency Dart execution
    trees_json = []
    for stage in clf.estimators_:
        tree = stage[0].tree_
        tree_dict = {
            "children_left": tree.children_left.tolist(),
            "children_right": tree.children_right.tolist(),
            "feature": tree.feature.tolist(),
            "threshold": tree.threshold.tolist(),
            "value": tree.value.squeeze().tolist(),
        }
        trees_json.append(tree_dict)

    meta_json = {
        "model_name": "LoopClosureIntentClassifier",
        "version": "1.0.0",
        "accuracy": round(acc, 4),
        "roc_auc": round(roc_auc, 4),
        "feature_names": feature_names,
        "n_estimators": len(trees_json),
        "learning_rate": clf.learning_rate,
        "init_value": clf.init_.prior if hasattr(clf.init_, 'prior') else 0.0,
    }

    out_dir = os.path.join("assets", "models")
    os.makedirs(out_dir, exist_ok=True)

    meta_path = os.path.join(out_dir, "loop_closure_meta.json")
    trees_path = os.path.join(out_dir, "loop_closure_trees.json")

    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta_json, f, indent=2)

    with open(trees_path, "w", encoding="utf-8") as f:
        json.dump(trees_json, f)

    print(f"      SUCCESS: Model metadata exported to {meta_path}")
    print(f"      SUCCESS: Serialized trees exported to {trees_path}")
    print("=" * 65 + "\n")

if __name__ == "__main__":
    train_and_export()
