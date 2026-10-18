# Timezone and Reset Boundary Architecture

## 1. Single Authoritative Server Epoch (Monday 00:00:00 UTC)

All competitive league cycles, leaderboard snapshots, and decay cadences in Territory Runner operate under a **single global canonical clock**: **UTC (Coordinated Universal Time)**.

Weekly leagues reset universally at:
$$\text{Reset Boundary} = \text{Monday 00:00:00 UTC}$$

```
                Sunday 23:59:59 UTC
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│               LEAGUE TIER RESOLUTION                   │
│   1. Top N% promoted (Diamond / Gold / Silver)         │
│   2. Bottom N% relegated                               │
│   3. Weekly stats reset: weekly_area = 0, runs = 0     │
└────────────────────────────────────────────────────────┘
                         │
                         ▼
                Monday 00:00:00 UTC
```

---

## 2. Rationale: Timezone Shopping & Arbitrage Defense

### Why not reset at each user's local midnight?
If weekly resets followed local midnight across the globe:
1. **Timezone Arbitrage**: A user in UTC+14 (Kiribati) would complete their week 26 hours ahead of a user in UTC-12 (Baker Island). A competitive runner could change device settings or VPN to an earlier timezone to inspect standings, then switch to a later timezone to snipe the promotion zone.
2. **Rolling Bracket Fragmentation**: Grouping players into competitive divisions requires a synchronized finish line. If participants in the same division have staggered deadlines, players who finish later have asymmetric knowledge of the exact score needed to win.
3. **Database Contention**: Staggered local midnights require 24 separate hourly batch jobs with timezone lookups. A single universal UTC boundary simplifies database transaction isolation and allows atomic promotion/relegation transitions.

---

## 3. Client Display & Local Conversion Rules

While the backend processes and calculates all deadlines in UTC:
1. **Wire Format**: Backend emits timestamps in strict ISO 8601 UTC format:
   ```json
   {
     "reset_at": "2026-10-26T00:00:00.000Z",
     "seconds_until_reset": 172800
   }
   ```
2. **Client Localization**: The Flutter client parses the ISO 8601 UTC string into a Dart `DateTime` and converts it via `.toLocal()` strictly at the presentation layer:
   ```dart
   final localReset = standing.resetAt.toLocal();
   // e.g., in IST (UTC+5:30): Monday 05:30 AM
   // e.g., in EST (UTC-5:00): Sunday 07:00 PM
   ```
3. **UI Badging**: The `WeeklyLeagueView` renders:
   - Live real-time countdown badge (`1d 14h 22m` / `HH:mm:ss`) derived from `secondsUntilReset`.
   - Local day/time descriptor: `Ends Mon 05:30 (Local)` alongside canonical `Resets Monday 00:00 UTC`.

---

## 4. Server-Side Timestamp Hygiene

GPS track submissions (POST `/v1/runs`) undergo strict temporal validation:
1. **Future Clock Protection**: Any track point with `timestamp > server_now + 10 minutes` is rejected (`400 Bad Request`, `FUTURE_TIMESTAMPS`). The 10-minute buffer accommodates modest client NTP drift without permitting forward-dating.
2. **Expiration Protection**: Runs older than 14 days (`timestamp < server_now - 14 days`) are rejected (`400 Bad Request`, `EXPIRED_RUN`). This prevents stale offline backlogs from unexpectedly upsetting historical league standings.
3. **Monotonicity**: Points must arrive in strictly ascending temporal sequence ($t_{i} \ge t_{i-1}$). Time travel or reordered batches are rejected (`NON_MONOTONIC_TIMESTAMPS`).
