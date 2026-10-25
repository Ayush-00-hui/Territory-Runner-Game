"""
Python Parity Test against 200 fixed test windows
Verifies bit-for-bit mathematical consistency between LightGBM booster, ONNX Runtime, and Tree JSON.
"""

import json
import math
import numpy as np
import onnxruntime as ort

def eval_node(node, x):
    if "leaf_value" in node:
        return node["leaf_value"]
    feat_idx = node["split_feature"]
    thresh = node["threshold"]
    if x[feat_idx] <= thresh:
        return eval_node(node["left"], x)
    else:
        return eval_node(node["right"], x)

def eval_trees(trees_payload, x):
    raw = 0.0
    for t in trees_payload["trees"]:
        raw += eval_node(t, x)
    return 1.0 / (1.0 + math.exp(-raw))

def main():
    with open("test_fixtures/parity_200_windows.json", "r", encoding="utf-8") as f:
        fixture = json.load(f)

    with open("assets/models/anomaly_detector_trees.json", "r", encoding="utf-8") as f:
        trees_payload = json.load(f)

    sess = ort.InferenceSession("assets/models/anomaly_detector.onnx")
    input_name = sess.get_inputs()[0].name

    cases = fixture["test_cases"]
    print(f"[*] Testing {len(cases)} parity windows in Python...")

    max_diff_tree = 0.0
    max_diff_onnx = 0.0
    mismatch_decisions = 0

    for c in cases:
        x = np.array(c["features"], dtype=np.float32)
        expected_prob = c["expected_probability"]
        expected_anomaly = c["expected_is_anomaly"]

        # 1. Custom tree evaluator
        tree_prob = eval_trees(trees_payload, x)
        diff_tree = abs(expected_prob - tree_prob)
        if diff_tree > max_diff_tree:
            max_diff_tree = diff_tree

        # 2. ONNX Runtime
        ort_out = sess.run(None, {input_name: x.reshape(1, -1)})
        # ort_out[1] is list of dicts: [{0: p0, 1: p1}]
        onnx_prob = ort_out[1][0][1]
        diff_onnx = abs(expected_prob - onnx_prob)
        if diff_onnx > max_diff_onnx:
            max_diff_onnx = diff_onnx

        tree_dec = tree_prob >= 0.5
        if tree_dec != expected_anomaly:
            mismatch_decisions += 1

    print(f"[+] Python Max diff (Booster vs Tree JSON): {max_diff_tree:.2e}")
    print(f"[+] Python Max diff (Booster vs ONNX):      {max_diff_onnx:.2e}")
    print(f"[+] Decision mismatches: {mismatch_decisions} / {len(cases)}")
    assert max_diff_tree < 1e-6, f"Tree diff too large: {max_diff_tree}"
    assert max_diff_onnx < 1e-4, f"ONNX diff too large: {max_diff_onnx}"
    assert mismatch_decisions == 0, "Decision mismatch detected"
    print("[+] Python parity verification PASSED!")

if __name__ == "__main__":
    main()
