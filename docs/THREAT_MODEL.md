# Territory Runner — Threat Model & Security Architecture

> **Security & Integrity Specification**  
> **Target Audience**: Core Engineers, Security Auditors, College Evaluation Committees  
> **Scope**: Mobile Client (Flutter/Dart), Backend API (Go/PostGIS), Kinematic Anti-Cheat (LightGBM/Rules)  

---

## 1. System Overview & Security Philosophy

Territory Runner is a real-time, location-based territory conquest platform where physical athletic runs enclose geographic polygons to claim territory, climb weekly competitive leagues, and challenge rivals in duels.

Because real estate and leaderboard prestige are tied directly to GPS coordinates, the system operates under a **zero-trust client model**:

```
[ Untrusted Client Device ]                [ Server Authority Boundary ]
┌─────────────────────────┐               ┌─────────────────────────────────────────┐
│ • Compromised OS/Root   │   Untrusted   │ • Independent Velocity Recalculation   │
│ • Spoofed GPS Provider  │   HTTP/WS     │ • Monotonic Timestamp Verification     │
│ • Faked Accelerometer   │ ────────────► │ • Pure Go LightGBM Kinematic Ensemble   │
│ • Reverse Engineered UI │   Payload     │ • PostGIS Transaction Advisory Locks    │
└─────────────────────────┘               │ • Cryptographic RS256 JWT Enforcement   │
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
 4. Tier 2 ML Anti-Cheat: Native Go LightGBM 25-Feature Decision Tree Ensemble
    • Sinuosity, Heading Entropy, Speed Variance, Motion Cadence
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

4. **Tier 2 ML Kinematic Ensemble (Pure Go)**  
   - The Go backend runs a compiled 60-tree LightGBM ensemble (`backend/internal/anticheat/ml_ensemble.go`) evaluating 25 kinematic and motion features over 30-second sliding windows.
   - Evaluates multi-dimensional signals: speed variance, acceleration jerk, heading change rate, turning angle entropy, and stop frequency.

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

While the combination of Tier 1 deterministic physical rules and Tier 2 ML kinematic classification detects standard spoofing and vehicle transit, the following attack vectors represent **known residual risks**:

| Residual Risk | Attack Description | Current Mitigation | Architectural Gap / Future Work |
| :--- | :--- | :--- | :--- |
| **Low-Speed E-Bike with Phone Shaker** | Adversary rides an electric bicycle at $12 - 16\text{ km/h}$ while an oscillating phone cradle generates a rhythmic $165\text{ SPM}$ accelerometer cadence. | Speed ceiling ($25\text{ km/h}$) and cadence stillness rules pass because speed and cadence appear human. | Requires high-frequency IMU jerk analysis (foot-strike ground reaction forces have higher peak sharpness than mechanical shakers). |
| **Hardware-Level RF GNSS Spoofing** | Attacker uses a Software-Defined Radio (e.g. HackRF) to broadcast simulated GPS satellite signals directly to the phone's physical antenna. | OS sees legitimate satellite carrier signals; `isMocked` is `false`. | Cannot be detected by client OS. Mitigated server-side solely by kinematic plausibility and route realism. |
| **Coordinated Multi-Account Collusion** | Two real athletes physically run to exchange or farm territories, deliberately surrendering zones to boost duel XP. | Rules against duplicate device IDs and IP rate limits. | Kinematic telemetry cannot detect social intent or collusive gameplay between legitimate human runners. |
| **Downhill Running Sprint Bursts** | An athlete running down a steep $15\%$ grade mountain trail can temporarily reach $21 - 23\text{ km/h}$ with erratic steps. | Conservative acceleration threshold ($8\text{ m/s}^2$). | May occasionally hover near the Tier 2 anomaly threshold ($\tau \approx 0.48$). Elevation delta weighting is applied to reduce false positives. |

---

## 5. Security Checklist for Production Deployments

- [x] **Zero-CGO Pure Go & Dart**: ML inference requires zero external C/C++ dynamic libraries, eliminating buffer overflow and native memory exploitation vectors.
- [x] **Encrypted Local Storage**: Sensitive client-side state (unsettled sync queue, crash recovery snapshots) is encrypted with 256-bit AES (`HiveAesCipher`) backed by `flutter_secure_storage`.
- [x] **Rate Limiting**: Backend Chi router enforces IP and user-based token bucket rate limits ($100\text{ req/min}$ general, $20\text{ req/min}$ run submissions).
- [x] **Zero Database Secrets in Source**: Database credentials, Firebase service accounts, and API keys are isolated via environment variables (`DATABASE_URL`, `FIREBASE_CREDENTIALS`).
