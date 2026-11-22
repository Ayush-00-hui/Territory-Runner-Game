# Territory Runner Mechanics Specification

This document serves as the authoritative source of truth for core game mechanics, rule parameters, and validation invariants shared between the Flutter client and Go backend.

---

## 1. Simulation & Demo Mode Integrity

### Server Authority & Enforcement
- **Submission Gate**: The backend endpoint `POST /v1/runs` strictly rejects simulated runs.
  - If `simulated: true` is received in the payload, the server immediately returns HTTP 400 Bad Request with:
    ```json
    {
      "code": "SIMULATED_RUN_REJECTED",
      "message": "Simulated runs cannot be submitted to leaderboard or territory rankings."
    }
    ```
- **Zero XP / Territory Reward**: Under no circumstances can simulated coordinates award XP, advance leaderboard rankings, increment user total area, or establish persistent territory ownership.

### Client Behavior & Local-Only Isolation
- **Explicit Simulation Only**: Simulation mode (`LocationService.isSimulationMode`) can only be activated through the deliberate Demo Mode switch (`AppPreferences.isDemoModeEnabled`) or virtual pacer mode. Implicit fallbacks when GPS permissions are denied or satellite fixes timeout are strictly forbidden.
- **Calm Error States**: When hardware location services are disabled or permissions denied, the app surfaces calm, informative action modals ("Location is off", "Location permission needed", "Waiting for GPS") directing the user to device settings or retrying. Runs cannot be started silently in a mock state.
- **HUD Indicator**: While simulation mode is running, a prominent calm badge (`SIMULATED (DEMO)`) with `Icons.science_rounded` is rendered on the HUD to maintain user transparency.
- **Sync Queue Quarantine**: `SyncQueueService.enqueueRun` detects `simulated: true` and drops the entry before SQLite/Hive encryption or background network sync occurs.
- **Local Run History**: Simulated runs are recorded locally with `simulated: true` and `syncStatus: 'demo_only'`. History cards render a calm "Demo run" badge and "Demo run (not submitted)" verification status.

---

## 2. GPS Pipeline & Dynamic Loop Closure Mechanics

### Distance Accumulation & Stationary GPS Wander
- **Zero-Velocity Update (ZUPT)**:
  - When the athlete is stationary (`smoothedSpeedKmh < 1.2 km/h` and `speed <= 0.4 m/s`) or `isAutoPaused == true`, the distance accumulator freezes (`deltaMeters = 0.0`).
  - Stationary GPS wander breadcrumbs are rejected from `_runCoordinates`, completely eliminating phantom drift during stops (reduces stationary drift from +728m baseline to 0.0m).
- **2D Kalman Filter**:
  - Raw GPS fixes are filtered using a constant-velocity local Cartesian Kalman filter where measurement covariance $R = \max(4.0, \sigma_{acc}^2)$.
  - Eliminates lateral zig-zagging hypotenuse accumulation on straight paths, keeping straight 1000m running tracks accurate to $\pm 1\%$.

### Dynamic Loop Closure Scaling
- **Authoritative Invariant**:
  - Base closure distance: $R_{base} = 35.0\text{ m}$.
  - Dynamic scaling formula:
    $$R_{eff} = \text{clamp}\left(25.0\text{ m}, 50.0\text{ m}, R_{base} + (\text{Accuracy}_m - 10.0) \times 0.4\right)$$
  - High-precision GNSS ($\le 5\text{ m}$) tightens to $\sim 33.0\text{ m}$ (minimum $25.0\text{ m}$).
  - Standard phone GPS ($10\text{ m}$) resolves to exactly $35.0\text{ m}$.
  - Degraded urban canyon GPS ($15\text{–}25\text{ m}$) expands gracefully up to $41.0\text{ m}$ (maximum $50.0\text{ m}$) to prevent frustrating false closure rejections.
  - When horizontal accuracy is absent or 0 (such as in legacy golden fixtures), the default $35.0\text{ m}$ is enforced across both client and Go backend.
- **Client & Server Parity**:
  - Implemented in Flutter client: `PolygonEnclosureEngine.effectiveClosureDistance`
  - Implemented in Go backend: `geo.Engine.effectiveClosureDistance`

---

## 3. Territory Defense Shield & Conquest Cooldown

### Sovereign Protection Invariant
- **Cooldown Window**:
  - Whenever an athlete captures a new territory or defends an existing one, the territory receives an authoritative **30-minute defense shield** (`cooldown_until = NOW() + INTERVAL '30 minutes'`).
  - During this 30-minute window, the territory is strictly immune to rival conquest, slicing, or structural damage.
- **Invasion Preemption & Non-Overlapping Sovereignty**:
  - If a rival athlete attempts to run a loop enclosing or intersecting a shielded territory:
    1. The rival cannot carve out or overwrite the shielded area (`ST_Difference` excludes territories where `cooldown_until > NOW()`).
    2. Any portion of the rival's loop intersecting shielded territory is subtracted from the rival's claimable polygon.
    3. If the rival's entire loop lies within the shielded territory, the rival gains 0 m² new area and receives no territory or XP.
- **Fortification & Re-runs**:
  - The owning athlete can re-run and fortify their own sovereign territory at any time, immediately resetting the defense shield to `+30 minutes` and restoring strength to 100%.
- **Shield Expiration & Natural Decay**:
  - Once the 30-minute cooldown elapses (`cooldown_until <= NOW()`), the shield lifts automatically.
  - The territory becomes vulnerable to rival invasion and enters standard lazy decay (15.0 strength lost per 24 hours).
  - Territories below the weak threshold (< 30.0% strength) grant an invading rival a 1.5x XP bonus and collapse if reduced below 50 m².
- **Client & Server Parity**:
  - Go Backend: `store.TerritoryShieldDuration = 30 * time.Minute`, `Territory.IsShielded()`, and SQL migration `000016_add_territory_cooldown.up.sql`.
  - Flutter Client: `Territory.defaultShieldDuration = Duration(minutes: 30)`, `Territory.isShielded()`, `Territory.remainingShieldTime()`, and `TerritoryService.capturePolygonTerritory`.
- **Calm UI Presentation**:
  - Map Markers: Shielded territories render `Icons.shield_rounded` with remaining countdown (`29m`) in calm moss green (`palette.mine`). Unshielded healthy territories display `Icons.shield_outlined`, while decayed territories render `Icons.warning_amber_rounded` in muted crimson.
  - Run Summary: A quiet banner confirms 30-minute defense shield activation upon successful territory capture.


