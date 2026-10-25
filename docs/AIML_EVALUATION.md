# GPS Trace Quality & Kinematic Anomaly Detection — AIML Technical Dossier

> **Specification & Empirical Evaluation**  
> **Model Version**: `3.0.0` (Production LightGBM 25-Feature Ensemble & ONNX Dual-Target)  
> **Quantile Regressor Version**: `1.0.0` (Triple-Quantile Pace & Distance Pinball Ensemble)  
> **Evaluation Protocol**: Leave-One-User-Out Grouped Cross-Validation (LOUO-CV) & Forward Temporal Splits  

---

## 1. Problem Formulation

In a location-based territory conquest engine, runner GPS coordinates dictate physical territory ownership, leaderboard rankings, and competitive duel outcomes. The anti-cheat subsystem evaluates incoming trajectory breadcrumbs to classify windows as legitimate human athletic effort or non-compliant transport/manipulation.

### Primary Objectives
- **Sub-Microsecond Deterministic Gate (Tier 1)**: Reject gross physical impossibilities (instant velocity, teleportation, mock flags) with zero memory allocations.
- **Microsecond Kinematic Ensemble (Tier 2)**: Classify complex, subtle transit patterns (urban vehicle transit, cadence mismatch) using decision tree ensembles compiled into native code (pure Go and pure Dart).
- **Quantile Athletic Progression**: Predict personalized $[p_{10}, p_{50}, p_{90}]$ performance intervals for achievable distance and pace using pinball loss optimization on sequential user history.

---

## 2. Data Sources & Provenance

The evaluation and training pipelines utilize three distinct data sources:

| Data Source | Modalities / Classes | Volume & Scope | Ingestion & Usage |
| :--- | :--- | :--- | :--- |
| **Microsoft GeoLife GNSS Dataset** | Walk, Run, Bike, Bus, Car, Taxi, Subway, Train | 182 distinct users, 17,621 trajectories, 1,200,000+ km, 24M raw points | Primary real-world multimodal baseline. Filtered into 127,655 fixed 30-second sliding windows (stride 15s). |
| **Synchronized IMU Activity Logs** | Outdoor Running, Trail Running, Track Intervals, Walking, Cycling | 13 test participants, 1,195 validated athletic sessions with continuous 25 Hz accelerometer logging | Supplies synchronized `cadence_spm`, `motion_energy`, and `cadence_confidence` features paired with raw GNSS fixes. |
| **Adversarial Spoof Suite** | Sparse Sampling, Speed Override, Timestamp Dilation, Offset Replay | 1,200 synthetically generated adversarial attack windows | Strictly held-out evaluation set. **Excluded from training** to evaluate generalization against zero-day manipulation. |

---

## 3. Data Partitioning & Split Methodology

### 3.1 Kinematic Anomaly Classifier (Leave-One-User-Out Cross-Validation)
- **Grouping Unit**: `user_id`.
- **Methodology**: 5-fold `GroupKFold` ensuring that all windows from any individual user reside strictly in either the training set or the validation set.
- **Rationale**: Trajectory shapes, stride cadence, and commuter routes exhibit high intra-subject correlation. Standard uniform random shuffling leaks individual movement signatures across splits and produces artificially deflated test error. Grouping by `user_id` measures true out-of-sample generalization across unseen humans.
- **Statistical Significance**: All reported metrics include 95% empirical bootstrap confidence intervals computed across 1,000 resamples.

### 3.2 Pace & Distance Quantile Regressors (Forward Temporal Splitting)
- **Grouping Unit**: Chronological run history per athlete.
- **Methodology**: For each athlete with $N \ge 5$ runs:
  - **Training Partition**: Earliest $75\%$ of sequential sessions (846 cumulative windows across 13 users).
  - **Held-Out Test Partition**: Latest $25\%$ of forward-looking sessions (288 evaluation windows).
- **Rationale**: Athletic adaptations (cardiovascular efficiency, endurance base, rest recovery) evolve monotonically over time. Randomly partitioning historical runs allows future training sessions to predict past sessions (temporal lookahead bias). Sequential forward partitioning guarantees that predictions reflect real-world deployment conditions.

---

## 4. Empirical Evaluation Tables (Numbers Only)

### 4.1 Cross-Validation Benchmark (GPS + Cadence Telemetry, 25 Features)

| Model Architecture | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Recall @ 5% FPR (95% CI) | Expected Calibration Error (ECE) | Latency (µs/window) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.8124 `[0.8012, 0.8236]` | 41.20% `[39.80%, 42.60%]` | 58.40% `[56.90%, 59.80%]` | 0.1240 | 0.05 µs |
| **Logistic Regression** | 0.8945 `[0.8850, 0.9038]` | 62.10% `[60.50%, 63.70%]` | 78.30% `[76.80%, 79.70%]` | 0.0612 | 1.20 µs |
| **LightGBM (60 Trees)** | 0.9782 `[0.9721, 0.9840]` | 84.30% `[82.90%, 85.70%]` | 92.15% `[91.10%, 93.20%]` | 0.0318 | 7.52 µs |
| **1D-CNN + GRU** | 0.9810 `[0.9754, 0.9862]` | 86.10% `[84.70%, 87.40%]` | 93.40% `[92.30%, 94.40%]` | 0.0289 | 84.20 µs |

### 4.2 Feature Set Ablation: GPS-Only vs. GPS + Accelerometer Cadence

Evaluated across identical 5-fold Leave-One-User-Out splits on 127,655 windows:

| Model Architecture | Telemetry Inputs | PR-AUC | Recall @ 1% FPR | Recall @ 5% FPR | Urban Vehicle Recall (Car/Bus 10–25 km/h) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Rule Baseline** | GPS-Only (22 feats) | 0.7640 | 32.10% | 49.30% | 14.20% |
| **Rule Baseline** | GPS + Cadence (25 feats) | 0.8124 | 41.20% | 58.40% | 46.80% |
| **Logistic Regression** | GPS-Only (22 feats) | 0.8412 | 48.50% | 68.20% | 38.40% |
| **Logistic Regression** | GPS + Cadence (25 feats) | 0.8945 | 62.10% | 78.30% | 74.10% |
| **LightGBM** | GPS-Only (22 feats) | 0.9485 | 59.50% | 76.53% | 56.40% |
| **LightGBM** | GPS + Cadence (25 feats) | 0.9782 | 84.30% | 92.15% | 91.20% |

### 4.3 Strictly Held-Out Adversarial Stress Test (Operating at 1.0% FPR Threshold)

| Adversarial Attack Vector | Attack Configuration | Rule Baseline | Logistic Regression | LightGBM | 1D-CNN + GRU |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Sparse Sampling** | Median $\Delta t > 5.0\text{ s}$, linear waypoint interpolation | 88.0% | 74.5% | 94.2% | 96.1% |
| **Speed-Field Spoofing** | Client reports $8.0\text{ km/h}$; coordinate $\Delta x / \Delta t = 45\text{ km/h}$ | 100.0% | 98.2% | 100.0% | 100.0% |
| **Timestamp Dilation** | Uniform time stretch $+200\%$ to disguise vehicle speed | 42.1% | 68.4% | 89.5% | 91.2% |
| **Offset-Shifted Replay** | Recorded marathon trace shifted $+0.005^\circ$ latitude | 0.0% | 24.1% | 72.4% | 78.0% |
| **Mean Adversarial Detection** | Weighted across all 1,200 synthetic attack cases | 57.5% | 66.3% | 89.0% | 91.3% |

### 4.4 Multi-Language Floating-Point Parity (200 Fixed Canonical Windows)

Reference runtime: Python LightGBM C++ Booster (`booster.predict`).

| Runtime Implementation | Environment | Max Absolute Difference ($\Delta p$) | Decision Matches ($\tau = 0.50$) | Max Relative Delta |
| :--- | :--- | :---: | :---: | :---: |
| **Pure Go Engine** | `backend/internal/anticheat/ml_ensemble.go` | $8.67 \times 10^{-19}$ | 200 / 200 (100.0%) | $< 10^{-15}$ |
| **Pure Dart Engine** | `lib/features/security/anomaly_service.dart` | $4.12 \times 10^{-5}$ | 200 / 200 (100.0%) | $< 10^{-4}$ |
| **ONNX Runtime Engine** | `onnxruntime.InferenceSession` (Python FFI) | $7.61 \times 10^{-8}$ | 200 / 200 (100.0%) | $< 10^{-7}$ |

### 4.5 Quantile Regression Performance (Held-Out 288 Windows)

Optimization criterion: Pinball Loss $\mathcal{L}_\alpha(y, \hat{y}) = \max(\alpha(y - \hat{y}), (\alpha - 1)(y - \hat{y}))$.

| Target Metric | Quantile ($\alpha$) | Pinball Loss | $p_{50}$ Test MAE | $[p_{10}, p_{90}]$ Empirical Coverage | Mean Interval Width |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Achievable Distance** | $p_{10}$ | 0.288 | — | — | — |
| **Achievable Distance** | $p_{50}$ | 0.692 | **1.384 km** | — | — |
| **Achievable Distance** | $p_{90}$ | 0.407 | — | **74.31%** (Nominal: 80.0%) | **3.541 km** |
| **Pace (min/km)** | $p_{10}$ | 0.638 | — | — | — |
| **Pace (min/km)** | $p_{50}$ | 1.171 | **2.343 min/km** | — | — |
| **Pace (min/km)** | $p_{90}$ | 0.672 | — | **75.69%** (Nominal: 80.0%) | **6.992 min/km** |

---

## 5. System Limits: Synthetic vs. Real Data

| Dimension | Real GNSS & IMU Data | Synthetic Adversarial Data | Practical Implication |
| :--- | :--- | :--- | :--- |
| **Measurement Noise** | Multipath jitter, atmospheric attenuation, clock drift, non-Gaussian positional variance | Mathematical interpolation, idealized spline curves, Gaussian white noise | Models trained exclusively on synthetic data fail on noisy real urban runs due to mismatch in high-frequency coordinate variance. |
| **Cadence Coupling** | Biomechanically coupled: step frequency correlates with speed ($r = 0.68$), heel-strike acceleration spikes | Artificially generated scalar steps or zero values | Synthesized cadence cannot capture natural biological variability during fatigue, hill climbs, or street crossing stops. |
| **Environmental Stopping** | Real athletes pause at traffic lights, pedestrian crossings, and water stations ($v = 0$, cadence drops, satellite lock preserved) | Often simulated as instantaneous stops or omitted entirely | Synthetic generators that lack realistic traffic stops cause models to over-index on zero-velocity intervals as anomalies. |

---

## 6. What the Model Does NOT Detect (Known Blindspots & Non-Detections)

The kinematic and machine learning anti-cheat subsystem is bounded by physical and sensor constraints. The following adversarial scenarios are **explicitly not detected** by the current model:

1. **Low-Speed Motorized Transport with Simulated Cadence**  
   If an adversary operates an electric bicycle, moped, or car at a realistic running velocity ($10.0 - 15.0\text{ km/h}$) and uses a mechanical phone shaker or programmatic injector to generate a rhythmic $160 - 175\text{ SPM}$ accelerometer signal with plausible motion energy ($>0.25$), all kinematic feature vectors remain within legitimate human bounds.

2. **Hardware-Level RF GNSS Spoofing**  
   If an attacker uses a Software-Defined Radio (SDR) emitting simulated GPS L1 C/A signals to deceive the device's physical GNSS receiver, the operating system calculates valid satellite ephemeris, non-mocked fixes, and realistic accuracy metrics ($3.0 - 5.0\text{ m}$). The client OS flag `isMocked` remains `false`.

3. **Subtle Elevation / Trail Pacing Discrepancies**  
   Vertical ascent/descent is currently filtered primarily via 2D horizontal kinematics and barometric elevation delta. Downhill running speeds of $20.0 - 22.0\text{ km/h}$ on steep grades exhibit acceleration patterns that border motorized transit, requiring high tolerance thresholds that can admit light vehicle coasting on descents.

4. **Strategic Multi-Account Route Collusion**  
   Legitimate runners who coordinate in person or via secondary communication channels to artificially claim, surrender, or trade territories without competing cannot be detected by kinematic analysis, as each individual trajectory represents genuine human physical movement.

5. **Smooth Mass Transit with Incidental Vibration**  
   Commuters on modern light-rail trams or smooth electric buses traveling at moderate velocities ($15.0 - 25.0\text{ km/h}$) where track vibration registers low-level accelerometer movement ($0.10 - 0.20$ energy) can fall near the decision boundary ($\tau \approx 0.45 - 0.55$), occasionally evading detection unless vehicle speed exceeds $25.0\text{ km/h}$.

---

## 7. Model Cryptographic Verification & Safe Fallback

Both runtime targets enforce cryptographic asset authentication prior to parsing model JSON:

| Model | Asset File | Expected SHA256 Checksum | Invalidation Fallback |
| :--- | :--- | :--- | :--- |
| **Anti-Cheat Trees** | `assets/models/anomaly_detector_trees.json` | `46c87109b1e730a4da6c84b76f6b15261774be826e3f9d96bc1e07f650d9b265` | Fallback to Tier 1 physical rules and 5-dimensional normalized Z-score engine. |
| **Pace/Distance Trees** | `assets/models/pace_distance_trees.json` | `a15a9b98ff37803e49e2908f515e02422716a504eb2ec59ea79dfa9ca46ce7ea` | Fallback to deterministic level-based athletic baseline tables. |
