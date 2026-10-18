# Activity-Aware Kinematics and Anti-Cheat Fairness

## 1. Physical Kinematic Boundaries

Territory Runner segregates movement kinematics across three distinct athletic categories:

| Parameter | Walking | Running (Default) | Cycling |
| :--- | :--- | :--- | :--- |
| **Max Outlier Speed** | 15 km/h (4.17 m/s) | 35 km/h (9.72 m/s) | 60 km/h (16.67 m/s) |
| **Min Perimeter** | 40 m | 40 m | 40 m |
| **Target Movement Cadence** | Pedestrian / Stroll | Sprint / Jog | Velocipede / Road / Gravel |

*Note on Minimum Enclosure Area*: The current codebase enforces a universal 40-meter minimum perimeter and 4-node floor. Activity-specific area and perimeter floors are specified for implementation in Phase 5.

### Rationale
- **Walking (15 km/h)**: Human fast-walking world records reach ~14-15 km/h. Filtering above 15 km/h prevents runners or cyclists from claiming walking leaderboards.
- **Running (35 km/h)**: Usain Bolt's peak sprint speed is ~44.7 km/h over 20 meters, with sustained running speeds under 30 km/h. 35 km/h provides ample headroom for elite sprinters while rejecting cars, scooters, or bicycles.
- **Cycling (60 km/h)**: Urban cycling rarely exceeds 40-50 km/h; 60 km/h accommodates high-speed downhill descents while filtering highway vehicular spoofing.

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
