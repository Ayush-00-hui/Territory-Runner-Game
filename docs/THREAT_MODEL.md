# Territory Runner — Threat Model & Security Architecture

> **Security & Integrity Specification**  
> **Target Audience**: Core Engineers, Security Auditors, College Evaluation Committees  
> **Scope**: Mobile Client (Flutter/Dart), Backend API (Go/PostGIS), Kinematic Anti-Cheat (LightGBM/Rules)  

---

## 1. System Overview & Security Philosophy

Territory Runner is a real-time, location-based territory conquest platform where physical athletic runs enclose geographic polygons to claim territory, climb weekly competitive leagues, and challenge rivals in duels.

Because real estate and leaderboard prestige are tied directly to GPS coordinates, the system operates under a **server-authoritative model with independent telemetry auditing**:

```
[ Untrusted Client Device ]                [ Server Authority Boundary ]
┌─────────────────────────┐               ┌─────────────────────────────────────────┐
│ • Compromised OS/Root   │   Untrusted   │ • Independent Velocity Recalculation   │
│ • Spoofed GPS Provider  │   HTTP/WS     │ • Monotonic Timestamp Verification     │
│ • Faked Accelerometer   │ ────────────► │ • Motion Window Sanity Auditing         │
│ • Missing Motion Data   │   Payload     │ • Deterministic Physical Gate (Tier 1)  │
│ • Reverse Engineered UI │               │ • Pure Go LightGBM Ensemble (Tier 2-Exp)│
└─────────────────────────┘               │ • PostGIS Transaction Advisory Locks    │
                                          │ • Cryptographic RS256 JWT Enforcement   │
                                          └─────────────────────────────────────────┘
```

---

## 2. Attacker Profile & Capabilities (What an Attacker Controls)

An adversary targeting Territory Runner has complete physical and programmatic control over the mobile device. Specifically, an attacker controls:

| Attacker-Controlled Input | Attack Vector / Mechanism | Potential Impact if Unvalidated |
| :--- | :--- | :--- |
| **GPS Coordinate Stream** | Mock location apps, rooted Android location providers, simulated GPX playback, Frida hook overrides of `Location.getLatitude()` / `getLongitude()`. | Faking closed loops around massive city centers or rival zones without physical presence. |
| **Telemetry Speed Field** | Intercepting or modifying the client-reported `speed` float field in JSON payloads (reporting $8.5\text{ km/h}$ while moving at $70\text{ km/h}$). | Evading basic client-side velocity checks. |
| **Timestamps** | Modifying point timestamps ($t_i$) or packet arrival times. Expanding time intervals to artificially deflate calculated velocity. | Disguising high-speed motorized vehicle transit as casual human jogging. |
| **Mock Location Flag (`isMocked`)** | Bypassing OS mock location detection using Xposed modules, Magisk DenyList, or custom Android ROMs where `isFromMockProvider()` is hardcoded to return `false`. | Defeating naive binary flags for developer mock tools. |
| **Motion Sensor (IMU) Data** | Injecting synthesized accelerometer time-series or faked step counts ($165\text{ SPM}$) through modified client binaries or external shakers. | Bypassing cadence stillness rules while riding in a motorized vehicle. |
| **Network Payloads & Replays** | Capturing valid run submissions using proxies (mitmproxy, Burp Suite), modifying idempotency keys, or replaying historical runs at different times or coordinates. | Re-claiming expired territories or inflating league XP. |

---

## 3. Server-Side Validation & Defenses (What We Validate Server-Side)

The Go backend server and PostGIS spatial database act as the absolute source of truth. Every submitted run undergoes authoritative validation before committing spatial mutations.

```
Incoming Run Submission (GeoJSON Polygon + Breadcrumb Telemetry)
                             │
                             ▼
 1. Cryptographic Authentication: Firebase RS256 JWT & Token Expiry
                             │
                             ▼
 2. Timestamp Integrity: Strict Monotonicity & Server Clock Drift Check (±10 min)
                             │
                             ▼
 3. Independent Kinematic Recalculation: Server ignores client "speed" field
    • Velocity = Haversine(P[i], P[i-1]) / (T[i] - T[i-1])
    • Hard Ceilings: Max Speed (25 km/h running), Max Accel (8 m/s²), Teleport (>50m/s)
                             │
                             ▼
 4. Motion Telemetry Audit & Tier 1/2 Evaluation:
    • Server audits motion windows (bounds, inflation, bot signatures)
    • Tier 1 Physical Constraints: Primary gate (speed, accel, vehicle stillness)
    • Tier 2 ML Ensemble: Experimental; disabled by default until >=30 team traces
    • Verification: verified_human, unverified_motion, or rejected
                             │
                             ▼
 5. Geometric & Topological Validation:
    • Loop Perimeter ≥ 40m, Area ≤ 5,000,000 m²
    • PostGIS ST_IsValid, ST_IsClosed, ST_MakeValid, Self-Intersection Check
                             │
                             ▼
 6. Atomic Concurrency Lock: pg_advisory_xact_lock(user_id)
                             │
                             ▼
 7. Spatial Commit: ST_Difference, ST_Union, XP Awarded & Event Broadcast
```

### Detailed Validation Rules

1. **Independent Server Velocity Recalculation**  
   The server explicitly discards the client's reported `speed` attribute. Velocity for each leg is recalculated independently:
   $$v_i = \frac{\text{GeodesicDistance}(P_i, P_{i-1})}{t_i - t_{i-1}}$$
   Any segment exceeding activity ceilings ($25.0\text{ km/h}$ for running, $10.0\text{ km/h}$ for walking, $50.0\text{ km/h}$ for cycling) triggers immediate rejection.

2. **Timestamp Monotonicity & Temporal Drift Bounds**  
   - Strict ordering: $t_i > t_{i-1}$ for all consecutive coordinates.
   - Inter-point bounds: $0.5\text{ s} \le \Delta t \le 10.0\text{ s}$.
   - System clock alignment: The submission timestamp must be within $\pm 10\text{ minutes}$ of the server's UTC clock to prevent replaying stale runs recorded months prior.

3. **Biomechanical Acceleration & Teleportation Ceilings**  
   - Instantaneous acceleration ceiling: $a_i = \frac{v_i - v_{i-1}}{\Delta t} \le 8.0\text{ m/s}^2$ for running ($12.0\text{ m/s}^2$ for cycling).
   - Teleportation jump detector: A spatial displacement $> 50.0\text{ m}$ in $\le 1.0\text{ s}$ is flagged as an invalid jump.

4. **Motion Window Sanity Auditing & Verification States**  
   - Accelerometer windows are client-supplied and cannot be cryptographically attested by mobile OS APIs.
   - The server executes `SanityCheckMotionWindows`:
     - Checks total window duration against run duration (flags inflation $> 15\%$).
     - Rejects out-of-bounds metrics (cadence $\notin [0, 300]\text{ SPM}$, motion energy $\notin [0, 50]$, confidence $\notin [0, 1]$).
     - Detects bot/synthetic injectors ($\ge 5$ consecutive windows with bit-for-bit identical cadence and motion energy).
   - **Verification State Resolution**:
     - `verified_human`: Physical GPS kinematics pass AND motion windows pass server sanity checks. Full territory and duel rewards granted.
     - `unverified_motion`: Physical GPS kinematics pass, but motion windows are missing, empty, or failed sanity checks. Run is accepted and territory is claimed, but active duel challenges are NOT advanced and the $1.5\times$ weak-territory multiplier is withheld.
     - `rejected`: Severe physical violations (mock GPS, teleportation, velocity $> 25\text{ km/h}$, or sustained vehicle stillness $> 6\text{ km/h}$ with 0 cadence and low vibration for $> 30\text{s}$) trigger instant rejection (`422 ANOMALY_REJECTED`).
   - **Tier 2 ML Ensemble (Experimental / Disabled by Default)**: Evaluates a 60-tree LightGBM model only when motion windows are valid and `EnableMLTier2: true`. Kept disabled by default until $\ge 30$ verified team traces are gathered.

5. **Topological & Spatial Sanitization (PostGIS & Clipper2)**  
   - **Minimum Distance**: Loop path perimeter must be $\ge 40\text{ m}$.
   - **Maximum Territory Area**: Enclosed area must not exceed $5,000,000\text{ m}^2$ ($5\text{ km}^2$) per single submission, preventing macro-spoofs of entire states or cities.
   - **Closure Tolerance**: The start and end vertices must close within $35.0\text{ m}$.
   - **Self-Intersection Sanitization**: Cleaned via PostGIS `ST_MakeValid` and classified for interior island holes.

6. **Transaction-Scoped Spatial Concurrency (`pg_advisory_xact_lock`)**  
   - Race conditions (e.g. two runners concurrently claiming the same block) are serialized using PostgreSQL transaction-level advisory locks. The first transaction to commit claims the territory; subsequent transactions subtract the overlapping polygon via `ST_Difference`.

7. **Cryptographic Replay & Identity Protection**  
   - Every request requires a valid Firebase RS256 JWT containing the authenticated `uid`.
   - Idempotency keys (`idempotency_key`) are tracked in the database (`runs` table with a unique constraint). Replaying the exact same payload returns the cached result without mutating database state.

---

## 4. Known Gaps & Residual Risks

While the combination of Tier 1 deterministic physical rules and server-side motion auditing mitigates standard spoofing and vehicle transit, the following attack vectors represent **known residual risks**:

| Residual Risk | Attack Description | Current Mitigation | Architectural Gap / Future Work |
| :--- | :--- | :--- | :--- |
| **Client-Supplied Motion Omission** | Adversary strips all accelerometer telemetry from the payload to avoid triggering cadence stillness checks while in a car. | Server categorizes trace as `unverified_motion`. Run captures base territory but receives zero duel progress and forfeits territory capture multipliers. | Pure GPS vehicle classification in slow urban traffic ($10 - 25\text{ km/h}$) has a ~37% recall at 1% FPR. |
| **Padded / Cushioned Backpack False Positive** | Legitimate runner carries phone in a heavily padded backpack with foam damping, causing motion energy to drop $< 0.25\text{ m}^2/\text{s}^4$ at $10\text{ km/h}$ for $> 30\text{s}$. | Tier 1 vehicle stillness heuristic requires both cadence $< 35$ and energy $< 0.25$. Normal backpack bounce exceeds $0.25$. | If heavily cushioned, triggers vehicle stillness rule. Advise athletes to wear phone in armbands or waistbands. |
| **Fast Stroller Jogging False Positive** | Athlete jogs at $7.5\text{ km/h}$ ($> 6.0\text{ km/h}$) pushing a baby stroller on smooth asphalt with phone mounted on handlebar (0 cadence, low vibration). | Walking with stroller ($\le 6.0\text{ km/h}$) passes cleanly. | Jogging with stroller at $> 6.0\text{ km/h}$ with low handlebar vibration mimics motorized vehicle cruising. |
| **Low-Speed E-Bike with Phone Shaker** | Adversary rides an electric bicycle at $12 - 16\text{ km/h}$ while an oscillating phone cradle generates a rhythmic $165\text{ SPM}$ accelerometer cadence. | Speed ceiling ($25\text{ km/h}$) and cadence stillness rules pass because speed and cadence appear human. | Requires high-frequency IMU jerk analysis (foot-strike ground reaction forces have higher peak sharpness than mechanical shakers). |
| **Hardware-Level RF GNSS Spoofing** | Attacker uses a Software-Defined Radio (e.g. HackRF) to broadcast simulated GPS satellite signals directly to the phone's physical antenna. | OS sees legitimate satellite carrier signals; `isMocked` is `false`. | Cannot be detected by client OS. Mitigated server-side solely by kinematic plausibility and route realism. |
| **Coordinated Multi-Account Collusion** | Two real athletes physically run to exchange or farm territories, deliberately surrendering zones to boost duel XP. | Rules against duplicate device IDs and IP rate limits. | Kinematic telemetry cannot detect social intent or collusive gameplay between legitimate human runners. |
| **Downhill Running Sprint Bursts** | An athlete running down a steep $15\%$ grade mountain trail can temporarily reach $21 - 23\text{ km/h}$ with erratic steps. | Conservative acceleration threshold ($8\text{ m/s}^2$). | May occasionally hover near the Tier 2 anomaly threshold ($\tau \approx 0.48$). Elevation delta weighting is applied to reduce false positives. |

### 4.1 Evaluation Dataset Limits & Adversarial Caveats

> [!WARNING]
> **Adversarial Evaluation Caveat**: The anti-cheat models have **not been evaluated against a motivated human attacker** who actively reverse-engineers the client APK, inspects the Go backend rules, or scripts kinematically plausible GPS tracks.

1. **Small User Cohort (13 Users) & Geographic Bias**:
   - The primary dataset consists of 127,655 windows from only 13 users in Beijing, China (GeoLife 1.3, 2008–2012).
   - In-repo team app traces currently total **0 validated traces** across **0 users** (`app_traces_manifest.json` indicates `min_threshold_met: false`).
   - Local conditions (Beijing subway/bus layouts, legacy GPS loggers) do not reflect global heterogeneous transit or modern multi-band GNSS smartphone chipsets.
2. **Synthetic Generator Caveat**:
   - Synthetic stress tests (`ml/data/generate_spoofs.py`) test specific generator parameters (fixed dt, constant velocity), not creative adversarial evasion.
   - **Replay Attack Vulnerability**: Geographic offset replays achieve **0.0% detection** by kinematic ML models because the underlying movement physics are identical to real human running.
3. **Safe Rollout Controls**:
   - Tier 2 ML cadence model is gated by `ENABLE_CADENCE_MODEL` (default: `false` / OFF).
   - SHA-256 checksums are verified on startup; any mismatch triggers immediate fallback to Tier 1 physical rules.
   - Submissions without valid motion are classified as `unverified_motion`, allowing casual territory capture while withholding competitive duel progression.

---

## 5. Security Checklist for Production Deployments

- [x] **Zero-CGO Pure Go & Dart**: ML inference requires zero external C/C++ dynamic libraries, eliminating buffer overflow and native memory exploitation vectors.
- [x] **Encrypted Local Storage**: Sensitive client-side state (unsettled sync queue, crash recovery snapshots) is encrypted with 256-bit AES (`HiveAesCipher`) backed by `flutter_secure_storage`.
- [x] **Rate Limiting**: Backend Chi router enforces IP and user-based token bucket rate limits ($100\text{ req/min}$ general, $20\text{ req/min}$ run submissions).
- [x] **Zero Database Secrets in Source**: Database credentials, Firebase service accounts, and API keys are isolated via environment variables (`DATABASE_URL`, `FIREBASE_CREDENTIALS`).
