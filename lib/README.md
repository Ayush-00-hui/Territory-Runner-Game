# Territory Runner — Flutter Client Architecture

The mobile client is built with Flutter 3.29+ (Dart 3.7+) following a Clean, Feature-First Architecture. It is designed for maximum offline resiliency, real-time spatial cartography, and high-contrast athletic readability.

---

## 🏛️ Directory Structure

```
lib/
├── core/               # Cross-cutting primitives (AppLogger, DateTime/Number formatters)
├── features/           # Domain features structured by business capability:
│   ├── auth/           # Firebase sign-in, Google Auth, anonymous guest upgrade
│   ├── coach/          # Google Gemini 2.5 Flash post-run athlete debriefs & pace prediction
│   ├── gallery/        # Trophy room & milestone achievement displays
│   ├── gameplay/       # Offline Shoelace enclosure, Clipper2 polygon math, territory models
│   ├── history/        # Run log history, elevation charts, shareable victory cards
│   ├── home/           # Above-the-fold athletic dashboard, streak flame, daily quests, AI forecast
│   ├── map/            # OpenStreetMap cartography, live GPS tracking HUD, closure bars, victory modal
│   ├── onboarding/     # First-run permissions primer, athletic callsign picker, faction selection
│   ├── profile/        # Runner profile, wardrobe, privacy zones, offline map tiles, settings
│   ├── routing/        # Biased closed-loop waypoint generator for target distances
│   ├── security/       # Real-time client-side kinematic anomaly detector
│   ├── social/         # Faction leaderboards, crew squads, head-to-head duels, friend activity feed
│   └── training/       # Interval workout plans, target pace alerts, audio cues
├── models/             # Domain entities and Hive TypeAdapters (Territory, RunLogEntry, RunnerProfile, etc.)
├── services/           # Infrastructure layer:
│   ├── api_client.dart           # HTTP client with retry policies and error mappings
│   ├── app_preferences.dart      # Local user preferences cache
│   ├── gps_distance_filter.dart  # Kalman distance smoothing & speed bounds
│   ├── sync_queue.dart           # Offline run sync queue backed by Hive AES-256
│   └── websocket_service.dart    # Live rival presence & territory broadcast client
├── ui/                 # Design System:
│   ├── motion/         # Purposeful athletic timing, haptic policies, BouncyTap, CelebrationBurst, StreakFlame
│   ├── theme/          # High-contrast Obsidian & Calm Moss design tokens (WCAG AAA)
│   └── widgets/        # Shared athletic UI components (PrimaryButton, StatTile, ProgressRing, etc.)
└── main.dart           # App entrypoint, service container initialization, and root routing
```
