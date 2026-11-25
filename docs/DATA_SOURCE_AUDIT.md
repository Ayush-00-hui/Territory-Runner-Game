# Data Source Audit: Profile, Compete & History Metrics

| Screen / Component | Metric / Number Displayed | Authoritative Source | Fallback / Offline Source | Synthetic / Mock Data Allowed? |
| :--- | :--- | :--- | :--- | :--- |
| **Profile** (`ProfileHero`) | Runner Username & Callsign | `RunnerProfile.username` (`Hive.box('profile')`) | Firebase Auth display name / default callsign | **NO** — 100% Real |
| **Profile** (`ProfileHero`) | Current Level | $\lfloor \text{xp} / 250 \rfloor + 1$ | Local Profile box computation | **NO** — 100% Real |
| **Profile** (`ProfileHero`) | Total Experience (XP) | `RunnerProfile.xp` | `Hive.box('profile')` | **NO** — 100% Real |
| **Profile** (`ProfileHero`) | Next Level XP Progress | `(xp % 250) / 250` | Mathematical modulo of real XP | **NO** — 100% Real |
| **Profile** (`ProfileHero`) | Faction Affiliation | `RunnerProfile.faction` | `Hive.box('profile')` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Total Distance | `RunnerProfile.totalDistanceKm` | Sum of `RunLogEntry.distanceM` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Active Running Streak | `RunnerProfile.currentStreak` | Consecutive calendar run days in `RunLogService` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Total Territory Area | $\sum \text{areaSqMeters}$ of user territories | `Hive.box('territories_v3')` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Average Pace (/km) | $\frac{\sum \text{movingSeconds}}{\sum \text{distanceKm}}$ across valid runs | `RunLogService.getAllRuns()` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Longest Run | $\max(\text{distanceM}) / 1000$ | `RunLogService.getAllRuns()` | **NO** — 100% Real |
| **Profile** (`ProfileStatGrid`) | Completed Runs Count | `RunLogService.getAllRuns().length` | Local encrypted run log (`run_log_v1`) | **NO** — 100% Real |
| **Profile** (`ChallengesShelf`) | Badges Earned | `RunnerProfile.badges` | `Hive.box('profile')` | **NO** — 100% Real |
| **Compete** (`WeeklyLeagueView`) | League Tier & Division | Server `/api/league/current` | Cached `SharedPreferences` | **NO** — 100% Real |
| **Compete** (`WeeklyLeagueView`) | Operative Weekly Area ($gained$) | Server Postgres $\sum gained$ (Net New + Stolen) | Local runs cached in `WeeklySummaryCard` | **NO** — 100% Real |
| **Compete** (`WeeklyLeagueView`) | Promotion / Relegation Zone | Server Division Table boundaries | Cached division snapshot | **NO** — 100% Real |
| **Compete** (`FactionLeaderboard`) | Faction Dominance (%) | Server PostGIS $\frac{\text{Faction Area}}{\text{Total Area}}$ | Local PostGIS / Polygon store | **NO** — 100% Real |
| **Compete** (`FactionLeaderboard`) | Faction Claimed Area | Server PostGIS $\text{ST\_Union}$ area in km² | Local territory cache | **NO** — 100% Real |
| **Compete** (`FactionLeaderboard`) | Active Operatives Count | Server `COUNT(DISTINCT owner_id)` past 7 days | Local active operatives | **NO** — 100% Real |
| **History** (`RunHistoryScreen`) | Total Claimed Area | $\sum \text{claimedAreaSqM}$ of logged runs | `RunLogService.runsNotifier` | **NO** — 100% Real |
| **History** (`RunHistoryScreen`) | Total History Distance | $\sum \text{distanceM} / 1000$ | `RunLogService.runsNotifier` | **NO** — 100% Real |
| **History** (`RunHistoryScreen`) | Personal Records (Fastest Km, Longest Run, Biggest Capture) | `RunLogService.computePersonalRecords()` | Evaluated from real GPS sample arrays | **NO** — 100% Real |
| **History** (`HistoryRunCard`) | Run Sample Coordinates, Splits, Elevation | Geodesic GPS points & elevation in `RunLogEntry` | Encrypted local storage | **NO** — 100% Real |
| **History** (`HistoryRunCard`) | Calorie Burn & Quantile | Calorie Surrogate ML Engine + Body Profile | Metabolic Equivalent (MET) formula | **NO** — 100% Real |
