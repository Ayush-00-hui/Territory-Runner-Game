# Activity-Aware Kinematics and Anti-Cheat Fairness

## 1. Physical Kinematic Boundaries

Territory Runner segregates movement kinematics across three distinct athletic categories:

| Parameter | Walking | Running (Default) | Cycling |
| :--- | :--- | :--- | :--- |
| **Max Instant Speed** | 10 km/h (2.78 m/s) | 25 km/h (6.94 m/s) | 50 km/h (13.89 m/s) |
| **Max Average Endurance** | 8.5 km/h (2.36 m/s) | 22 km/h (6.11 m/s) | 40 km/h (11.11 m/s) |
| **Max Outlier Speed** | 15 km/h (4.17 m/s) | 35 km/h (9.72 m/s) | 60 km/h (16.67 m/s) |
| **Teleport Ceiling** | 15 km/h | 35 km/h | 65 km/h |
| **Min Perimeter** | 40 m | 40 m | 40 m |
| **Min Points** | 4 | 4 | 4 |
| **Max Loop Area** | 5,000,000 m² | 5,000,000 m² | 5,000,000 m² |
| **Target Movement Cadence** | Pedestrian / Stroll | Sprint / Jog | Velocipede / Road / Gravel |

> [!NOTE]
> **No Per-Activity Minimum Area Floors**: The codebase deliberately enforces a universal 40-meter minimum perimeter and 4-node floor. No per-activity minimum area floors (e.g., 100/400/2500 m²) exist in the code (`lib/features/gameplay/polygon_enclosure_engine.dart` or `backend/internal/geo/engine.go`). Any non-self-intersecting loop meeting the 40m perimeter and $\le 5,000,000\text{ m²}$ constraint is geometrically valid.

### Rationale
- **Walking (10 km/h instant, 15 km/h outlier)**: Human fast-walking world records reach ~14-15 km/h. Filtering above 10 km/h instant and 15 km/h outlier prevents runners or cyclists from claiming walking leaderboards.
- **Running (25 km/h instant, 35 km/h outlier)**: Elite sprinting speeds reach ~44 km/h momentarily, with sustained distance running below 22 km/h. 25 km/h instant and 35 km/h outlier accommodate sprinters while rejecting bicycles and cars.
- **Cycling (50 km/h instant, 60 km/h outlier)**: Urban road cycling rarely exceeds 40-50 km/h; 50 km/h instant and 60 km/h outlier accommodate fast descents while filtering highway motor vehicle spoofing.

---

## 2. Consecutive Sample Outlier Tracking

A critical security flaw in naive spatial outlier filters is calculating speed relative only to the *last accepted* point:
$$\text{Flawed Speed} = \frac{\text{dist}(P_{\text{current}}, P_{\text{last\_accepted}})}{t_{\text{current}} - t_{\text{last\_accepted}}}$$

If a player is in a motorized vehicle traveling at 80 km/h, intermediate points are discarded, causing $t_{\text{current}} - t_{\text{last\_accepted}}$ to grow large. Eventually, an arbitrary subsequent sample will have an average speed falling below 35 km/h, allowing the vehicle track to sneak through.

### Industry Standard Implementation (Dart & Go Parity)
Both client and server track the **most recently received sample** ($P_{\text{last\_received}}, t_{\text{last\_received}}$), regardless of whether it was accepted into the enclosure buffer:

```
P1 (Accepted) ──> P2 (80 km/h - Outlier) ──> P3 (80 km/h - Outlier) ──> P4
                  ▲                          ▲
                  Checked vs P1              Checked vs P2 (Speed: 80 km/h)
                  REJECTED                   REJECTED
```

This guarantees continuous kinematic validation without bypasses.

---

## 3. Separation of Competitions

### Leaderboards and Weekly Leagues
A cyclist traveling at 35 km/h over 1 hour encloses up to $50\times$ more area than an equivalent runner. Mixing cycling and running on a single leaderboard destroys competitive integrity and demotivates runners.
- **GET `/v1/leaderboard?activity_type={running|cycling|walking}`** partitions aggregate captured territory by sport.
- **GET `/v1/league/current?activity_type={running|cycling|walking}`** partitions weekly promotion/relegation divisions.

### Duels
- Every duel challenge has an explicit `activity_type` (PostGIS migration 000009).
- When a user submits a run, `store.UpdateDuelProgress` increments progress **only** for active duels whose `activity_type` matches the submitted run. Cycling runs cannot advance running duels.

---

## 4. Test Verification & Parity Fixtures

- **Golden Fixtures**:
  - `golden_cycling_valid_loop.json`: Loop at ~42 km/h. Rejected under running mode (outlier detected), accepted under cycling mode.
  - `golden_walking_valid_loop.json`: Valid walking loop at ~5 km/h.
- **Dart Tests**: `test/golden_fixtures_test.dart` (8 tests) verifies Dart engine behavior against both fixtures.
- **Go Tests**: `backend/internal/geo/engine_test.go` (9 tests) verifies identical behavior on Go backend.
