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
  - Whenever an athlete captures a new territory or defends an existing one, the territory receives an authoritative **2-hour defense shield** (`cooldown_until = NOW() + INTERVAL '2 hours'`).
  - During this 120-minute window, the territory is strictly immune to rival conquest, slicing, or structural damage.
- **Invasion Preemption & Non-Overlapping Sovereignty**:
  - If a rival athlete attempts to run a loop enclosing or intersecting a shielded territory:
    1. The rival cannot carve out or overwrite the shielded area (`ST_Difference` excludes territories where `cooldown_until > NOW()`).
    2. Any portion of the rival's loop intersecting shielded territory is subtracted from the rival's claimable polygon.
    3. If the rival's entire loop lies within the shielded territory, the rival gains 0 m² new area and receives no territory or XP.
- **Fortification & Re-runs**:
  - The owning athlete can re-run and fortify their own sovereign territory at any time, immediately resetting the defense shield to `+2 hours` (120 minutes) and restoring strength to 100%.
- **Shield Expiration & Natural Decay**:
  - Once the 2-hour cooldown elapses (`cooldown_until <= NOW()`), the shield lifts automatically.
  - The territory becomes vulnerable to rival invasion and enters standard lazy decay (15.0 strength lost per 24 hours).
  - Territories below the weak threshold (< 30.0% strength) grant an invading rival a 1.5x XP bonus and collapse if reduced below 50 m².
- **Client & Server Parity**:
  - Go Backend: `store.TerritoryShieldDuration = 120 * time.Minute`, `Territory.IsShielded()`, and SQL migration `000016_add_territory_cooldown.up.sql`.
  - Flutter Client: `Territory.defaultShieldDuration = Duration(hours: 2)`, `Territory.isShielded()`, `Territory.remainingShieldTime()`, and `TerritoryService.capturePolygonTerritory`.
- **Calm UI Presentation**:
  - Map Markers: Shielded territories render `Icons.shield_rounded` with remaining countdown (`1h 59m`) in calm moss green (`palette.mine`). Unshielded healthy territories display `Icons.shield_outlined`, while decayed territories render `Icons.warning_amber_rounded` in muted crimson.
  - Run Summary: A quiet banner confirms 2-hour defense shield activation upon successful territory capture.




---

## 4. XP Economy, Leveling Curve & Daily XP Cap

### Area-to-XP Conversion Formula
- **Minimum Capture Floor**: $25.0\text{ m}^2$ (`MinCaptureFloorSqm`).
  - Loops yielding less than $25.0\text{ m}^2$ of net new territory award **$0\text{ XP}$** and create no territory record.
- **Base XP Reward**:
  $$\text{XP}_{\text{base}} = \max\left(5, \text{round}\left(\frac{\text{Net Area Claimed (m}^2)}{20.0}\right)\right)$$
  - Every $20\text{ m}^2$ of sovereign land awards $1\text{ XP}$.
  - Any valid claim ($\ge 25\text{ m}^2$) is guaranteed at least $5\text{ XP}$.
- **Weak Territory Conquest Bonus**:
  - Invading and capturing rival territory whose strength has decayed below $30.0\%$ grants a $1.5\times$ effective area multiplier for XP calculation:
  $$\text{XP}_{\text{weak}} = \max\left(5, \text{round}\left(\frac{1.5 \times \text{Net Area Claimed (m}^2)}{20.0}\right)\right)$$

### Level Progression Curve
- **Progression Step**:
  $$\text{XP Required for Level } L \rightarrow L+1: \quad L \times 250\text{ XP}$$
- **Cumulative XP Requirements**:
  $$\text{Cumulative XP}(L) = \sum_{i=1}^{L-1} (i \times 250) = 125 \times (L-1) \times L$$
  - Level 1: $0\text{ XP}$
  - Level 2: $250\text{ XP}$
  - Level 3: $750\text{ XP}$
  - Level 4: $1,500\text{ XP}$
  - Level 5: $2,500\text{ XP}$ (Unlocks *Veteran Strider* title & wardrobe items)
  - Level 6: $3,750\text{ XP}$
  - Level 7: $5,250\text{ XP}$
  - Level 8: $7,000\text{ XP}$
  - Level 9: $9,000\text{ XP}$
  - Level 10: $11,250\text{ XP}$ (Unlocks Elite wardrobe catalog)

### Daily XP Cap: Analysis & Proposal
- **Current State in Code**: **No Cap** ($0\text{ ceiling}$).
  - *Imbalance*: Any user or vehicle exploiter bypassing velocity gates can submit hundreds of kilometers and earn $50,000+\text{ XP}$ in a single day, breaking weekly league standings and all-time leaderboards.
- **PROPOSED VALUE**: **$10,000\text{ XP}$ per 24-hour UTC day**.
  - *Athletic Calibration*:
    - $10,000\text{ XP} \equiv 200,000\text{ m}^2$ ($0.20\text{ km}^2$) of net new territory loop claims.
    - A dedicated athlete running a demanding $20\text{ km}$ Sunday long run typically claims $80,000\text{ to }140,000\text{ m}^2$ ($4,000\text{ to }7,000\text{ XP}$), leaving comfortable **$30\%\text{–}60\%$ headroom**.
    - Even a full $42.2\text{ km}$ marathon loop ($150,000\text{–}180,000\text{ m}^2$) safely clears under the $10,000\text{ XP}$ ceiling.
  - *Fairness Invariant*:
    - Hitting the cap does **not** stop runs, delete GPS tracks, or reject territory claims.
    - Runs beyond $10,000\text{ XP}$ continue to be recorded, saved in run history, and claimed on the map. Only incremental XP accumulation pauses until 00:00:00 UTC.

---

## 5. Territory Decay Curves & Land Baron Prevention

### Current Decay Formula
- **Decay Nature**: **Strictly Linear**.
- **Decay Rate**: $15.0\text{ strength points lost per 24 hours}$ (`TerritoryDecayPerDay = 15.0`).
- **Dynamic Formula**:
  $$\text{EffectiveStrength}(t) = \max\left(0.0, \min\left(100.0, \text{StoredStrength} - \frac{\Delta t_{\text{hours}}}{24.0} \times 15.0\right)\right)$$
- **Lifecycle Milestones**:
  - $t = 0\text{ days}$: $100.0\%$ (Freshly claimed or defended, shielded)
  - $t = 2.0\text{ days}$: $70.0\%$
  - $t = 4.67\text{ days}$ ($112\text{ hours}$): Crosses below $30.0\%$ threshold $\rightarrow$ enters **Weak state** ($1.5\times\text{ XP}$ capture bonus)
  - $t = 6.67\text{ days}$ ($160\text{ hours}$): Reaches $0.0\%$ strength.

### The "Land Baron" Problem
1. **Perpetual Squatting**: Even when strength reaches $0.0\%$, territories currently **never despawn**. If an inactive runner leaves the app, their $1\text{ km}^2$ polygon remains rendered on the map forever unless an active runner physically traces a loop around or through it.
2. **Infinite Fortification with Zero Marginal Effort**: A dominant runner who jogs a quick loop once every 6 days resets their massive polygon back to $100.0\%$ strength instantly (`TerritoryDefaultStrength = 100.0`).
3. **Barriers to Newer Runners**: A new or slower runner covering $2\text{–}3\text{ km}$ cannot dismantle a giant $15\text{ km}$ perimeter; carving out a $500\text{ m}^2$ parcel leaves $99.95\%$ of the baron's polygon intact.

### PROPOSED MECHANIC: Natural Renewal & Splinter Conquest
1. **Commons Return (Despawn Grace Period)**:
   - When a territory hits $0.0\%$ strength, a **72-hour (3-day) grace period** begins (total $9.67\text{ days}$ of consecutive inactivity).
   - If not defended within the grace period, the territory gently dissolves back into the public commons (unclaimed territory). Local runners can claim fresh ground without having to overwrite old polygons.
2. **Diminishing Fortification**:
   - Re-running an existing sovereign loop restores $+50.0\%$ strength (up to $100.0\%$) rather than an unconditional instant jump from $0\%$ to $100\%$. Regular active runners easily maintain $100\%$, while neglectful runners must run twice to fully restore a decayed zone.
3. **Underdog Splinter Conquest**:
   - Slicing through a territory in the Weak state ($< 30\%$ strength) fractures the sovereign polygon, inflicting an additional $-25.0\%$ structural penalty on the remaining parcel.

---

## 6. Weekly League Structure, Tiers & Thresholds

### Weekly Cycle & Reset
- **Schedule**: Weekly from Monday 00:00:00 UTC to next Monday 00:00:00 UTC.
- **Activity Modality Segregation**: Standings and tiers are calculated separately for running (`activity_type=running`) and cycling (`activity_type=cycling`).
- **Primary Metric**: Net new claimed territory area in square meters ($\text{WeeklyAreaSqm}$).

### Tier Brackets & Percentiles
Standings partition all weekly active participants into four competitive tiers based on cumulative weekly area:
- **Diamond Tier**: Top $5\%$ ($\text{Rank} \le \lceil 0.05 \times N \rceil$)
- **Gold Tier**: Next $20\%$ ($\lceil 0.05 \times N \rceil < \text{Rank} \le \lceil 0.25 \times N \rceil$)
- **Silver Tier**: Next $35\%$ ($\lceil 0.25 \times N \rceil < \text{Rank} \le \lceil 0.60 \times N \rceil$)
- **Bronze Tier**: Bottom $40\%$ ($\text{Rank} > \lceil 0.60 \times N \rceil$)

### Promotion & Relegation Cutoffs
- **Bronze**: Promoted to Silver if finishing in the top $60\%$; no relegation.
- **Silver**: Promoted to Gold if finishing in the top $25\%$; relegated to Bronze if finishing in the bottom $40\%$.
- **Gold**: Promoted to Diamond if finishing in the top $5\%$; relegated to Silver if falling out of the top $25\%$.
- **Diamond**: Retains Diamond status if remaining in the top $5\%$; relegated to Gold otherwise.

---

## 7. Seasons & Crew Goals

### Monthly Seasons
- **Duration**: Exact calendar month (`season_YYYY_MM`, e.g. `season_2026_11`).
  - Starts: 1st of the month at 00:00:00 UTC.
  - Ends: Last day of the month at 23:59:59 UTC.
- **Tracked Metrics**:
  - Individual Runner: Cumulative Monthly Area claimed ($\text{m}^2$), Total Distance ($\text{m}$), and Season XP.
  - Factions: Aggregate sum across all active runners for each of the 4 factions:
    - *Cyber Vanguard*
    - *Neon Wardens*
    - *Solaris Nomads*
    - *Shadow Syndicate*

### Athletic Crews
- **Capacity Constraint**: Maximum **10 runners** per crew (`maxCrewSize = 10`).
- **Exclusivity**: Strict limit of **1 crew per runner**.
- **Weekly Goals**:
  - Set by the crew creator/leader for the active Monday-to-Monday cycle.
  - Metrics: "distance" (meters, e.g. $50,000\text{ m} \equiv 50\text{ km}$) or "area" ($\text{m}^2$, e.g. $25,000\text{ m}^2$).
  - Progress: Automatically aggregated across all crew members' verified runs during the active week.

---

## 8. Social Duels & Stakes

### Parameters & Anti-Abuse Guards
- **Stakes Range**: $0\text{ to }1,000\text{ XP}$ (`0 <= XpStake <= 1000`).
- **Concurrency Limit**: Maximum **3 active or pending duels** per runner simultaneously (`maxActiveDuels = 3`).
- **Target Types**:
  - Distance Target: e.g. $5,000\text{ m}$, $10,000\text{ m}$, $15,000\text{ m}$.
  - Area Target: e.g. $5,000\text{ m}^2$, $10,000\text{ m}^2$, $25,000\text{ m}^2$.
- **Modality Segregation**: Duel target must match the run's exercise activity type (running runs count only toward running duels).
- **Time Limits & Expiration**:
  - Invitation: Automatically expires in **24 hours** if unaccepted.
  - Active Duel: Runs for **24 hours** from acceptance timestamp.
  - Resolution: The athlete who reaches the target first, or leads when 24 hours expire, is declared winner and receives the `XpStake`. In the event of a tie upon expiration, status transitions to `expired` with zero XP transferred.

---

## 9. Territory Defense Shield Duration (Adopted: 120 Minutes)

### Comparative Evaluation of Shield Durations

| Option | Formula / Duration | Pros | Cons | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Legacy Baseline** | Fixed 30 minutes | Land is quickly re-contestable. | **Too short in practice**: expires while athlete is still jogging home or cooling down. | Deprecated |
| **Option A (Area-Scaled)** | $30\text{m} + (\text{Area} / 1000\text{m}^2) \times 10\text{m}$, capped at 4h | Rewards large geographic accomplishments. | Incentivizes massive vehicle loop exploits; opaque calculation for runners. | Rejected |
| **Option B (Streak-Scaled)** | $60\text{m} + (\text{Streak} \times 15\text{m})$, capped at 4h | Rewards daily running consistency. | Punishes newer runners who have a 1-day streak with weak shields. | Rejected |
| **Option C (Calm Fixed 2 Hours)** | **Fixed 120 minutes** | **Zero mental math**, protects runner throughout their post-run recovery and commute, allows morning vs. evening rival contestability without locking neighborhoods. | Fixed regardless of whether loop was $200\text{ m}^2$ or $20,000\text{ m}^2$. | **ADOPTED IN CODE** |

**Implemented Invariant**: `TerritoryShieldDuration = 120 * time.Minute` in Go backend (`backend/internal/store/models.go`) and `Territory.defaultShieldDuration = Duration(hours: 2)` in Flutter client (`lib/models/territory.dart`).

---

## 10. Social Activity Feed, Kudos Reactions & Moderation Mechanics (Phase G4)

### 10.1 Feed Visibility & Server Authoritative Gating
1. **Privacy-by-Default (`share_runs_with_friends = false`)**:
   - Runs are private upon account creation.
   - A run only enters the feed pipeline if the author has explicitly set `share_runs_with_friends = true`.
2. **Mutual Friendship Filter**:
   - Feed query strictly matches users with mutual `friendships.status = 'accepted'`.
   - Strangers, unaccepted requests, or rival runners cannot access an athlete's feed items.
3. **Automatic Privacy Redaction (`geo.MaskPath`)**:
   - Route coordinates are filtered through the athlete's active `privacy_zones`.
   - All breadcrumbs within distance $d \le R$ of any active privacy zone center are pruned on the server prior to returning GeoJSON/thumbnail coordinates.
   - Long tracks are downsampled to a maximum of 50 thumbnail coordinates to prevent bandwidth waste while preserving route silhouette.

### 10.2 Kudos (Reactions) Mechanics
1. **Allowed Tokens**:
   - `kudos`: General athletic recognition (thumbs up).
   - `clap`: Applause and encouragement.
   - `fire`: High performance, speed, or significant area claim.
   - `strong`: Grit, resilience, and challenging course effort.
2. **Cardinality & Idempotency**:
   - One active reaction per user per run (`feed_kudos` has UNIQUE constraint on `(run_id, user_id)`).
   - Selecting an existing reaction removes it; selecting a different reaction updates it.
   - Reaction requests are rate-limited per user to prevent automated spamming.

### 10.3 Moderation Integrity
1. **Block Enforcement**:
   - Blocking immediately establishes a mutual block in `user_blocks`, terminates any active friendship, and marks pending duels between the pair as declined.
   - Blocked athletes cannot see each other's runs in feed or leaderboard direct comparisons.
2. **Hide Post**:
   - Hiding a post records an entry in `hidden_posts` for the requesting runner. The post is omitted from subsequent feed queries for that viewer.
3. **Structured Reporting**:
   - Reports are recorded in `moderation_reports` with structured categories (`harassment`, `inappropriate_shape`, `vehicular_cheat`, `spam`, `other`).

---

## 11. Authoritative Matrix: Server-Enforced vs. Client-Only Rules

| Mechanic / Feature | Authority | Exact Value / Rule | Backend Source File | Flutter Source File |
| :--- | :--- | :--- | :--- | :--- |
| **Simulated Runs Reject** | Server | HTTP 400 `SIMULATED_RUN_REJECTED`, 0 XP, 0 area | `backend/internal/api/handlers.go` | `lib/services/sync_queue_service.dart` |
| **Max Running Speed** | Server + Client | $25.0\text{ km/h}$ ($6.94\text{ m/s}$), vehicle cutoff | `backend/internal/anticheat/engine.go` | `lib/services/location_service.dart` |
| **Max Cycling Speed** | Server + Client | $45.0\text{ km/h}$ ($12.5\text{ m/s}$) | `backend/internal/anticheat/engine.go` | `lib/services/location_service.dart` |
| **Teleport Rejection** | Server + Client | $> 50.0\text{ m}$ jump in $1.0\text{ s}$ ($180\text{ km/h}$) | `backend/internal/anticheat/engine.go` | `lib/services/anomaly_service.dart` |
| **Dynamic Loop Closure** | Parity | $\text{clamp}(25\text{m}, 50\text{m}, 35\text{m} + (\text{acc} - 10) \times 0.4)$ | `backend/internal/geo/engine.go` | `lib/features/gameplay/polygon_enclosure_engine.dart` |
| **Territory Defense Shield** | Server Authoritative | $120\text{ minutes}$ (2 hours) post-capture | `backend/internal/store/models.go` | `lib/models/territory.dart` |
| **Minimum Capture Floor** | Parity | $25.0\text{ m}^2$ minimum loop area | `backend/internal/store/models.go` | `lib/features/gameplay/territory_service.dart` |
| **XP Conversion Rate** | Parity | $1\text{ XP} \text{ per } 20.0\text{ m}^2$, minimum floor $5\text{ XP}$ | `backend/internal/store/models.go` | `lib/features/gameplay/territory_service.dart` |
| **Weak Conquest Bonus** | Parity | $1.5\times$ XP bonus on territory strength $< 30\%$ | `backend/internal/store/models.go` | `lib/features/gameplay/territory_service.dart` |
| **Daily XP Ceiling** | Parity | $10,000\text{ XP}$ per UTC day ceiling | `backend/internal/store/models.go` | `lib/features/gameplay/territory_service.dart` |
| **Territory Decay Rate** | Parity | $15.0\text{ points per 24h}$ (160h to 0%) | `backend/internal/store/models.go` | `lib/models/territory.dart` |
| **Despawn Grace Period** | Parity | $72\text{ hours}$ (232h total before commons return) | `backend/internal/store/models.go` | `lib/models/territory.dart` |
| **Weekly League Divisions** | Server Authoritative | Mon-Mon UTC cycle; Diamond (5%), Gold (20%), Silver (35%), Bronze (40%) | `backend/internal/league/league.go` | `lib/features/compete/weekly_league_view.dart` |
| **Crew Max Capacity** | Server Authoritative | Max 10 runners per crew, max 1 crew per runner | `backend/internal/store/models.go` | `lib/features/social/widgets/crew_sheet.dart` |
| **Social Duel Limits** | Server Authoritative | $0\text{–}1,000\text{ XP}$ stake, max 3 active duels, 24h expiry | `backend/internal/store/models.go` | `lib/features/social/widgets/social_duel_creator_sheet.dart` |
| **Social Feed Sharing** | Server Authoritative | Opt-in default OFF (`share_runs_with_friends`), mutual friends only | `backend/internal/store/postgres.go` | `lib/services/app_preferences.dart` |
| **Privacy Zone Masking** | Server Authoritative | Authoritative boundary circle redaction (`geo.MaskPath`) | `backend/internal/geo/privacy.go` | `lib/models/privacy_zone.dart` |
| **Kudos Reaction Tokens** | Server Authoritative | Exactly 4 tokens: `kudos`, `clap`, `fire`, `strong` | `backend/internal/store/models.go` | `lib/features/social/widgets/social_feed_tab.dart` |
| **Saved Loops (F1)** | Client Local | SQLite/Hive encrypted, off-route cue $30.0\text{ m}$ | Local-only | `lib/services/saved_loop_service.dart` |
| **Training Plans (F2)** | Client Local | 8-week 5K & 4-week pace building, zero shame | Local-only | `lib/services/training_plan_service.dart` |
| **Auto-Lap / Pacing (F3)** | Client Local | $1.0\text{ km}$ or $1.0\text{ mi}$, $\pm 10\text{ s/km}$ tolerance band | Local-only | `lib/services/auto_lap_service.dart` |
| **Weekly Recap (F4)** | Client Local | Sunday card, 0 coordinate leakage, delta metrics | Local-only | `lib/services/weekly_recap_service.dart` |
| **Exploration Map (F5)** | Client Local | $50\text{ m} \times 50\text{ m}$ geohash tiles, 0 upload | Local-only | `lib/services/exploration_service.dart` |
| **Tiered Badges (F6)** | Client Local | Bronze, Silver, Gold cosmetic wardrobe progression | Local-only | `lib/services/tiered_achievement_service.dart` |
| **Streak Freeze (Local)** | Client Local | Earned 1 per 7 active days, max 2 stored | Local-only | `lib/services/app_preferences.dart` |
| **Biometrics & Calories** | Client Local | Strictly on-device (weight, height, age, surrogate ML) | Local-only | `lib/services/calorie_model_engine.dart` |


