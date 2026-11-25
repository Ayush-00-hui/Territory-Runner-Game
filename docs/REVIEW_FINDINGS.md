# Territory Runner Codebase Forensic Audit & Review Findings

This document contains the complete findings from the forensic audit of the Territory Runner codebase across the Go backend, Dart Flutter client, database migrations, CI workflows, and documentation.

Findings are categorized by severity:
- **P0**: Critical correctness bugs, wrong game calculations, double-counting, spatial integrity loss, unhandled database errors.
- **P1**: Visible UX bugs, unindexed queries, missing edge-case handling, design token violations, CI workflow gaps.
- **P2**: Maintainability, architectural hygiene, technical debt.
- **P3**: Minor cosmetic polish and documentation enhancements.

---

## 1. P0 Findings (Must be fixed in this release)

| ID | File & Line | Severity | Category | Description | One-Line Fix |
|:---|:---|:---:|:---|:---|:---|
| **P0-1** | `backend/internal/store/postgres.go:412` | **P0** | Spatial Accounting | `areaClaimed += loop.AreaSqMeters` credits raw loop area. Looping over existing owned territory earns full area and XP again indefinitely. | Compute `net_new = ST_Area(new_geom) - ST_Area(old_geom)` and record only genuine new area in `runs.area_claimed`. |
| **P0-2** | `backend/internal/store/memory.go:359` | **P0** | Parity Accounting | `areaClaimed = loopArea` in memory store uses raw loop area instead of net new area, causing parity divergence. | Calculate net new area by subtracting existing player territory from candidate loop in memory store. |
| **P0-3** | `backend/internal/store/postgres.go:348` | **P0** | Spatial Conflict | `ST_Union` merges the new loop into player territory without clipping shielded rivals (`cooldown_until > NOW()`). Two players can own the same ground. | Pre-clip candidate loop by subtracting shielded rival geometries (`ST_Difference`) before unioning. |
| **P0-4** | `backend/internal/store/memory.go:433` | **P0** | Parity Conflict | Memory store assigns player territory without clipping shielded rival coordinates. | Subtract shielded rival paths from candidate loop before updating memory store territories. |
| **P0-5** | `backend/internal/store/postgres.go:350-353` | **P0** | Territory Defense | Union sets `strength = 100.0, last_defended_at = NOW(), cooldown_until = NOW() + 120min` for the player's whole MultiPolygon. A 10m loop heals all distant territory. | Implement area-weighted strength formula: `(old_eff_strength * undisturbed_area + 100.0 * (overlap_area + new_area)) / new_total_area`. |
| **P0-6** | `backend/internal/store/memory.go:439-442` | **P0** | Parity Defense | Memory store unconditionally resets territory strength to 100.0 and refreshes cooldown on any capture. | Compute area-weighted strength in memory store matching PostgreSQL formula. |
| **P0-7** | `lib/features/gameplay/territory_service.dart:317` | **P0** | Client Preview | Client optimistic preview unconditionally resets `strength = 100.0` for the entire unified territory MultiPolygon. | Update client `capturePolygonTerritory` to compute area-weighted strength matching server logic. |
| **P0-8** | `backend/internal/store/postgres.go:380` | **P0** | Bonus Inflation | Weak-rival bonus adds `loop.AreaSqMeters * 0.5` per intersecting weak rival (entire loop area rather than overlapped rival area). | Calculate weak bonus using `ST_Area(ST_Intersection(loop, rival)) * 0.5` per intersecting weak rival. |
| **P0-9** | `backend/internal/store/memory.go:372` | **P0** | Parity Bonus | Weak bonus adds `areaClaimed * 0.5` for every weak territory in memory regardless of geometric overlap. | Restrict weak bonus in memory store to intersecting weak rival paths scaled by overlap area. |
| **P0-10** | `backend/internal/store/postgres.go:377, 407` | **P0** | Data Duplication | `rivalsAffected` appends `rOwner` in both `checkRivalsQuery` and `diffQuery`, producing duplicate user IDs. | Deduplicate `rivalsAffected` using a set before returning `CaptureResult`. |
| **P0-11** | `backend/internal/store/postgres.go:345-357` | **P0** | Floor Semantics | Spatial union and rival clipping occur before the 25 m² floor check. Sub-floor loops mutate territory geometry while awarding 0 XP and 0 claimed area. | Pre-check net gained area (`net_new + stolen`) and abort territory mutation if below `MinCaptureFloorSqm (25 m²)`. |
| **P0-12** | `lib/features/gameplay/territory_service.dart:322` | **P0** | Client Floor | Client `capturePolygonTerritory` puts mutated `unifiedTerritory` into Hive before checking if `claimableSqM >= 25.0`. | Guard local Hive territory mutation with `claimableSqM >= minClaimAreaSqMeters`. |
| **P0-13** | `backend/internal/geo/intersection.go:20` | **P0** | Geometry Quality | `DoSegmentsIntersect` uses strict cross-product signs and ignores collinear overlaps. Out-and-back spurs create zero-width tails and invalid self-touching boundaries. | Add collinear segment overlap detection and spur trimming in Go geo engine. |
| **P0-14** | `lib/features/gameplay/polygon_enclosure_engine.dart:615` | **P0** | Parity Quality | `doSegmentsIntersect` in Dart client ignores collinear overlaps, allowing out-and-back spurs to form invalid polygons. | Add collinear segment overlap detection and spur trimming in Dart polygon engine. |
| **P0-15** | `backend/internal/store/postgres.go:618` | **P0** | Rankings Inflation | `GetLeaderboard` by activity queries `COALESCE(SUM(r.area_claimed), 0.0)` from historical runs, double-counting overlapping reruns. | Rank all-time leaderboard by current active owned territory (`territories.area_sqm`). |
| **P0-16** | `backend/internal/store/postgres.go:769, 781` | **P0** | League Accounting | `GetWeeklyStandings` sums raw `r.area_claimed` instead of net gained area (`net_new + stolen`). | Sum net gained area (`area_claimed + area_stolen`) for weekly standings. |
| **P0-17** | `backend/internal/store/postgres.go:1924` | **P0** | Crew Accounting | `GetCrewMembers` sums raw `r.area_claimed` for weekly crew goal contribution. | Sum net gained area for crew member contributions. |
| **P0-18** | `backend/internal/store/postgres.go:1429-1431` | **P0** | Duel Accounting | `UpdateDuelProgress` increments duel area progress with raw `areaClaimed`. | Increment duel area progress by net gained area (`net_new + stolen`). |
| **P0-19** | `backend/internal/store/postgres.go:1345, 1347, 1464, 1470` | **P0** | Swallowed Errors | Unchecked SQL execution errors on duel expiration and XP reward queries (`_, _ = s.pool.Exec(...)`). | Check and log errors returned from database execution on duel updates and user XP awards. |

---

## 2. P1 Findings (Must be fixed in this release)

| ID | File & Line | Severity | Category | Description | One-Line Fix |
|:---|:---|:---:|:---|:---|:---|
| **P1-1** | `backend/internal/geo/engine.go:313` | **P1** | Geometry Quality | Missing isoperimetric quotient thinness check ($4\pi A / P^2 < 0.02$). Long, paper-thin loops (e.g. 100m out and back 1m apart) pass validation. | Reject loops with $4\pi A / P^2 < 0.02$ with rejection reason "Loop too thin". |
| **P1-2** | `lib/features/gameplay/polygon_enclosure_engine.dart:519` | **P1** | Parity Quality | Dart client missing isoperimetric thinness check ($4\pi A / P^2 < 0.02$). | Reject loops with $4\pi A / P^2 < 0.02$ with rejection reason "Loop too thin". |
| **P1-3** | `backend/internal/store/postgres.go:348, 391` | **P1** | Geometry Hygiene | PostGIS queries lack sliver removal (< 2 m²) and hole filling (< 10 m²) after `ST_Union` and `ST_Difference`. | Clean output geometries by removing polygon rings < 2 m² and filling interior rings < 10 m². |
| **P1-4** | `backend/internal/store/postgres.go:586` | **P1** | Transaction Safety | `UpdateDuelProgress` is called after `tx.Commit()` outside the capture transaction. | Execute duel progress updates inside the atomic capture transaction. |
| **P1-5** | `backend/migrations/000001_init_schema.up.sql:40` | **P1** | Performance Index | Missing composite index on `runs(user_id, created_at DESC)` for daily XP cap query. | Add migration creating composite index `idx_runs_user_created ON runs(user_id, created_at DESC)`. |
| **P1-6** | `backend/migrations/000016_add_territory_cooldown.up.sql:1` | **P1** | Performance Index | Missing partial index on `territories(cooldown_until)` for conflict and decay queries. | Add index `idx_territories_cooldown ON territories(cooldown_until) WHERE cooldown_until IS NOT NULL`. |
| **P1-7** | `.github/workflows/ci.yml:5-15` | **P1** | CI Workflow | CI workflow branch trigger list lacks `final-release`, preventing CI runs on push. | Add `final-release` to `on.push.branches` and `on.pull_request.branches` in `ci.yml`. |
| **P1-8** | `test/ui/token_enforcement_test.dart:16-90` | **P1** | Design Tokens | 424 hardcoded font sizes exist across grandfathered files (`season_crew_view.dart`, `profile_dialogs.dart`, `faction_leaderboard.dart`, `auth_screen.dart`, etc.). | Refactor grandfathered widgets to use `AppText` design tokens and eliminate allowances. |
| **P1-9** | `lib/features/onboarding/onboarding_screen.dart:54` | **P1** | Performance Battery | Continuous repeating pulse animation runs indefinitely without pausing when off-screen. | Pause animation controller or gate with `TickerMode` when route is inactive. |
| **P1-10** | `lib/features/map/map_screen.dart:540` | **P1** | UX Battery | Missing low-battery (15%) detection prompt offering one-tap AMOLED battery saver mode. | Listen to device battery events and present calm prompt to enable AMOLED saver at <= 15%. |
| **P1-11** | `lib/features/map/widgets/run_hud.dart:120` | **P1** | Layout Contrast | Auto-pause and simulation chips in HUD can overlap if both active on compact 360dp width screens. | Wrap top status chips in a responsive `Wrap` or prioritized single indicator. |
| **P1-12** | `backend/internal/api/handlers.go:744-746` | **P1** | Input Validation | Error return values from `strconv.ParseFloat` on bbox coordinates are discarded with `_`. | Validate bbox float parsing and return HTTP 400 Bad Request on malformed query values. |

---

## 3. P2 Findings (Maintainability & Technical Debt)

| ID | File & Line | Severity | Category | Description | One-Line Fix |
|:---|:---|:---:|:---|:---|:---|
| **P2-1** | `lib/features/history/run_history_screen.dart:530` | **P2** | Feature Polish | Missing GPX export action for individual run logs. | Add GPX serialization and file share trigger to `HistoryRunCard`. |
| **P2-2** | `lib/features/history/widgets/history_run_card.dart:106` | **P2** | Feature Polish | Runs cannot be renamed or annotated with user notes. | Add title/note field to `RunLogEntry` and edit modal in run details. |
| **P2-3** | `lib/features/profile/widgets/challenges_shelf.dart:80` | **P2** | UI Feedback | Milestone badges don't display percentage progress towards next tier. | Add progress indicator on unearned milestone badges. |
| **P2-4** | `backend/internal/api/handlers.go:2035` | **P2** | Code Hygiene | `_ = json.NewEncoder(w).Encode(data)` discards write errors. | Log write errors when response encoding fails. |
| **P2-5** | `pubspec.yaml:19` | **P2** | Release Metadata | Version number is `1.0.0+1`; needs synchronization with release tagging. | Bump build number to match release milestone. |

---

## 4. P3 Findings (Nice to Have)

| ID | File & Line | Severity | Category | Description | One-Line Fix |
|:---|:---|:---:|:---|:---|:---|
| **P3-1** | `lib/models/weekly_recap.dart:1` | **P3** | Documentation | Add dartdoc comments to model fields and percentage calculation methods. | Add doc comments. |
| **P3-2** | `docs/ASSETS.md:1` | **P3** | Documentation | Update assets documentation to reflect latest audio and model files. | Synchronize documentation. |
