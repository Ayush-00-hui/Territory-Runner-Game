# Audio & Media Assets Reference

This document tracks all sound effects, icons, and media assets bundled within the Territory Runner application, certifying their origins and licensing terms.

---

## 🎵 Sound Effects (`assets/audio/`)

All sound effects bundled in Territory Runner are procedurally synthesized harmonic cues engineered specifically for high outdoor intelligibility without harsh audio clipping or high-frequency distortion.

| Asset File | Duration | Format | Audio Description | Source / Generator | License |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `sos_siren.wav` | 0.6s (loopable) | 22.05 kHz 16-bit Mono PCM | High-intensity pulsed dual-frequency siren (880 Hz / 587 Hz) for SafetyService emergency SOS distress beacon. | Procedural sine synthesis (Territory Runner Core) | **CC0 1.0 Universal / Public Domain** |
| `interval_work.wav` | 0.3s | 22.05 kHz 16-bit Mono PCM | Rising dual harmonic chime (587 Hz -> 880 Hz) signaling active run/work workout intervals. | Procedural sine synthesis (Territory Runner Core) | **CC0 1.0 Universal / Public Domain** |
| `interval_rest.wav` | 0.3s | 22.05 kHz 16-bit Mono PCM | Descending harmonic chime (659 Hz -> 440 Hz) signaling walk/rest recovery workout intervals. | Procedural sine synthesis (Territory Runner Core) | **CC0 1.0 Universal / Public Domain** |
| `countdown_tick.wav` | 0.1s | 22.05 kHz 16-bit Mono PCM | Short crisp acoustic tick cue for 3-2-1 countdown steps. | Procedural sine synthesis (Territory Runner Core) | **CC0 1.0 Universal / Public Domain** |
| `countdown_go.wav` | 0.25s | 22.05 kHz 16-bit Mono PCM | Rising two-tone chime signaling run launch. | Procedural sine synthesis (Territory Runner Core) | **CC0 1.0 Universal / Public Domain** |

---

## 🔤 Typography (`assets/fonts/`)

| Font Family | Styles | License | Source |
| :--- | :--- | :--- | :--- |
| **Inter** | Regular (400), SemiBold (600), Bold (700) | SIL Open Font License 1.1 | [Google Fonts / Rasmus Andersson](https://fonts.google.com/specimen/Inter) |

---

## 🖼️ Visual Icons (`assets/icons/`)

| Asset | Type | License | Source |
| :--- | :--- | :--- | :--- |
| `logo.png` | PNG Raster (1024x1024) | MIT License | Territory Runner Shield & Stride Crest Vector Render (`#0D0F11` Obsidian + `#A3C586` Calm Moss + `#F8FAFC` Alpine Snow) |
| `logo_foreground.png` | PNG Raster (1024x1024 Transparent) | MIT License | Android 12+ Adaptive Icon Foreground Layer (Shield & Stride Crest + Splash Logo) |
| `android/app/src/main/res/drawable/ic_notification.xml` | Android Monochrome VectorDrawable (24dp) | MIT License | Minimal white `#FFFFFF` Shield & Stride Crest silhouette for status bar notifications (`#A3C586` accent) |
| `mipmap-*`, `Assets.xcassets`, `web/icons` | Platform Icon & Splash Suites | MIT License | Generated via `flutter_launcher_icons` & `flutter_native_splash` |
| Material & Cupertino Icons | Vector glyphs | Apache 2.0 / MIT | Google Material Design / Apple Cupertino Icons |

---

## 🗺️ Map Tiles & Cartography Data

Territory Runner displays map tiles using OpenStreetMap data by default, with optional Mapbox styles when an API key is configured.

| Asset / Service | Provider | Attribution Required | Default License / Terms | Configuration Key |
| :--- | :--- | :--- | :--- | :--- |
| **Default Base Tiles** | [OpenStreetMap Foundation](https://www.openstreetmap.org) | `© OpenStreetMap contributors` | [Open Database License (ODbL)](https://www.openstreetmap.org/copyright) | `TILE_URL_TEMPLATE` |
| **Optional Dark Style** | [Mapbox](https://www.mapbox.com) | `© Mapbox, © OpenStreetMap` | [Mapbox Terms of Service](https://www.mapbox.com/legal/tos) | `MAPBOX_API_KEY` / `TILE_API_KEY` |

### OpenStreetMap Tile Usage Policy Compliance:
- **No Unsolicited Bulk Prefetching**: Bulk area prefetching is disabled by default (`ALLOW_TILE_PREFETCH=false`). Only areas actively navigated or viewed by the runner are cached locally.
- **Minimum 7-Day Caching**: The client caches viewed tiles with a minimum 7-day retention period (`minTileCacheDays = 7`) before conditional revalidation (`If-Modified-Since`), minimizing network load.
- **Identifiable User-Agent**: All map tile HTTP requests identify the application, version, and repository (`com.territoryrunner.app/1.0.0 (https://github.com/Ayush-00-hui/Territory-Runner-Game)`).
- **Prominent Attribution**: Attribution is displayed on the live map via `RichAttributionWidget` and in the Profile Settings under "Map Data & Attribution".

