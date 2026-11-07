# Territory Runner: Calorie & Energy Expenditure Engine Architecture

This document specifies the scientific and physiological energy expenditure foundation for **Territory Runner**. It replaces the historical flat distance multiplier ($kcal = d \cdot M \cdot factor$) with peer-reviewed biomechanical models accounting for body mass, speed, incline/grade, resting metabolism, and cycling power dynamics.

---

## 1. Principles & Offline-First Design

1. **Offline-First**: All physiological and sensing calculations execute on-device in pure Dart with zero external network or server dependencies.
2. **Privacy-by-Design**: User body details (weight, height, age, gender) remain strictly local on the device in encrypted storage (`SharedPreferences`). They are **never** transmitted to backends, analytics, push notifications, or public leaderboards.
3. **Dual Metric Tracking (Gross vs. Net Energy)**:
   - **Gross Energy Expenditure ($EE_{\text{gross}}$)**: Total calories burned by the body during the workout, including basal/resting metabolism ($RMR$). Fitness devices (Garmin, Apple Watch, Strava) display gross energy to athletes. Territory Runner renders gross calories as the primary user readout (`~N kcal (est.)`).
   - **Net Energy Expenditure ($EE_{\text{net}}$)**: Energy burned *strictly above* resting levels due to physical locomotion ($EE_{\text{net}} = EE_{\text{gross}} - RMR$). Both are tracked internally.
4. **Treatment of Paused Time**:
   - During active movement ($v \ge 0.5\text{ km/h}$), gross energy accumulates locomotor cost plus resting cost.
   - When stationary or auto-paused, locomotor cost is immediately zeroed ($0.0\text{ kcal/min}$). Only resting basal metabolism ($RMR_{\text{min}}$) accumulates per minute of elapsed stopped time.

---

## 2. Core Physiological Equations

### 2.1 Resting Metabolic Rate: Mifflin-St Jeor (1990)
**Citation**: Mifflin, M. D., St Jeor, S. T., Hill, L. A., Scott, B. J., Daugherty, S. A., & Koh, Y. O. (1990). *A new predictive equation for resting energy expenditure in healthy individuals*. The American Journal of Clinical Nutrition, 51(2), 241–247.

$$RMR \ (\text{kcal/day}) = 10 \cdot M_{\text{kg}} + 6.25 \cdot H_{\text{cm}} - 5.0 \cdot A_{\text{yr}} + s$$

Where:
- $M_{\text{kg}}$: Body mass in kilograms (valid range: $25$ to $250\text{ kg}$).
- $H_{\text{cm}}$: Stature in centimeters (valid range: $100$ to $230\text{ cm}$).
- $A_{\text{yr}}$: Age in years (valid range: $10$ to $100\text{ years}$).
- $s$: Biological sex coefficient:
  - **Male**: $s = +5.0$
  - **Female**: $s = -161.0$
  - **Prefer not to say (Neutral)**: $s = \frac{+5.0 + (-161.0)}{2} = -78.0\text{ kcal/day}$ (the exact unbiased arithmetic midpoint).

**Resting Rate per Minute**:
$$RMR_{\text{min}} = \frac{RMR}{1440\text{ min/day}} \ (\text{kcal/min})$$

*Reference Adult (70 kg, 170 cm, 30 years, Neutral Sex)*:
$$RMR = 10(70) + 6.25(170) - 5(30) - 78 = 700 + 1062.5 - 150 - 78 = 1534.5\text{ kcal/day} = 1.066\text{ kcal/min}$$

---

### 2.2 Locomotion Oxygen Cost: ACSM Metabolic Equations
**Citation**: American College of Sports Medicine (2021). *ACSM's Guidelines for Exercise Testing and Prescription*, 11th Edition. Wolters Kluwer.

- Speed $s$ is converted to meters per minute: $s = v_{\text{km/h}} \times \frac{1000}{60}\text{ m/min}$.
- Grade $G$ is fractional inclination (e.g. $+5\% = +0.05$).
- Caloric Oxygen Equivalent: **$4.86\text{ kcal / L } O_2$** at respiratory exchange ratio $RER \approx 0.85$ (aerobic lipid/carbohydrate oxidation).
- Resting baseline: $1\text{ MET} = 3.5\text{ mL } O_2 \cdot \text{kg}^{-1} \cdot \text{min}^{-1}$.

#### A. Running Equation (Valid for speed $\ge 8.0\text{ km/h}$, grade $-0.06 \le G \le +0.15$):
$$VO_{2,\text{run}} \ (\text{mL}\cdot\text{kg}^{-1}\cdot\text{min}^{-1}) = 0.2 \cdot s + 0.9 \cdot s \cdot G + 3.5$$
- $0.2 \cdot s$: Horizontal oxygen cost ($0.2\text{ mL}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$).
- $0.9 \cdot s \cdot G$: Vertical climbing oxygen cost ($0.9\text{ mL}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$ vertical).
- $3.5$: Resting metabolic component.

#### B. Walking Equation (Valid for speed $3.0$ to $6.0\text{ km/h}$, grade $-0.06 \le G \le +0.15$):
$$VO_{2,\text{walk}} \ (\text{mL}\cdot\text{kg}^{-1}\cdot\text{min}^{-1}) = 0.1 \cdot s + 1.8 \cdot s \cdot G + 3.5$$
- $0.1 \cdot s$: Horizontal walking cost ($0.1\text{ mL}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$).
- $1.8 \cdot s \cdot G$: Vertical climbing cost ($1.8\text{ mL}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$ vertical).

#### Gross Calorie Burn Rate from $VO_2$:
$$\text{Burn Rate } (\text{kcal/min}) = \frac{VO_2}{1000\text{ mL/L}} \times M_{\text{kg}} \times 4.86\text{ kcal/L}$$

---

### 2.3 Steep Incline & Decline Cost: Minetti et al. (2002)
**Citation**: Minetti, A. E., Moia, C., Roi, G. S., Susta, D., & Ferretti, G. (2002). *Energy cost of walking and running at extreme uphill and downhill slopes*. Journal of Applied Physiology, 93(3), 1039–1046. DOI: 10.1152/japplphysiol.01177.2002.

For gradients $|G| > 0.06$ (steeper than $\pm 6\%$, up to $\pm 20\%$), linear models lose validity. Minetti's 5th-order empirical polynomial models the energy cost per unit distance $C_r(i)$ in $\text{J} \cdot \text{kg}^{-1} \cdot \text{m}^{-1}$:

$$C_r(i) = 155.4 \cdot i^5 - 30.4 \cdot i^4 - 32.8 \cdot i^3 + 43.7 \cdot i^2 + 19.5 \cdot i + 3.6$$

And for walking:
$$C_w(i) = 280.5 \cdot i^5 - 58.7 \cdot i^4 - 76.8 \cdot i^3 + 51.9 \cdot i^2 + 19.6 \cdot i + 2.5$$

Where $i = \text{fractional grade}$.
- **Downhill Braking Limit**: Eccentric muscular contractions require active energy to brake. Minetti establishes a physiological minimum cost of running around $i \approx -0.10$ to $-0.15$ ($C_r \ge 1.8\text{ J}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$, $C_w \ge 1.2\text{ J}\cdot\text{kg}^{-1}\cdot\text{m}^{-1}$). Energy cost **never** drops below this floor or becomes negative.
- Conversion to Net $VO_2$:
  $$\text{Net } VO_2 = \frac{C(i) \cdot s}{20.33424} \ (\text{mL}\cdot\text{kg}^{-1}\cdot\text{min}^{-1}) \quad [1\text{ L } O_2 = 4.86\text{ kcal} = 20,334.24\text{ J}]$$
  $$\text{Gross } VO_2 = \text{Net } VO_2 + 3.5$$

---

### 2.4 Cycling Power-Balance Model: Martin et al. (1998)
**Citation**: Martin, J. C., Milliken, D. L., Cobb, J. E., McFadden, K. L., & Coggan, A. R. (1998). *Validation of a mathematical model for road cycling power*. Journal of Applied Biomechanics, 14(3), 276–291.

Total mechanical power required at the pedals $P_{\text{pedal}}$ in Watts ($v = \text{speed in m/s}$, total mass $M_{\text{tot}} = M_{\text{body}} + 10.0\text{ kg}$):
$$P_{\text{propulsion}} = P_{\text{rolling}} + P_{\text{gravity}} + P_{\text{drag}}$$

1. **Rolling Resistance**: $P_{\text{rolling}} = C_{rr} \cdot M_{\text{tot}} \cdot g \cdot v$ ($C_{rr} = 0.005$, $g = 9.80665\text{ m/s}^2$).
2. **Gravity Power**: $P_{\text{gravity}} = M_{\text{tot}} \cdot g \cdot G \cdot v$.
3. **Aerodynamic Drag**: $P_{\text{drag}} = 0.5 \cdot \rho \cdot C_d A \cdot v^3$ ($\rho = 1.225\text{ kg/m}^3$, $C_d A = 0.38\text{ m}^2$).
4. **Drivetrain Mechanical Loss**: $\eta_{\text{drivetrain}} = 0.96 \implies P_{\text{pedal}} = \frac{\max(0.0, P_{\text{propulsion}})}{0.96}$.
5. **Gross Human Metabolic Efficiency**: $\eta_{\text{human}} = 0.22$ ($22\%$ mechanical-to-metabolic efficiency).
$$P_{\text{metabolic}} = \frac{P_{\text{pedal}}}{\eta_{\text{human}}} \ (\text{Watts})$$
$$\text{Net Burn Rate } (\text{kcal/min}) = P_{\text{metabolic}} \times \frac{60\text{ s/min}}{4184\text{ J/kcal}} \approx P_{\text{metabolic}} \times 0.01434$$
$$\text{Gross Burn Rate } (\text{kcal/min}) = \text{Net Burn Rate} + RMR_{\text{min}}$$

---

## 3. Reference Test Cases (Hand Arithmetic)

| Activity | Mass | Speed | Grade | Duration | Distance | Calculated Gross Kcal | Legacy Flat Kcal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Running (Flat)** | 70 kg | 10 km/h | 0.0% | 30 min | 5.0 km | **376 kcal** ($12.53\text{ kcal/min}$) | 363 kcal |
| **Running (+5% Hill)** | 70 kg | 10 km/h | +5.0% | 30 min | 5.0 km | **452 kcal** ($15.08\text{ kcal/min}$) | 363 kcal (+20.3% uphill) |
| **Running (+10% Steep)** | 70 kg | 10 km/h | +10.0% | 30 min | 5.0 km | **534 kcal** ($17.79\text{ kcal/min}$) | 363 kcal (+42.1% Minetti) |
| **Walking (Flat)** | 70 kg | 5 km/h | 0.0% | 60 min | 5.0 km | **242 kcal** ($4.03\text{ kcal/min}$) | 255 kcal |
| **Cycling (Flat)** | 70 kg | 20 km/h | 0.0% | 60 min | 20.0 km | **315 kcal** ($5.25\text{ kcal/min}$) | 560 kcal (Flat overstated) |

---

## 4. Mathematical Monotonicity Guarantees

1. **Body Mass Monotonicity**: $\frac{\partial (EE)}{\partial M} > 0$. A 90 kg runner burns more calories than a 60 kg runner at any identical speed and incline.
2. **Speed Monotonicity**: $\frac{\partial (\text{BurnRate})}{\partial v} > 0$. Running faster increases energy expenditure per unit time.
3. **Incline Monotonicity**: $\frac{\partial (EE)}{\partial G} > 0$ for all positive slopes. Uphill terrain increases muscular power cost.
4. **Downhill Boundedness**: For all negative gradients $G \in [-0.20, 0.0]$, $EE_{\text{gross}} \ge RMR_{\text{min}} \cdot t > 0$. Energy cost is never negative and incorporates Minetti eccentric braking.

---

## 5. Machine Learning Surrogate & Quantile Bands (Phase 4)

### 5.1 Why a Surrogate Model?
Laboratory-grade indirect calorimetry with breath-by-breath gas exchange masks ($\text{VO}_2/\text{VCO}_2$) is the physiological gold standard, but cannot be worn during real-world smartphone runs. Public datasets containing paired wearable GPS trajectories and laboratory metabolic cart recordings either do not exist with unencumbered open licenses or lack high-rate mobile sensor logs.

Accordingly, Territory Runner does **not claim to have discovered new physiological ground truth**. Instead, the on-device ML model is an **explainable, noise-resilient surrogate** trained against the validated Phase 3 physiological baseline (ACSM + Minetti + Mifflin-St Jeor), explicitly trained to absorb:
1. GPS Doppler speed noise ($\sigma \approx 0.35\text{ km/h}$).
2. Barometric / GPS altitude grade noise ($\sigma \approx 0.012$).
3. Accelerometer cadence fluctuation.

### 5.2 Model Architecture & Non-Decreasing Monotonicity
- **Framework**: Monotone-constrained gradient boosted decision trees (`LightGBM`).
- **Input Features**: `[body_mass_kg, speed_kmh, grade, cadence_spm, climb_rate_m_min]`.
- **Monotone Constraints**: `[+1, +1, +1, 0, +1]`. Tree splits are mathematically constrained so that predicted energy expenditure rate cannot decrease as body mass, speed, grade, or climb rate increases.
- **Quantile Uncertainty Bands**:
  - **P10 (10th percentile)**: Conservative estimate (highly economical runner, smooth surface, favorable wind).
  - **P50 (50th percentile)**: Median physiological expectation.
  - **P90 (90th percentile)**: Elevated estimate (less economical runner, soft/muddy terrain, headwind, grade spikes).
  - **Non-Crossing Guarantee**: Enforces $P10 \le P50 \le P90$ on every inference pass.

### 5.3 On-Device Pure Dart Inference
- **Zero Heavy Dependencies**: Evaluated directly in Dart using native recursion on compact JSON tree structures (`assets/models/calorie_trees.json`).
- **Integrity Validation**: The runtime hashes the model asset with cryptographic SHA-256 (`6ef0429cf529b8267a635631ffec9e3bab027423f1376519739eda47071037e4`). If the asset is missing, corrupt, or tampered with, it logs once and gracefully falls back to the analytical Phase 3 equations.
- **Execution Cost**: $< 15\ \mu\text{s}$ per evaluation on standard mobile CPUs.

### 5.4 Personal Smartwatch Calibration ("Calibrate with my watch")
For runners with trusted wrist wearables (Apple Watch, Garmin, Coros):
- After at least 3 completed runs where the user records their watch calories, Territory Runner computes the median ratio:
  $$k_{\text{calib}} = \text{median}\left(\frac{\text{Cal}_{\text{watch}}}{\text{Cal}_{\text{model}}}\right)$$
- The calibration factor is strictly bounded within $[0.8, 1.2]$ to prevent spoofing or erroneous input.
- Calibration is stored purely on-device (`pref_watch_calorie_factor_v1`), displayed transparently in Settings, and can be reset at any time.

