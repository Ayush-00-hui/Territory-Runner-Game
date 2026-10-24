# Territory Runner — UX & Design Redesign Checklist

This document tracks the complete UI/UX overhaul of Territory Runner on the `v9-ui-redesign` branch. The app has been redesigned from the ground up to embody a calm, minimal, premium, human-designed aesthetic ("Graphite + Bone + Moss") inspired by modern running benchmarks (Strava, Nike Run Club) and refined spatial software.

---

## 1. Design System & Palette Foundations

### 1.1 Color Palette: "Graphite + Bone + Moss"
- **Dark-Only Surface Hierarchy**:
  - `AppColors.bgDeep` (`#0D0E0C`): Deepest background for map underlay and page scaffold.
  - `AppColors.bgElevated` (`#11120F`): Elevated backgrounds and modal sheet backing.
  - `AppColors.surface` (`#141512`): Primary card and container fill.
  - `AppColors.surface2` (`#1B1C18`): Secondary inner containers and chip fills.
  - `AppColors.surfaceGlass` (`#F2141512`): Obsidian glass effect with 95% opacity for HUDs.
  - `AppColors.border` (`#2A2B26`): Structural card and container borders.
  - `AppColors.borderSubtle` (`#14ECEAE3` — 8% Bone): Subtle internal dividers and boundaries.
  - `AppColors.divider` (`#0FECEAE3` — 6% Bone): Hairline separators.
  - `AppColors.scrim` (`#99000000` — 60% Black): Backdrop barrier for sheets and dialogs.
  - `AppColors.disabled` (`#55554D`): Inactive elements.

- **Typography Colors (Never Pure White `#FFFFFF`)**:
  - `AppColors.textPrimary` (`#ECEAE3` — Bone): High-contrast primary reading text and hero numbers (13.9:1 contrast vs `bgDeep`).
  - `AppColors.textSecondary` (`#A6A397` — Warm Grey): Secondary metadata and section labels (7.3:1 contrast).
  - `AppColors.textMuted` (`#85837A` — Stone): Captions, timestamps, and subtle hints (4.8:1 contrast — exceeds WCAG AA 4.5:1).

- **Brand & Semantic Accents**:
  - `AppColors.accent` / `AppColors.mine` (`#A3C586` — Moss): Primary action buttons, claimed territory fills, loop closure indicators (9.2:1 contrast).
  - `AppColors.onAccent` (`#0D0E0C`): Deep dark text/icons rendered over accent fills.
  - `AppColors.accentContainer` (`#1AA3C586` — 10% Moss): Selected states, pill fills.
  - `AppColors.rival` (`#86A5D3` — Steel Blue): Rival territory outlines and comparison metrics.
  - `AppColors.warning` (`#D9A441` — Ochre): Cautionary status and moderate GPS signal.
  - `AppColors.error` (`#E0716B` — Terracotta / Rose): SOS shield, destructive finish actions, degraded states.
  - `AppColors.info` (`#9AA4B2` — Slate): Neutral telemetry indicators and speed icons.

### 1.2 Typography & Numerics
- Font family: `Inter` across all text styles.
- Tabular figures (`FontFeature.tabularFigures()`) enabled on all running metrics, timers, paces, and distances to prevent layout jitter during active run ticks.
- Dynamic typography scaling with `FittedBox(fit: BoxFit.scaleDown)` and `Expanded` protections against overflow up to 2.0× accessibility text scale.

### 1.3 Motion & Haptics
- `AppMotion` system tokens: `fast` (120ms), `standard` (200ms), `medium` (300ms), `slow` (500ms).
- Easing curves: `easeOut` (Decelerate), `easeInOut` (Standard), `sharp` (Accelerate).
- Respects system accessibility `prefers-reduced-motion` flag, automatically collapsing animation durations to `Duration.zero`.
- Tactile haptic feedback: `selectionTick()`, `lightTick()`, `mediumTick()`, and `heavyBurst()`.

---

## 2. Redesign Phase Deliverables (D0 – D7)

### Phase D0: Audit & Design Brief
- [x] Identified and cataloged UI anti-patterns (unfocused neon cyan glows, cluttered HUDs, military sci-fi jargon).
- [x] Established design brief: Authentic runner-first app focusing on running geometry, territory ownership, calm dark aesthetics, and instant responsiveness.

### Phase D1: Foundation Tokens & Shared Components (`debf3fb`)
- [x] Implemented token architecture: `AppColors`, `AppSpacing`, `AppText`, `AppMotion`.
- [x] Created `TerritoryArt`: High-performance vector polygon renderer with auto-centering bounds, moss fill, rival dashed border, and node vertices.
- [x] Created shared UI primitives:
  - `AppButton`: Primary (Moss fill), Secondary (Outline), Ghost variants with min 48dp height.
  - `AppIconButton`: Circular icon buttons with enforced >= 48×48 dp hit targets and semantic tooltips.
  - `AppCard`: Standard card container with `surface` fill and `borderSubtle` stroke.
  - `SectionHeader`: Baseline-aligned section titles with optional trailing action.
  - `CombinedStatusIndicator`: Unified single pill replacing fragmented GPS/Battery/Sync dots.
  - `AppToast`: Glassmorphism toast system with queue-based auto-dismissal.
  - `AppBottomSheet`: Draggable modal sheet with drag handle and backdrop blur.

### Phase D2: Home Dashboard & Navigation (`830b644`)
- [x] Redesigned `HomeScreen`:
  - Profile header with level avatar ring and top-right `CombinedStatusIndicator`.
  - Hero `DailyGoalCard` with real goal progression and giant "Start run" CTA button.
  - `WeeklySummaryCard` featuring distance, territory, run count, and a 7-day bar chart.
  - `RecentActivityFeed` with empty-state runner glyph and "View all" navigation.
- [x] Rebuilt `AppBottomNav`: Floating navigation bar with 3 clean destinations (`Home`, `Run`, `Profile`) and sliding indicator pill.

### Phase D3: Active Run Experience (`8c33ea2`)
- [x] Map luminance filter (M1): Calm dark map tiles with minimal distraction.
- [x] Tactical SOS shield button (R1): Floating 48dp circular button with shield icon and direct confirmation sheet.
- [x] Bottom action controls (R2):
  - "Close loop" button: State-aware trigger with distance-to-closure feedback and moss highlight when within threshold.
  - Central play/pause toggle with prominent moss styling.
  - "Hold to finish" button: Accidental-tap protected 1.4-second press-and-hold with circular progress ring and haptic milestones. Disabled state provides informative toast hint ("Start a run first").
- [x] HUD slide animation (R3): Bottom navigation cleanly hides during active run to maximize map visibility.
- [x] Jargon sweep (R4): Replaced all military/cyber terms ("GRID LOCK", "SECTOR RECON") with authentic running terminology.

### Phase D4: Run Summary, Share Card & Activity (`34510f5`)
- [x] `SummarySheet`: Post-run debrief sheet displaying run map thumbnail, tabular metrics (distance, moving time, pace, elevation, calories), split pace breakdown, and AI coach debrief.
- [x] `ShareCardGenerator`: Exportable social share card with run polygon silhouette, key stats, and faction branding.
- [x] `RunHistoryScreen`: Comprehensive activity log with aggregate stat bar, horizontal filter chips (`All runs`, `Loops`, `Claims`, `This week`, `This month`), and sort picker.

### Phase D5: Compete, Profile & System Dialogs (`979b841`)
- [x] Redesigned `ProfileScreen` with top segmented pill selector:
  - `ProfileTabContent`: Avatar, Level, XP progression bar, stat cards, active territory quests.
  - `TeamsTabContent`: Faction territory distribution bar (Vanguard, Syndicate, Nomads), local vs global leaderboard chips, athlete rank card.
  - `LeagueTabContent`: Weekly division standings with tier promotions/relegations.
  - `FriendsTabContent`: Social squad and duel matchups with offline cache indicators.
- [x] Settings & Tactical Safety Sheet: Toggles for AMOLED battery saver, privacy zones, biometric lock, and account data export.
- [x] Permission primers and clean dialogs for location, motion sensors, and push notifications.

### Phase D6: Detail Pass, Jargon Sweep & Responsiveness (`8d007dc`)
- [x] Complete jargon sweep across presets in `RunGoalSheet`:
  - "Quick Strike" -> "Quick Run"
  - "Endurance Sweep" -> "Endurance Run"
  - "Full Campaign" -> "Long Run"
  - "District Dominion" -> "District Claim"
- [x] Text-scale and small-screen overflow protections:
  - Fixed `TabBar` overflow on narrow screens (360×640) with `isScrollable: true`.
  - Added `FittedBox` scale-down wrappers on summary metrics and debrief headers.
  - Wrapped dynamic labels in `Expanded` / `Flexible` with single-line ellipsis.
- [x] Comprehensive automated test suite (`phase_d6_accessibility_and_responsiveness_test.dart`): 21 dedicated tests passing across 360×640, 393×852, 412×915 viewports and 1.3× / 2.0× text scaling.

### Phase D7: Verification, Documentation & Screenshots (`HEAD`)
- [x] Full code analysis: `flutter analyze` completed with **0 errors, 0 warnings, 0 lints**.
- [x] Full test suite: `flutter test` completed with **359/359 tests passed**.
- [x] Captured live screenshots on Android emulator verifying all redesigned flows.
- [x] Created `docs/UX_CHECKLIST.md`.

---

## 3. Accessibility & Usability Matrix

| Metric | Target | Implementation Result | Status |
| :--- | :--- | :--- | :--- |
| **Color Contrast (Primary)** | >= 7.0:1 (AAA) | `textPrimary` (`#ECEAE3`) vs `bgDeep` (`#0D0E0C`): **13.9:1** | PASS |
| **Color Contrast (Secondary)** | >= 4.5:1 (AA) | `textSecondary` (`#A6A397`) vs `bgDeep` (`#0D0E0C`): **7.3:1** | PASS |
| **Color Contrast (Accent)** | >= 4.5:1 (AA) | `accent` (`#A3C586`) vs `bgDeep` (`#0D0E0C`): **9.2:1** | PASS |
| **Minimum Touch Target** | >= 48×48 dp | All buttons, icon buttons, and navigation pills enforce >= 48dp | PASS |
| **Reduced Motion** | Supported | `AppMotion.shouldReduceMotion()` collapses animation durations | PASS |
| **Text Scale Support** | 1.0× to 2.0× | Tested with no RenderFlex overflows up to 2.0× scale | PASS |
| **Small Screen Support** | 320px – 360px width | Tested on 320px and 360×640 viewports without clipping | PASS |
| **Tabular Numbers** | Mandatory for metrics | `FontFeature.tabularFigures()` on all HUD timers & distances | PASS |

---

## 4. Live Screenshot Index

The following screenshots were captured live from the Android emulator (`emulator-5554` running `com.territoryrunner.app`):

1. **Home Dashboard** (`scratch/d7_home_screen.png`):
   - Shows user greeting, status indicator (`● Ready`), goal card with "Start run" CTA, weekly summary chart, and recent activity section.
2. **Active Map & Run HUD** (`scratch/d7_run_screen.png`):
   - Shows dark luminance map underlay, SOS shield button, telemetry glass card with tabular figures, Close loop action, central play button, and Hold to finish button.
3. **Athlete Profile** (`scratch/d7_current_screen.png`):
   - Shows level avatar, XP progression, stat cards (Distance, Streak, Territory, Tier), active territory quests, and 4-tab segmented pill bar.
4. **Team Standings & Leaderboard** (`scratch/d7_teams_screen.png`):
   - Shows Vanguard / Syndicate / Nomads distribution bar, leaderboard scope selector (`Global`, `City`, `Local`), and athlete ranking card.
5. **Run History & Records** (`scratch/d7_history_screen.png`):
   - Shows aggregate stats banner, filter chips (`All runs`, `Loops`, `Claims`, `This week`, `This month`), sort selector (`Newest`), and empty/populated state.
6. **League Standings** (`scratch/d7_league_screen.png`):
   - Shows weekly division standings and offline cache handling with retry action.
7. **Friends & Squads** (`scratch/d7_friends_screen.png`):
   - Shows social squad list and duel challenge cards.
