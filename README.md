# 🏃 Territory Runner — Server-Authoritative Real-Time GPS Territory Capture

<div align="center">

```
  _______             _ _                     _____                                 
 |__   __|           (_) |                   |  __ \                                
    | | ___ _ __ _ __ _| |_ ___  _ __ _   _  | |__) |   _ _ __  _ __   ___ _ __     
    | |/ _ \ '__| '__| | __/ _ \| '__| | | | |  _  / | | | '_ \| '_ \ / _ \ '__|    
    | |  __/ |  | |  | | || (_) | |  | |_| | | | \ \ |_| | | | | | | |  __/ |       
    |_|\___|_|  |_|  |_|\__\___/|_|   \__, | |_|  \_\__,_|_| |_|_| |_|\___|_|       
                                       __/ |                                        
                                      |___/                                         
```

**Real-Time Server-Authoritative Location-Based Athletic Fitness Platform**  
*Enclose arbitrary closed-loop GPS territory polygons on a crisp, calm athletic map. Defend land from rivals, build daily exploration streaks, race ghosts, climb weekly competitive league tiers, and receive post-run AI coaching.*

<br>

[![CI](https://github.com/Ayush-00-hui/Territory-Runner-Game/actions/workflows/ci.yml/badge.svg)](https://github.com/Ayush-00-hui/Territory-Runner-Game/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/Ayush-00-hui/Territory-Runner-Game/branch/main/graph/badge.svg)](https://codecov.io/gh/Ayush-00-hui/Territory-Runner-Game)
[![Flutter Tests](https://img.shields.io/badge/Flutter_Tests-743%20Passing-00F59B.svg?style=flat-square&logo=flutter&logoColor=black)](test/)
[![Go Tests](https://img.shields.io/badge/Go_Tests-11%20Packages_Passing-00ADD8.svg?style=flat-square&logo=go&logoColor=white)](backend/)
[![Cartography](https://img.shields.io/badge/Cartography-OpenStreetMap_Standard-00C6FF.svg?style=flat-square&logo=openstreetmap&logoColor=white)](lib/features/map/widgets/map_layers.dart)
[![Theme Palette](https://img.shields.io/badge/Theme-Calm_Moss_&_Neutral_Obsidian-A3C586.svg?style=flat-square)](lib/ui/theme/app_colors.dart)
[![Game Mechanics](https://img.shields.io/badge/Mechanics-Dynamic_Loop_&_120--Min_Shield-46663A.svg?style=flat-square)](docs/MECHANICS.md)
[![Encrypted Storage](https://img.shields.io/badge/Storage-Hive_AES--256-blueviolet.svg?style=flat-square&logo=keybase&logoColor=white)](lib/services/hive_encryption_service.dart)
[![Threat Model](https://img.shields.io/badge/Security-STRIDE_Threat_Model-critical.svg?style=flat-square&logo=shield&logoColor=white)](docs/THREAT_MODEL.md)
[![AIML Anti-Cheat](https://img.shields.io/badge/AIML_AntiCheat-LightGBM_&_PyTorch_LOUO-9C27B0.svg?style=flat-square&logo=scikitlearn&logoColor=white)](docs/AIML_EVALUATION.md)
[![Static Analysis](https://img.shields.io/badge/Flutter_Analyze-0_Issues-4C8DFF.svg?style=flat-square&logo=dart&logoColor=white)](lib/)
[![Code Formatting](https://img.shields.io/badge/Format-Clean_325_Dart_Files-green.svg?style=flat-square)](lib/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B.svg?style=flat-square&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.13.2+-0175C2.svg?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Go](https://img.shields.io/badge/Go-1.26+-00ADD8.svg?style=flat-square&logo=go&logoColor=white)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_PostGIS_3.4-4169E1.svg?style=flat-square&logo=postgresql&logoColor=white)](https://postgis.net/)
[![Docker](https://img.shields.io/badge/Docker-Compose_Ready-2496ED.svg?style=flat-square&logo=docker&logoColor=white)](docker-compose.yml)
[![Auth](https://img.shields.io/badge/Auth-Firebase_RS256_JWT-FFA000.svg?style=flat-square&logo=firebase&logoColor=white)](backend/internal/auth/)
[![Push Alerts](https://img.shields.io/badge/Push_Alerts-FCM_HTTP_v1-FFCA28.svg?style=flat-square&logo=firebase&logoColor=black)](backend/internal/notify/)
[![AI Coach](https://img.shields.io/badge/AI_Coach-Google_Gemini_2.5_Flash-4285F4.svg?style=flat-square&logo=google&logoColor=white)](backend/internal/coach/)

<br>

[Level 0: Concept](#-level-0-the-high-altitude-concept--paradigm) • [Level 1: Quickstart](#-level-1-fast-track-onboarding-zero-to-running-in-5-minutes) • [Structure](#-repository-file--folder-structure) • [Level 2: Gameplay](#-level-2-gameplay-mechanics--athlete-experience) • [Level 3: Mobile](#-level-3-mobile-client-engineering--offline-resiliency-flutter) • [Level 4: Backend](#-level-4-backend-engineering--distributed-spatial-systems-go--postgis) • [Level 5: Security](#-level-5-cryptography-privacy--zero-trust-security) • [Level 6: AI/ML](#-level-6-machine-learning--anti-cheat-pipeline) • [Level 7: Master](#-level-7-master-level-testing-verification--production-ops) • [Dossiers](#-technical-documentation--defense-dossiers)

</div>

---

## 🗺️ Master Curriculum: Level 0 to Master

This document is organized as a structured **Level 0 to Master** curriculum. Whether you are a first-time developer exploring the codebase, an athlete understanding the game mechanics, or a senior distributed systems architect examining spatial concurrency, this guide covers every layer of the system.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                TERRITORY RUNNER ROADMAP                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 🧭 Level 0: The High-Altitude Concept & Paradigm                                       │
│    └─ Why standard fitness trackers fall short | Comparative matrix | Architecture     │
│ ⚡ Level 1: Fast-Track Onboarding (0 to Running in 5 Minutes)                           │
│    └─ Docker Compose Full-Stack | Hermetic In-Memory Mode | Mobile & Desktop setup     │
│ 📁 Repository Structure: Clean Modular Layout & Architecture Boundaries                │
│    └─ Flutter client lib/ | Go backend/ | Python ml/ | Golden fixtures | Docs & tools │
│ 🎮 Level 2: Gameplay Mechanics & Daily Habit Experience                                │
│    └─ Dynamic loop closure | 120-min Shield | Daily Quests | 100m Grid | Ghost | Plans │
│ 📱 Level 3: Mobile Client Engineering & Offline Resiliency (Flutter)                   │
│    └─ Instant GNSS warm-up | ZUPT stationary filter | Calm Moss design | Hive FIFO     │
│ 🖥️ Level 4: Backend Engineering & Distributed Spatial Systems (Go + PostGIS)           │
│    └─ pg_advisory_xact_lock | PostGIS ST_Difference | Team validation | WebSocket Hub │
│ 🔒 Level 5: Cryptography, Privacy & Zero-Trust Security                                │
│    └─ Firebase RS256 JWT verifier | Dual-layer privacy zones | Anti-abuse duels        │
│ 🤖 Level 6: Machine Learning & Anti-Cheat Pipeline (LightGBM + PyTorch)                │
│    └─ Tier 1 deterministic gate | 311k-window GeoLife eval | Calorie & Pace models     │
│ 🏆 Level 7: Master Level (Testing, Audits, Verification & Production Ops)             │
│    └─ Full Flutter + 11 Go package suites | CI/CD gates | Viva defense cheatsheet      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

<a id="dossiers"></a><a id="-technical-documentation--defense-dossiers"></a>
## 📚 Technical Documentation & Defense Dossiers

Every dimension of the platform's distributed systems, mathematics, security posture, and athletic biomechanics is formally specified across dedicated engineering dossiers:

| Engineering Dossier | Primary Scope & Contents | Target Audience |
| :--- | :--- | :--- |
| **[Game Mechanics & Territorial Sovereignty](docs/MECHANICS.md)** | Authoritative specification of dynamic loop closure ($20\text{m} \le 1.5\sigma \le 45\text{m}$), 120-minute (2h) territory defense cooldown shield, ZUPT stationary drift prevention, and simulated run sync isolation. | Game Designers, Engineers, Reviewers |
| **[Study Notes & Architecture Dossier](docs/STUDY_NOTES.md)** | Comprehensive 8-module textbook covering spatial algorithms, distributed concurrency, ML pipelines, and protocol references. | Engineers, Researchers, Examiners |
| **[STRIDE Threat Model](docs/THREAT_MODEL.md)** | Formal security analysis across Spoofing, Tampering, Repudiation, Info Disclosure, DoS, and Elevation of Privilege. | Security Engineers, Auditors |
| **[Master Viva Defense Cheatsheet](docs/VIVA.md)** | 335-line comprehensive defense of all architectural trade-offs (`pg_advisory_xact_lock`, Clipper2, Shoelace vs PostGIS, lazy decay). | Examiners, Interviewers |
| **[AIML Technical Dossier](docs/AIML_EVALUATION.md)** | Statistical proofs, ROC/PR curves, hyperparameter optimization, and parity tests for the LightGBM & neural anti-cheat models. | ML Engineers, Data Scientists |
| **[Activity Type Fairness & Calibration](docs/ACTIVITY_FAIRNESS.md)** | Mathematical speed envelopes, biomechanical cadence constraints, and MET energy expenditure equations across Running, Walking, and Cycling. | Sports Scientists, Product |
| **[Production Deployment Specification](docs/DEPLOYMENT.md)** | Multi-stage Docker containers, Render deployment, PostgreSQL 16 PostGIS tuning, and production Docker Compose stacks. | DevOps, SREs |
| **[App Store & Play Store Readiness](docs/STORE_READINESS.md)** | Android 14 `FOREGROUND_SERVICE_LOCATION` compliance, iOS Background Modes, and privacy manifest audits. | Release Engineers, Mobile Leads |
| **[UX Design System & WCAG AA Audit](docs/UX_CHECKLIST.md)** | High-contrast Calm Moss + Neutral Obsidian design tokens, tabular typography rules, and automated contrast verification. | UI/UX Designers, Accessibility |
| **[Calorie & Energy Expenditure Engine](docs/CALORIES.md)** | Peer-reviewed physiological energy expenditure (ACSM, Minetti, Mifflin-St Jeor), monotone-constrained ML surrogate, and zero-knowledge DPDP privacy. | Sports Scientists, ML Engineers, Athletes |
| **[Privacy Policy & Geodata Architecture](docs/PRIVACY.md)** | Sensitive geodata collection, client-side redaction, server-enforced privacy exclusion zones, and complete account erasure. | Security Engineers, Privacy Officers, Athletes |
| **[Audio, Fonts & Cartography Assets](docs/ASSETS.md)** | OpenStreetMap tile usage compliance, synthetic harmonic audio specs, and font licensing certifications. | Compliance, Cartographers, Designers |
| **[College Defense Presentation Suite](docs/presentation/)** | 3-minute individual defense speeches (Ayush, Avinash, Gurudutt), 10-minute master team deck, and work breakdown matrices. | Faculty Reviewers, Candidates |

---

<a id="level-0"></a><a id="-level-0-the-high-altitude-concept--paradigm"></a>
## 🧭 Level 0: The High-Altitude Concept & Paradigm

### The Problem with Traditional Fitness Trackers
Traditional fitness trackers (Strava, Nike Run Club, Apple Fitness) record passive 1D linear polylines. They measure distance and pace, but offer no spatial ownership, territorial sovereignty, or real-time tactical motivation. 

Conversely, first-generation location-based games (Ingress, Pokémon GO, Turf) constrain players to rigid discrete cells—either Google S2 cells, Uber H3 hexagons, or fixed point-of-interest portals. They turn running into stop-and-go screen tapping rather than authentic athletic movement.

### The Territory Runner Paradigm
**Territory Runner** bridges this gap:
1. **Continuous 2D Organic Polygons:** Athletes claim arbitrary closed-loop polygons around city blocks, parks, or running tracks without rigid grid discretization.
2. **True Athletic Momentum:** Run, jog, walk, or cycle continuously. Crossing your earlier trail automatically triggers mathematical lasso snapping and enclosure without breaking stride.
3. **Server-Authoritative Spatial Integrity:** All territory operations (`ST_Union`, `ST_Difference`, geodesic area calculation) are validated and executed by PostgreSQL 16 + PostGIS 3.4 inside transaction-scoped advisory locks, eliminating spatial race conditions and cheating.

```
🏃 Athlete Runs Closed Loop ──► 🛰️ Kinematic Filter ──► 📐 Shoelace Area Metric
                                                                │
🏆 PostGIS Authority ◄── ☁️ Offline Sync Queue ◄── ✂️ Clipper2 Optimistic Preview
```

---

### Comparative Analysis Matrix

| Capability | Standard Trackers (Strava, Nike) | Grid GPS Games (Ingress, Turf) | Territory Runner |
| :--- | :--- | :--- | :--- |
| **Spatial Model** | Passive 1D linear breadcrumbs | Rigid discrete cells (S2 / H3 hexes) | **Continuous arbitrary organic 2D polygons** |
| **Enclosure Mechanism** | None | Fixed geographic portal linking | **Dynamic GPS-scaled loop closure ($20-45\text{m}$) + 120-minute (2h) PostGIS & Clipper2 defense shield** |
| **Concurrency Control** | Independent tracks, no conflict | Optimistic locks with retry aborts | **Transaction-scoped PostGIS advisory lock (`pg_advisory_xact_lock`)** |
| **Offline Capability** | Records track, no gameplay | Fails without active cell signal | **Dual-engine: local Clipper2 optimistic preview + Hive FIFO queue** |
| **Screen-Lock GPS** | Standard OS background tracking | Often throttled by OS battery management | **Hardened foreground service with sticky notification & CPU wakelock** |
| **Anti-Cheat Validation** | Post-hoc manual flag reviews | Basic speed thresholds | **Tier 1 Kinematic Gate + Tier 2 LightGBM 22-feature ML ensemble (LOUO-CV)** |
| **Privacy Safeguards** | Client-only map blur | None | **Dual-layer: client redaction + server-side geodesic suppression in WebSockets** |
| **Rival Alerts** | None | Delayed batch emails | **Real-time WebSocket alerts + FCM HTTP v1 background push** |
| **Map Cartography** | Standard map SDK | Low-detail raster / custom vector | **OpenStreetMap standard basemaps (clean, unwatermarked, keyless) with optional CARTO/Mapbox layers** |
| **Auto-Pause Engine** | Basic threshold, pauses at start line | None (battery drain) | **Athletic hysteresis ($< 2.5 \to \ge 3.0\text{ km/h}$) + start-line suppression gate + 10s grace window** |
| **Visual Aesthetic** | Cluttered social feed | Neon, gamified arcade glare | **Calm Moss (`#A3C586`) + Neutral Obsidian (`#0D0F11`) + Muted Terracotta (`#C25946`) with <90ms touch feedback** |

---

### System Architecture Overview

```mermaid
graph TD
    subgraph Client ["Flutter Mobile Client (Offline-First & Background Hardened)"]
        UI[Tactical Map HUD & Obsidian Design System]
        GNSSPreWarm[Instant GNSS Warm-up & Last Known Position]
        ForegroundService[Foreground Location Service & Sticky Notification]
        WakeLockMgr[Wakelock Keep-Alive Manager]
        CrashBox[(Hive Crash Recovery Box)]
        SignalFilter[Signal Gap Segmentation & Kinematic Filter]
        ClaimPlanner[Explore Claim Planner & Net-New Area]
        LocalEngine[Clipper2 Optimistic Engine & Loop Enclosure]
        HiveQueue[(Hive Offline Sync Queue)]
        ApiClient[ApiClient with Exponential Backoff & 4xx Halt]
        HoleClassifier[Ray-Casting Hole Classifier]
        LeagueView[Weekly League View & Percentile HUD]
        
        ForegroundService --> SignalFilter
        GNSSPreWarm --> ForegroundService
        WakeLockMgr --> ForegroundService
        SignalFilter --> CrashBox
        SignalFilter --> LocalEngine
        UI --> ClaimPlanner
        ClaimPlanner --> LocalEngine
        LocalEngine --> HiveQueue
        HiveQueue --> ApiClient
        UI --> HoleClassifier
        UI --> LeagueView
    end

    subgraph Backend ["Go Server-Authoritative Backend (:8080)"]
        ChiRouter[Chi HTTP Router]
        MiddlewareStack[RequestID, Logger, RateLimiter, BodyLimit, CORS Whitelist]
        AuthVerifier[Firebase Auth RS256 JWT Verifier]
        TeamValidator[Unicode NFKC Team Name Validator & Rate Limiter]
        AntiCheat[Kinematic Anomaly & Spoofing Mitigation]
        GoGeoEngine[Go Geo Enclosure Engine & Shoelace]
        AdvisoryLock[Transaction-Scoped Spatial Advisory Lock]
        WSHub[Real-Time WebSocket Hub with Singleflight]
        CoachProxy[Gemini LLM Coach Proxy & Smart Fallback]
        LeagueEngine[Weekly League Engine & Monday UTC Resets]
        FCMSender[FCM HTTP v1 Client with OAuth2 RS256 JWT]

        ChiRouter --> MiddlewareStack
        MiddlewareStack --> AuthVerifier
        AuthVerifier --> AntiCheat
        AuthVerifier --> GoGeoEngine
        AuthVerifier --> WSHub
        AuthVerifier --> CoachProxy
        AuthVerifier --> LeagueEngine
        GoGeoEngine --> AdvisoryLock
        AdvisoryLock --> FCMSender
    end

    subgraph Persistence ["Spatial Persistence Layer"]
        PostGIS[(PostgreSQL 16 + PostGIS 3.4)]
        GiSTIndex[GiST Spatial Index on geom]
        DeviceTokens[(device_tokens Table)]
        MemStore[(Hermetic In-Memory Dev Store)]
        
        AdvisoryLock --> PostGIS
        PostGIS --- GiSTIndex
        FCMSender --> DeviceTokens
        AdvisoryLock -.->|Local Dev Fallback| MemStore
    end

    subgraph External ["External Services"]
        OSRM[OSRM Pedestrian Graph Routing]
        Gemini[Google Gemini 2.5 Flash API]
        FCMService[Firebase Cloud Messaging HTTP v1 API]
        GoogleOAuth[Google OAuth2 Token Service]
        TileServer[OpenStreetMap / CARTO Basemap Tile Servers]
    end

    ApiClient -->|HTTP REST /v1| ChiRouter
    ApiClient -->|WebSocket /v1/ws| WSHub
    FCMSender -->|RS256 JWT Assertion| GoogleOAuth
    FCMSender -->|Push Dispatch| FCMService
    ClaimPlanner -->|Pedestrian Route Query| OSRM
    CoachProxy -->|Server-Side Key Isolation| Gemini
    UI -->|Map Tiles| TileServer
```

---

### Run Conquest Lifecycle Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Athlete as 🏃 Athlete
    participant GPS as 🛰️ GPS & Foreground Service
    participant Client as 📱 Flutter Client (Clipper2)
    participant Hive as 💾 Hive Storage
    participant API as 🌐 Go Chi API (:8080)
    participant Lock as 🔒 pg_advisory_xact_lock
    participant DB as 🐘 PostgreSQL / PostGIS 3.4
    participant FCM as 📲 FCM HTTP v1
    participant Rival as 🏃 Rival Athlete

    Athlete->>GPS: Starts Outdoor Workout Session
    GPS->>Client: Continuous GPS Point Stream (1 Hz)
    Client->>Hive: Flushes point to active_run_recovery (Crash Recovery)
    Athlete->>GPS: Crosses Previous Track (Lasso Closure)
    Client->>Client: Detects Loop Closure & Computes Clipper2 Optimistic Area
    Client->>UI: Renders Instant Optimistic Sector on Map
    Athlete->>Client: Finishes Run (Hold-To-Finish 1400ms)
    Client->>Hive: Enqueues Run into Persistent FIFO Sync Queue
    Hive->>API: POST /v1/runs (with Idempotency Key & Raw Points)
    API->>API: Verifies Firebase RS256 JWT Token & Checks Rate Limit
    API->>API: Evaluates Kinematic Anomaly Window (Speed, Accel, Replay)
    API->>Lock: Acquires pg_advisory_xact_lock(hashtext('territory_mutation_lock'))
    API->>DB: ST_MakeValid(ST_PolygonFromText(Loop))
    API->>DB: ST_Union into Runner Sovereign Geometry
    API->>DB: ST_Difference against Overlapping Rival Territories
    DB-->>API: Returns Net Claimed Area, New Total Area & Affected Rivals
    API->>DB: Commits Spatial Mutation Transaction & Releases Lock
    API-->>Client: Returns HTTP 201 Created (Claimed Area, XP, Status)
    Client->>Hive: Dequeues Run from Sync Queue & Clears Crash Box
    Client->>UI: Displays Area Reconciliation Toast if Server Area Differs
    
    par Async Push Notification Fan-Out
        API-)FCM: Signs RS256 Assertion & Dispatches Push Alert (5s Timeout)
        FCM-)Rival: "Your territory in Sector 4 was carved by Runner X"
    and Real-Time WebSocket Broadcast
        API-)Rival: WS Broadcast `territory_under_attack` HUD Alert
    end
```

---

<a id="level-1"></a><a id="-level-1-fast-track-onboarding-zero-to-running-in-5-minutes"></a>
## ⚡ Level 1: Fast-Track Onboarding (Zero to Running in 5 Minutes)

### Prerequisites

| Tool | Version Requirement | Purpose |
| :--- | :--- | :--- |
| **Go** | 1.26+ (`backend/go.mod`) | Server compilation, spatial math, WebSocket hub |
| **Flutter SDK** | Stable (Dart 3.13.2+) | Cross-platform client (Android / iOS / Web / Desktop) |
| **Docker & Compose** | v2.20+ (optional in dev) | Multi-stage backend build & PostGIS spatial database |
| **Android SDK / Xcode** | Android 13+ (API 33+) / iOS 15+ | Mobile deployment targets |

---

### Path A: Full Stack with Docker Compose (Recommended)

This spins up PostgreSQL 16 with PostGIS 3.4 and runs the Go backend server automatically:

```bash
# 1. Clone Repository
git clone https://github.com/Ayush-00-hui/Territory-Runner-Game.git
cd Territory-Runner-Game

# 2. Launch PostgreSQL 16 + PostGIS 3.4 & Server
docker compose up -d

# 3. Verify Health & Database Readiness
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

The server listens on `http://localhost:8080` (or `http://localhost:8081` when `PORT=8081` is configured in `backend/.env`) with PostGIS on port `5432`. Built-in SQL migrations (`000001`–`000018`, 36 files) run automatically on startup when `RUN_MIGRATIONS=true`.

---

### Path B: Hermetic In-Memory Dev Store (Zero Docker Required)

If you don't have Docker or PostgreSQL installed, you can launch the backend locally using its hermetic in-memory store (`ENV=development` with empty `DATABASE_URL`):

```bash
cd backend

# On Linux/macOS:
export ENV=development
export AUTH_MODE=dev
go run ./cmd/server

# On Windows PowerShell:
$env:ENV="development"
$env:AUTH_MODE="dev"
go run ./cmd/server
```

On startup, the server auto-loads `backend/.env` (if present, without overriding existing shell variables) and initializes an in-memory store with REST, WebSocket, anti-cheat, social, and AI coaching endpoints.

---

### Path C: Launching the Flutter Client

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Verify formatting, static analysis, and tests
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --timeout 120s

# 3. Launch on Android Emulator or Physical Device
flutter run -d emulator-5554
# For a physical phone on your local Wi-Fi / hotspot:
flutter run --dart-define=API_BASE_URL=http://<YOUR_LAN_IP>:8080

# 4. Launch on Windows Desktop or Chrome Web
flutter run -d windows
flutter run -d chrome
```

> [!IMPORTANT]
> **Client API Endpoint Resolution (`lib/services/api_client.dart`):**  
> - By default, Android builds target `http://10.0.2.2:8080` (Android Emulator host loopback), while Web/Desktop builds target `http://localhost:8080`.  
> - For an emulator using `localhost` forwarding, run `adb reverse tcp:8080 tcp:8080` and pass `--dart-define=API_BASE_URL=http://localhost:8080`.  
> - For a physical phone or hosted backend (Render / Railway / VPS), pass `--dart-define=API_BASE_URL=http://<LAN_IP>:8080` or `https://your-backend-host`.

---

### Environment Variables Configuration

Copy `backend/.env.example` to `backend/.env` to configure local or production settings (see [`backend/internal/config/config.go`](backend/internal/config/config.go) and [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)):

```env
# Server
PORT=8080
ENV=development               # 'development' | 'staging' | 'production' (default: 'production')
AUTH_MODE=dev                 # 'firebase' (default) | 'dev' (strictly requires ENV=development)
RUN_MIGRATIONS=true           # Automatically runs embedded migrations on startup

# Database (Leave empty in ENV=development to use hermetic in-memory store)
DATABASE_URL=postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable

# Firebase RS256 Authentication (Required when AUTH_MODE=firebase)
FIREBASE_PROJECT_ID=territory-runner

# FCM HTTP v1 Push Notifications (Optional; also supports GOOGLE_APPLICATION_CREDENTIALS)
FIREBASE_SERVICE_ACCOUNT_JSON=backend/service-account.json

# Security & Reverse Proxy
ALLOWED_ORIGINS=              # Comma-separated CORS/WS origins (required in production unless ALLOW_ANY_ORIGIN=true)
METRICS_TOKEN=                # Optional Bearer token protecting GET /metrics
TRUSTED_PROXIES=              # Comma-separated CIDRs/IPs trusted for X-Forwarded-For / X-Real-IP

# Google Gemini AI Athletic Coach (Optional - falls back to sports science rule heuristics)
GEMINI_API_KEY=AIzaSy...
GEMINI_MODEL=gemini-2.5-flash

# Anti-Cheat & Limits
ENABLE_CADENCE_MODEL=false
MAX_POINTS_PER_RUN=20000
MAX_RUN_DURATION_SECONDS=86400
```

---

<a id="structure"></a><a id="-repository-file--folder-structure"></a>
## 📁 Repository File & Folder Structure

Territory Runner follows a clean modular, domain-driven, and offline-first architecture. The monorepo encapsulates the mobile Flutter client, high-throughput Go spatial backend, Python anti-cheat machine learning pipelines, formal engineering dossiers, and comprehensive verification test fixtures.

```
territory_runner/
├── assets/                     # Packaged runtime assets
│   ├── audio/                  # Harmonic cue audio (countdown tick/go, intervals, SOS siren)
│   ├── fonts/                  # Inter typography fonts (Regular, SemiBold, Bold)
│   ├── icons/                  # Vector-rendered Shield & Stride crest (`logo.png`, `logo_foreground.png`)
│   ├── models/                 # LightGBM trees, ONNX anti-cheat, Calorie & Pace quantile models
│   └── loading_quotes.json     # Motivational athletic mindset quotes
├── backend/                    # High-throughput Go 1.26 Spatial Backend
│   ├── cmd/server/             # HTTP & WebSocket entrypoint (main.go)
│   ├── internal/               # Server-authoritative domain packages (11 test packages)
│   │   ├── anticheat/          # Tier 1 Kinematic gate, motion window & replay auditing
│   │   ├── api/                # Chi REST router, rate-limiter, moderation & request handlers
│   │   ├── auth/               # Firebase RS256 JWT verifier with cached Google certs
│   │   ├── coach/              # Google Gemini 2.5 Flash proxy & physiology heuristics
│   │   ├── config/             # Environment variable loading & production safety checks
│   │   ├── geo/                # PostGIS spatial math, Shoelace area & dynamic loop closure
│   │   ├── league/             # Weekly tier promotions, percentile ranks, Monday UTC resets
│   │   ├── notify/             # Firebase Cloud Messaging (FCM) HTTP v1 push dispatcher
│   │   ├── store/              # PostgreSQL 16 + PostGIS 3.4 & hermetic in-memory stores
│   │   └── ws/                 # Real-time WebSocket hub with singleflight concurrency
│   ├── migrations/             # 18 transactional SQL migration pairs (000001 - 000018, 36 files)
│   └── Dockerfile              # Multi-stage lightweight scratch/alpine production build
├── bin/                        # Standalone Dart CLI tools (`generate_interval_audio.dart`)
├── docs/                       # Technical defense dossiers & specifications
│   ├── presentation/           # Defense decks, speaker notes, and architecture visuals
│   ├── ACTIVITY_FAIRNESS.md    # Multi-sport kinematic speed/cadence envelopes
│   ├── AIML_EVALUATION.md      # Statistical validation of LightGBM & neural anti-cheat
│   ├── ASSETS.md               # Audio synthesis, OpenStreetMap tile, icon & font licenses
│   ├── CALORIES.md             # ACSM/Minetti metabolic calculation & ML surrogate proof
│   ├── DEPLOYMENT.md           # Production Docker Compose, Render & PostgreSQL tuning
│   ├── MECHANICS.md            # Authoritative game mechanics, dynamic loops & 120-min shield
│   ├── PRIVACY.md              # Dual-layer privacy zones & geodata redaction policies
│   ├── STORE_READINESS.md      # Android 14 Foreground Service & iOS Background Modes
│   ├── STUDY_NOTES.md          # 8-module comprehensive systems engineering textbook
│   ├── THREAT_MODEL.md         # STRIDE security audit & defense-in-depth matrix
│   ├── UX_CHECKLIST.md         # WCAG AAA/AA contrast audit & Calm Moss design rules
│   └── VIVA.md                 # Comprehensive viva defense cheatsheet
├── integration_test/           # End-to-end device integration tests
│   └── run_flow_sync_integration_test.dart # Full workout lifecycle & offline sync test
├── lib/                        # Flutter Client Source Code (215 Dart files)
│   ├── core/                   # Shared foundational utilities & system logging
│   │   ├── logging/            # AppLogger with Crashlytics forwarding & log hygiene
│   │   └── utils/              # Team name validation, geohash cells, constants
│   ├── features/               # 13 Domain-driven feature modules
│   │   ├── auth/               # Firebase OAuth, login modals, Shield & Stride crest header
│   │   ├── coach/              # AI athletic coach briefing & Pace/Distance quantile predictions
│   │   ├── gallery/            # Debug Design System component gallery & token inspector
│   │   ├── gameplay/           # PolygonEnclosureEngine, Clipper2, and TerritoryService
│   │   ├── history/            # Workout archive, cloud run sync, splits, elevation & share cards
│   │   ├── home/               # Dashboard, quick-launch hero, daily quests, weekly recap
│   │   ├── map/                # Live OSM viewport, exploration fog grid, ghost runner, run HUD
│   │   ├── onboarding/         # Flagship 3-step athletic onboarding & permission primers
│   │   ├── profile/            # Profile hub, stats grid, trophy case, tiered milestones, settings
│   │   ├── routing/            # OSRM pedestrian loop planning & net-new area preview
│   │   ├── security/           # Anomaly detector service and kinematic auditor
│   │   ├── social/             # Activity feed, kudos, moderation, squad management, duels & crews
│   │   └── training/           # Guided multi-week 5K / 10K / fitness training plan sheets
│   ├── models/                 # 25 immutable Dart models & Hive TypeAdapters
│   ├── services/               # 39 System & domain services (GPS, ZUPT, SyncQueue, DailyQuests,
│   │                           # ExplorationGrid, GhostRunner, SavedLoops, IntervalWorkouts,
│   │                           # VoiceCoach, OfflineTiles, PrivacyZones, WebSocketService)
│   ├── ui/                     # Design system tokens, motion curves, BrandMark & AppIntroGate
│   │   ├── motion/             # Calibrated motion durations & reduced-motion accessibility
│   │   ├── theme/              # AppColors (Calm Moss & Neutral Obsidian), AppText, AppPalette
│   │   ├── widgets/            # BrandLogo crest, AppIntroGate, buttons, sheets & modals
│   │   └── ui.dart             # Unified barrel export for design system primitives
│   └── main.dart               # App bootstrap, Provider wiring & parallel async pre-warming
├── ml/                         # Machine Learning Anti-Cheat, Calorie & Progression Pipelines
│   ├── calories/               # Monotone-constrained LightGBM calorie surrogate & report
│   ├── data/                   # Microsoft GeoLife preparation, spoof generator & trace validator
│   ├── features/               # 22 GPS displacement kinematic feature extractors
│   ├── models/                 # LightGBM, 1D-CNN+GRU (PyTorch), Quantile Pace & ONNX export
│   └── reports/                # LOUO-CV benchmarks (311,383 windows), PR & calibration curves
├── scripts/                    # Automation, test runners & PostGIS backup/restore scripts
├── test/                       # Automated Flutter Unit, Widget & Compliance Suites (11 dirs)
│   ├── assets/                 # Asset compliance and tile licensing tests
│   ├── benchmarks/             # Performance baseline & frame-budget benchmarks
│   ├── features/               # Feature-specific widget & workout lifecycle tests
│   ├── gameplay/               # 120-min shield, loop enclosure, decay & grace tests
│   ├── gps/                    # ZUPT stationary drift, Kalman & gap segmentation tests
│   ├── integrity/              # Simulation isolation & environment flag tests
│   ├── motion/                 # <=600ms launch intro & 90ms tap motion budget tests
│   ├── services/               # Low-level service tests (Hive, SyncQueue, Calorie, DailyQuests)
│   ├── social/                 # Activity feed, kudos & moderation tests
│   ├── theme/                  # Zero-raw-color, token-budget & WCAG contrast audits
│   └── ui/                     # Font-size token enforcement, loading experience & avatar tests
└── test_fixtures/              # 17 Shared Golden Datasets (Dart & Go parity verification)
    ├── anomaly_vectors.json    # Synthetic spoof vectors (teleport, vehicle speed, jitter)
    ├── golden_*.json           # 15 reference loop trajectories & modality edge cases
    └── parity_200_windows.json # 200 kinematic test tracks verified across client & server
```

### Architectural Boundaries & Core Invariants

1. **Feature Encapsulation (`lib/features/`):** Each business domain contains its own screens, domain controllers, and scoped sub-widgets. Shared primitives reside in `lib/ui/widgets/` or `lib/services/`.
2. **Server Authority & Parity:** Game mechanics (dynamic loop closures, 120-minute defense shields, lazy decay, net-new area accounting, anti-cheat kinematics) are symmetrically implemented in Dart (`lib/features/gameplay`) and Go (`backend/internal/geo`, `backend/internal/store`), verified against all 17 golden datasets in `test_fixtures/`.
3. **Offline-First Resilience:** Network operations always enqueue into encrypted Hive storage (`unsynced_runs_v2`) before transmission. Local Clipper2 immediately computes an optimistic polygon preview so athletes never wait on cellular latency.
4. **Design Token Strictness:** Raw hex colors (`Color(0x...)`) and inline font sizes are prohibited in application code. Automated CI tests (`no_raw_colors_test.dart` and `token_enforcement_test.dart`) enforce design token compliance across every commit.
5. **Simulation Isolation:** Demo Mode simulation runs are isolated on device (`isSimulated: true`), flagged with a "Demo run" history badge, and barred from mutating backend database state or leaderboards.

---

<a id="level-2"></a><a id="-level-2-gameplay-mechanics--athlete-experience"></a>
## 🎮 Level 2: Gameplay Mechanics & Athlete Experience

### 1. Multi-Candidate Proximity & Lasso Closure

```
                       Start Point (A)
                             ▲
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            │          CLOSED LOOP            │
            │                                 │
            ▼                                 │
    Intersection (P_int) ◄────────────────────┘
            │
            ▼ Trailing Path (Athlete continues running)
```

1. **Self-Intersection Detection:** When current segment $\overline{P_{n-1}P_n}$ intersects an earlier segment $\overline{P_j P_{j+1}}$, the intersection point $\mathbf{P}_{\text{int}}$ is calculated via 2D cross-product line determinants:
   $$t = \frac{(x_1 - x_3)(y_3 - y_4) - (y_1 - y_3)(x_3 - x_4)}{(x_1 - x_2)(y_3 - y_4) - (y_1 - y_2)(x_3 - x_4)}$$
2. **Lasso Snapping & Tail Retention:** The closed loop is formed from $[\mathbf{P}_{\text{int}}, P_{j+1}, \dots, P_{n-1}, \mathbf{P}_{\text{int}}]$. Preceding breadcrumbs prior to $P_j$ are preserved as the trailing path, allowing athletes to close multiple loops in a single continuous run.
3. **Multi-Candidate Proximity & Dynamic Loop Closure:** If no direct segment self-intersection is detected, proximity scanning searches recorded vertices within an accuracy-scaled dynamic closure distance:
   $$R_{\text{eff}} = \text{clamp}\left(25.0\text{ m}, 50.0\text{ m}, R_{\text{base}} + (\text{Accuracy}_m - 10.0) \times 0.4\right)$$
   where base closure $R_{\text{base}} = 35.0\text{ m}$. Clean satellite fixes ($\le 5\text{ m}$) tighten closure to $\sim 33.0\text{ m}$, while degraded urban canyon drift ($15\text{--}25\text{ m}$) expands gracefully up to $41.0\text{ m}$ to prevent frustrating false dropouts. Implemented with strict symmetry across Dart `PolygonEnclosureEngine` and Go `geo.Engine` (see [docs/MECHANICS.md](docs/MECHANICS.md)).

---

### 2. Tri-Modality Athletic Engine

Different sports have fundamentally different spatial scales and kinematics. Territory Runner calibrates geometric thresholds and speed limits specifically for each modality:

| Parameter | 🚶 Walking | 🏃 Running | 🚴 Cycling |
| :--- | :--- | :--- | :--- |
| **Minimum Enclosed Area** | $100\text{ m}^2$ | $200\text{ m}^2$ | $1,000\text{ m}^2$ |
| **Minimum Loop Perimeter** | $40\text{ m}$ | $60\text{ m}$ | $150\text{ m}$ |
| **Instant Speed Ceiling** | $10.0\text{ km/h}$ | $25.0\text{ km/h}$ | $50.0\text{ km/h}$ |
| **Sustained Avg Speed** | $8.5\text{ km/h}$ | $22.0\text{ km/h}$ | $40.0\text{ km/h}$ |
| **Teleport / Outlier Filter** | $15.0\text{ km/h}$ | $35.0\text{ km/h}$ | $60.0\text{ km/h}$ |
| **Peak Acceleration Ceiling** | $2.5\text{ m/s}^2$ | $8.0\text{ m/s}^2$ | $12.0\text{ m/s}^2$ |
| **Minimum XP Capture Floor** | $25\text{ m}^2$ | $25\text{ m}^2$ | $25\text{ m}^2$ |

> [!TIP]
> **Modality Segregation:** Head-to-Head Duels strictly enforce activity type matching. A $15\text{ km}$ cycling workout will never progress a running duel challenge, eliminating cross-sport exploitation.

---

### 3. Dynamic Territory Strength, Lazy Decay & 120-Minute Defense Shield

Captured land is living territory that rewards regular runs and defense:

```
Captured / Defended ──► [ 120-Minute (2h) Defense Shield (ST_Difference Immunity) ]
                                   │
                           Shield Lapses (cooldown_until <= NOW())
                                   ▼
100% Strength ──[ -15% / day without run ]──► 30% Vulnerable ──► <50m² Collapse
     ▲                                                │
     └──────── Friendly Runner Visits ────────────────┘
```

- **120-Minute (2-Hour) Defense Shield:** Every captured or defended territory receives an authoritative 2-hour defense shield (`cooldown_until = NOW() + INTERVAL '120 minutes'`). During this window:
  - Rival loops cannot carve or overwrite shielded ground (`ST_Difference` in PostgreSQL and Clipper2 in Dart subtract protected land).
  - Friendly re-runs fortify the territory, resetting the shield to `+120 minutes` and strength to 100%.
  - The HUD map displays a solid shield indicator while protected.
- **Initial Health:** Newly claimed zones start at $100.0\%$ strength.
- **Lazy Decay on Read:** Decays at $-15.0\%$ per day without friendly visits, with a 72-hour grace period after reaching $0\%$ strength before returning to open commons (232 hours total):
  $$\text{Strength}(t) = \max\left(0, 100.0 - 15.0 \times \Delta t_{\text{days}}\right)$$
  *Evaluated lazily on read queries—eliminating wasteful background cron sweeps over millions of inactive database rows.*
- **Friendly Defense:** Running through your own territory resets `strength = 100.0` and updates `last_defended_at = NOW()`.
- **Rival Takeover Bonus:** Capturing a weakened rival territory ($<30\%$ strength) awards a $1.5\times$ XP bonus (when motion verification passes). Fragmented slivers under $50\text{ m}^2$ collapse automatically.

---

### 4. Explore Claim Planner (OSRM + Clipper2 Net-New Deduction)

Athletes can plan territory routes before leaving home:
- **Pedestrian Graph Routing:** Generates real pedestrian routes along runnable footpaths and sidewalks using the Open Source Routing Machine (OSRM).
- **Preset Targets:** Quick buttons for $2\text{k}, 5\text{k}, 10\text{k}, 25\text{k}\text{ m}^2$ loops or fine-grained distance sliders.
- **Optimistic Net-New Area Deduction:** Uses client-side Clipper2 difference operations to calculate *net-new* claimable area by subtracting your existing sovereign polygons before you take your first stride.

---

### 5. Unique Runner ID, Friend Requests Inbox, Duels & Crews

- **Unique Runner ID (`RUN-XXXXXX`):** Every athlete receives a deterministic/random shareable Runner ID (`RUN-XXXXXX`) on account creation and login ([`auth_screen.dart`](lib/features/auth/auth_screen.dart), migration [`000015_add_user_runner_code.up.sql`](backend/migrations/000015_add_user_runner_code.up.sql)). Athletes can copy and share their ID directly from the Profile header badge or Squad view.
- **Friend Search & Quick Add:** Search athletes by exact Runner ID (`RUN-XXXXXX`) or display name via `GET /v1/users/search` inside the Add Friend sheet ([`social_add_friend_dialog.dart`](lib/features/social/widgets/social_add_friend_dialog.dart)), with 1-tap clipboard paste.
- **Friend Requests Inbox & Non-Blocking Social Hub:** Dedicated Friend Requests Inbox modal ([`friend_requests_inbox_sheet.dart`](lib/features/social/widgets/friend_requests_inbox_sheet.dart)) accessible via Inbox and `+` controls across Home (`HomeHeader`), Profile (`ProfilePage`), and Social Hub (`SocialHubHeader`). Features live incoming badge counts, incoming Accept/Decline actions, outgoing cancel controls, and instant Hive cache hydration with non-blocking offline/sync status banners ([`social_hub_sheet.dart`](lib/features/social/widgets/social_hub_sheet.dart)).
- **Runner Crews & Seasonal Challenges:** Form or join cooperative running crews and set group territory/distance targets (`/v1/crews/*`, `/v1/seasons/current`, migration [`000014_add_seasons_and_crews.up.sql`](backend/migrations/000014_add_seasons_and_crews.up.sql)).
- **24-Hour Head-to-Head Duels:** Issue head-to-head challenges with configurable metrics (Area Conquered or Kinematic Distance) and XP stakes ($0 - 1000\text{ XP}$).
- **Database Unique Pair Index:**
  ```sql
  CREATE UNIQUE INDEX uq_duels_active_pair 
  ON duels (LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id))
  WHERE status IN ('pending', 'active');
  ```
  Guarantees that no two athletes can have more than one concurrent active or pending challenge.
- **Anti-Abuse Limits:** Max 5 active duels, max 10 pending invitations, self-duels rejected at database level.
- **Squad Friends:** Mutual friends render on live tactical radar with dynamic distance and heading indicators.

---

### 6. Physiological Calorie & Energy Expenditure Engine

Territory Runner replaces naive flat distance multipliers ($kcal = d \cdot M \cdot 1.036$) with a peer-reviewed biomechanical energy pipeline:

1. **Multi-Factor Bioenergetics:** Energy calculation incorporates body mass, speed, horizontal grade/incline, and stride cadence. Uphill climbs increase energy consumption, heavier athletes burn proportionally more, and running faster expends more energy per minute.
2. **Peer-Reviewed Physiology:**
   - **ACSM Metabolic Equations (2021):** Validated oxygen consumption ($VO_2$) for walking ($3\text{--}6\text{ km/h}$) and running ($\ge 8\text{ km/h}$), converted at $4.86\text{ kcal / L } O_2$.
   - **Minetti et al. (2002) Polynomial:** 5th-order empirical model for extreme gradients ($|G| > 6\%$, up to $\pm 20\%$) with eccentric muscle braking limits preventing negative energy burn.
   - **Mifflin-St Jeor (1990) RMR:** Basal resting metabolic rate per minute, incorporating an unbiased neutral sex midpoint ($s = -78\text{ kcal/day}$) when gender is unstated.
   - **Martin et al. (1998) Cycling Power Balance:** Direct physical modeling of rolling resistance, gravitational potential work, and aerodynamic drag with $22\%$ human metabolic efficiency.
3. **Honest Estimation & Uncertainty Range:** Calories are presented honestly as estimates with a likely quantile range (e.g., `~410 kcal (est.) • likely between 370 and 450 kcal`), grounded in the "How we estimate this" explanation modal.
4. **Monotone-Constrained LightGBM Surrogate:** On-device ML decision trees enforce non-decreasing monotonicity (`[+1, +1, +1, 0, +1]`) so predicted energy burn rate mathematically cannot drop as body mass, speed, or grade increases. Inferences run in pure Dart in $< 15\ \mu\text{s}$ with SHA-256 asset integrity validation.
5. **Zero-Knowledge Privacy (India DPDP Act & GDPR):** Body details (weight, height, age, gender) and computed calories are strictly confined to local device storage (`SharedPreferences` & local sync queue). They are **never** uploaded to servers, analytics, or leaderboards.
6. **Smartwatch Calibration:** Athletes can optionally calibrate against their wrist wearable (Apple Watch, Garmin) across 3+ runs, producing a median multiplier strictly bounded to $[0.8, 1.2]$.

---

### 7. Weekly Competitive League Engine

- **Canonical UTC Reset:** All league divisions reset every **Monday at 00:00:00 UTC**:
  $$\text{ResetTimestamp} = \text{date\_trunc}('week', \text{NOW}() \text{ AT TIME ZONE } 'UTC') + 7\text{ days}$$
  *Immune to client timezone tampering or phone clock manipulation.*
- **Dynamic Percentile Division Tiers:**
  - 💎 **Diamond:** Top 5% of active athletes ($\lceil 0.05 \times N \rceil$)
  - 🥇 **Gold:** Next 20% of active athletes ($\lceil 0.25 \times N \rceil$)
  - 🥈 **Silver:** Next 35% of active athletes ($\lceil 0.60 \times N \rceil$)
  - 🥉 **Bronze:** Bottom 40% of active athletes (remaining)

---

### 8. Google Gemini AI Athletic Coach

- **Post-Run Debrief:** Calls Google Gemini 2.5 Flash (`POST /v1/runs/{id}/coach`) to generate physiological workout debriefs analyzing cardiovascular effort, pace degradation, elevation profile, and tactical route suggestions.
- **Zero Key Leakage:** Client never touches Google Gemini API keys; requests proxy through the Go backend.
- **Heuristic Offline Fallback:** If the Gemini API is unreachable or unconfigured, the system automatically uses an on-device sports science rule engine analyzing split pace variance and heart rate zones.

---

### 9. Server-Authoritative Faction & Team Validation (`PUT /v1/me/faction`)

Team names appear publicly on real-time presence radar, leaderboards, and push alerts. The backend serves as the single source of truth for validation, normalization, and abuse defense:
- **Canonical Content Rules:** Trims input, collapses repeated internal spaces, enforces 3 to 24 Unicode characters, and restricts characters strictly to letters, digits, spaces, hyphens, and underscores.
- **Zero-Tolerance Exploit Filtering:** Rejects control characters, newlines, HTML/script tags, URLs, and invisible/homoglyph spaces (`\u200B`, `\u00A0`).
- **Reserved Word Deny-List:** Blocks impersonation of administrative identities (`admin`, `support`, `moderator`, `official`, `staff`, `system`, `null`, `undefined`).
- **NFKC Normalization & Canonical Comparison:** Normalizes with Unicode NFKC and case-folding so `"Team A"` and `"team  a"` resolve identically, eliminating squatting and confusion.
- **Abuse Rate-Limiting:** Enforces a rolling ceiling of **3 faction changes per 24 hours per athlete**, logging all modifications at `INFO` level without sensitive PII leakage.
- **Legacy Resiliency:** Existing database records with legacy invalid formats are mapped safely to empty (no faction) upon read, preventing crashes or deserialization errors.
- **Mirrored Client Feedback:** The Flutter profile dialog mirrors identical validation rules for immediate real-time feedback with matching error diagnostics.

---

### 10. Explicit Simulation & Demo Mode Isolation

To guarantee game integrity and prevent spoofing or accidental mock data from contaminating competitive leaderboards:
- **Zero Silent Fallback:** Simulation mode is never triggered implicitly. If GPS permission is denied or hardware location is disabled, the app displays calm, actionable modals ("Open Settings", "Location is off", "Waiting for GPS") rather than silently falling back to simulated coordinates.
- **Explicit Demo Mode Only:** Simulated runs are only possible through the deliberate user-enabled Demo Mode switch.
- **Clear HUD Visibility:** While Demo Mode is active, an unambiguous zinc/moss "SIMULATED (DEMO)" badge is rendered on the HUD.
- **Sync Queue Quarantine:** Simulated workouts carry `isSimulated = true`. They are strictly quarantined locally, barred from the encrypted FIFO sync queue, never sent to `POST /v1/runs`, never award XP, and never alter server territory ownership.
- **History Demarcation:** In the athlete's local workout history, simulated sessions carry a calm "Demo run" badge and "Demo run (not submitted)" verification status.

---

<a id="level-3"></a><a id="-level-3-mobile-client-engineering--offline-resiliency-flutter"></a>
## 📱 Level 3: Mobile Client Engineering & Offline Resiliency (Flutter)

### 1. Screen-Lock Background Tracking Hardening

Running apps frequently stop recording when users lock their screens or switch apps due to OS battery management (Android Doze, iOS Background Suspension). Territory Runner implements full background hardening:

```
┌────────────────────────────────────────────────────────┐
│               BACKGROUND TRACKING LIFECYCLE            │
├────────────────────────────────────────────────────────┤
│  1. Android Foreground Service (FOREGROUND_SERVICE_LOCATION) │
│  2. Sticky Ongoing Notification with Live Distance & Pace │
│  3. wakelock_plus CPU Keep-Alive (Prevents CPU Sleep) │
│  4. iOS UIBackgroundModes: location, allowsBackgroundUpdates │
└────────────────────────────────────────────────────────┘
```

- **Android:** Runs under `FOREGROUND_SERVICE_LOCATION` with a persistent sticky notification displaying real-time metrics. Acquires a CPU WakeLock (`wakelock_plus`) on workout start.
- **iOS:** Configures `UIBackgroundModes: location`, `allowsBackgroundLocationUpdates: true`, and `activityType: Fitness`.

---

### 2. Encrypted Crash Recovery Safety Box (`RunRecoveryService`)

To protect athlete workouts against sudden process death, OS low-memory termination, or battery exhaustion:
- Every valid GPS coordinate and telemetry metric received by [location_service.dart](lib/services/location_service.dart) is throttled and flushed to disk into Hive storage box `active_run_recovery` ([run_recovery_service.dart](lib/services/run_recovery_service.dart)).
- **Hardware-Backed AES-256 Encryption:** Storage is encrypted using `HiveAesCipher` with a 256-bit cryptographically secure key managed by [hive_encryption_service.dart](lib/services/hive_encryption_service.dart) via Android KeyStore / iOS Keychain (`flutter_secure_storage`).
- Upon relaunch, the app detects unfinalized sessions and prompts the athlete:  
  *"Unfinished run detected (3.42 km, 18 min). Resume tracking or finalize capture?"*
- Resuming restores all track points, duration timers, and live preview area without data loss.

---

### 3. Encrypted Offline-First FIFO Sync Queue (`SyncQueueService`)

```
Run Completed ──► Local Clipper2 Optimistic Preview ──► Enqueued in Encrypted Hive FIFO
                                                                │
   Reconciliation Toast ◄── Server PostGIS Commit ◄── Network Restored
```

1. **Instant Optimistic Preview:** Local Dart Clipper2 computes and renders the captured territory polygon immediately, with zero network wait.
2. **Encrypted Persistent FIFO Queue:** The run is serialized into encrypted Hive box `unsynced_runs_v2` ([sync_queue.dart](lib/services/sync_queue.dart)) with an idempotent UUID, step counts, motion windows, and point kinematics (geodesic velocity & compass bearing).
3. **Automatic & Resilient Flushing:** `SyncQueueService` flushes pending runs immediately on completion, on app foregrounding/startup recovery, and via HTTP health checks with exponential backoff (`2s`, `4s`, `8s`, ... `max 60s`).
4. **4xx Permanent Circuit Breaker:** Permanent client errors (`422 ANOMALY_REJECTED`, `400 INVALID_LOOP`) halt retries immediately and archive the run into encrypted box `rejected_runs_v1` to prevent battery and bandwidth drain.
5. **Reconciliation Toast & Archive Sync:** If the server-authoritative PostGIS area differs from the optimistic preview (e.g. rival claimed overlapping land first), a notification alerts the runner, while [run_history_screen.dart](lib/features/history/run_history_screen.dart) lets athletes pull and reconcile remote runs from `GET /v1/runs`.

---

### 4. AMOLED Endurance Battery Saver Mode

```
Standard Mode (60 FPS Map Tiles, Shaders)  ──►  Battery Saver Mode (Pure #000000 Canvas)
Drain: ~18-24% per hour                         Drain: ~5-7% per hour (60-80% Power Reduction)
```

- **OLED Subpixel Physics:** On AMOLED displays, pure black pixels (`#000000`) draw 0 mW of electrical current.
- **Map & Animation Suspension:** [battery_saver_service.dart](lib/services/battery_saver_service.dart) suspends 60 FPS map tile rendering, shimmer animations, and camera matrix updates.
- **Dynamic GPS Duty-Cycling:** Relaxes GPS polling from 1 Hz ($1000\text{ ms}, 2\text{ m}$ filter) to 0.33 Hz ($3000\text{ ms}, 8\text{ m}$ filter).
- **Double-Tap Wake:** A responsive double-tap gesture wakes the tactical map HUD instantaneously without interrupting background location tracking.

---

### 5. GPS Quality, Zero-Interpolation Policy & ZUPT Stationary Filter

- **Signal Dropout Policy:** [gps_quality_service.dart](lib/services/gps_quality_service.dart) tracks the elapsed time since the last valid GPS fix.
- **15-Second Gap Rule:** Signal dropouts exceeding 15 seconds segment the track buffer rather than interpolating across unknown terrain. Dead-reckoning through urban canyons or tunnels risks hallucinating paths through impassable buildings or private property; resetting ensures every captured polygon represents physically verified athlete movement.
- **Zero-Velocity Update (ZUPT) & Kalman Filter ([gps_distance_filter.dart](lib/services/gps_distance_filter.dart)):**
  - When the athlete is stationary (`smoothedSpeedKmh < 1.2 km/h` and `speed <= 0.4 m/s`) or auto-paused, distance accumulation freezes (`deltaMeters = 0.0`).
  - Completely eliminates stationary GPS multi-path jitter (reducing stationary drift from a $+728\text{ m}$ baseline down to $0.0\text{ m}$).
  - Raw coordinates pass through a 2D Cartesian Kalman filter ($R = \max(4.0, \sigma_{\text{acc}}^2)$) to eliminate lateral zig-zagging on straight tracks.
- **Jump Suppression:** Reacquired fixes with speed exceeding the activity ceiling are suppressed to prevent teleportation cutting.

---

### 6. Instant GPS Acquisition, Asynchronous Pre-Warming & Viewport Unblocking

In outdoor fitness tracking, cold-start satellite acquisition typically delays tracking by 15–45 seconds while waiting for low horizontal dilution ($\le 30\text{ m}$). Territory Runner eliminates launch delays through a multi-stage acquisition architecture:
- **Unblocked Map Viewport:** Removed full-screen loading spinners from [map_viewport.dart](lib/features/map/widgets/map_viewport.dart). The map mounts immediately at the runner's last known sector, pre-rendering tiles and territories in parallel.
- **Asynchronous GNSS Pre-warming (`warmUpLocation`):** On screen mount (`MapScreen._initMapState()`), [location_service.dart](lib/services/location_service.dart) instantly queries the hardware OS `getLastKnownPosition()` cache (<50ms response) to lock camera follow and pre-warms the GNSS radio before the user presses "Start".
- **Two-Tier Accuracy Gate:**
  - *Initial Fix Gate:* Allows coarse fixes up to $\le 50\text{ m}$ when `lastPos == null` to immediately establish the runner marker and map center.
  - *Active Tracking Gate:* Strictly enforces high-precision $\le 30\text{ m}$ horizontal dilution for path vertex recording and polygon closure calculations.
- **Visual vs. Recording Separation:** In [map_run_controller.dart](lib/features/map/controllers/map_run_controller.dart), coarse fixes (> 30m) update the live position marker and camera follow so athletes are never left blind, but distance and territory accumulation wait for high satellite accuracy ($\le 30\text{ m}$).

---

### 7. Brand Identity & Athletic High-Contrast Design System (Calm Moss + Neutral Obsidian)

Engineered specifically for outdoor glanceability at arm's length, direct sunlight contrast, OLED battery conservation, flagship launch polish, and thumb-driven ergonomics with zero glowing neon visual fatigue.

- **Shield & Stride Brand Emblem (`assets/icons/` & [brand_logo.dart](lib/ui/widgets/brand_logo.dart)):** Custom-crafted high-resolution Crest pairing a Calm Moss (`#A3C586`) faceted shield polygon on Neutral Obsidian (`#0D0F11`) with an Alpine Snow (`#F8FAFC`) loop stride path and GPS beacon apex — rendered natively in vector Flutter (`TerritoryBrandMark`) across onboarding, auth screens, and the `< 600 ms` animated `AppIntroGate` spline reveal ([app_intro_animation.dart](lib/ui/widgets/app_intro_animation.dart)), plus full Android Adaptive / iOS / Web icon & splash bundles.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                ATHLETIC COLOR TOKENS                                   │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────┬──────────────────┤
│   bgDeep    │   surface   │   accent    │    rival    │    gold     │   textPrimary    │
│   #0D0F11   │   #16191D   │   #A3C586   │   #C25946   │   #D4A373   │     #F8FAFC      │
│  Obsidian   │Card Surface │  Calm Moss  │ Terracotta  │ Trophy Ochre│ Alpine Snow 16.9 │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┴──────────────────┘
```

- **Athletic Palette Tokens ([app_colors.dart](lib/ui/theme/app_colors.dart)):**
  - `bgDeep` (`#0D0F11`): Neutral Obsidian Canvas Base.
  - `surface` (`#16191D`), `surface2` (`#1F2328`), & `bgElevated` (`#262B32`): Layered Neutral Obsidian card and drawer surfaces.
  - `accent` / `primary` / `mine` (`#A3C586`): Calm Moss Green for player territory polygons, primary actions, and verified progress.
  - `rival` (`#C25946`): Muted Terracotta for rival contested territory and shield alerts.
  - `gold` (`#D4A373`): Warm Ochre demoted strictly to podium #1 awards and streak milestones.
  - `warning` (`#F59E0B`): Warm Amber for auto-pause notices and satellite quality degradation.
  - `error` (`#DC2626`): Safety Alert Red for SOS beacons and diagnostic errors.
  - `border` (`#30363D`) & `borderSubtle` (`#252A31`): Clean structural divider borders.
  - `textPrimary` (`#F8FAFC`): Alpine Snow (16.9:1 AAA contrast against `surface`).
  - `textSecondary` (`#9CA9BE`): Cool Slate (7.4:1 AAA contrast) for telemetry metrics.
  - `textMuted` (`#8692A0`): Muted Slate (5.8:1 AA/AAA contrast) for secondary captions.
  - `territoryMineFill` (`#2EA3C586`): 18% Calm Moss fill with `2.0dp` `#A3C586` outline.
  - `territoryRivalFill` (`#2EC25946`): 18% Muted Terracotta fill with `2.0dp` `#C25946` outline.
- **Calibrated Motion Budgets ([motion.dart](lib/ui/motion/motion.dart)):**
  - `fast` (90ms): Instant touch feedback on tap down / scale interactions.
  - `standard` (220ms): Smooth content transitions and card elevations.
  - `sheet` (240ms): Fluid bottom-sheet entrance and dismiss curves (`Curves.easeOutCubic`).
  - `AppIntroGate` (`590ms`): Crisp spline loop reveal honoring the strict `<= 600ms` launch motion ceiling.
  - `accessibleDuration`: Automatically reduces motion durations to `Duration.zero` when the user enables platform reduced-motion preferences.
- **Tabular Figures & Glanceable Typography:** In [run_hud_metrics_card.dart](lib/features/map/widgets/run_hud_metrics_card.dart), distance, moving time, and split pace use bold weights and tabular figures (`FontFeature.tabularFigures()`), eliminating horizontal digit jitter while running. All text styles are strictly governed by `AppText.*` tokens enforced by `token_enforcement_test.dart`.
- **Safety Thumb-Zone Hold-To-Finish:** Accidental-tap protected 1.4-second press-and-hold button [hold_to_finish_button.dart](lib/features/map/widgets/hold_to_finish_button.dart) with tactile haptic tick milestones at 33% and 66% and heavy burst on completion, anchored directly in the bottom thumb zone.
- **Zero Raw Colors Policy:** Enforced automatically by `no_raw_colors_test.dart` and `token_budget_test.dart` (`<= 32` palette constants).

---

### 8. High-Visibility OpenStreetMap Cartography & Offline Caching

Standard mobile map tiles often suffer from inverted dark matrix filters that blur pedestrian paths or washed-out low-contrast graphics. Territory Runner implements high-clarity open-source cartography:
- **Native Clarity:** Uninverted, high-contrast map rendering, restoring full native sharpness and street legibility.
- **OpenStreetMap Standard Basemap (Default):** Free, open, unwatermarked basemap tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`) requiring zero proprietary API keys or external lock-in.
- **Optional CARTO & Mapbox Support:** Supports CARTO raster retina basemaps (Voyager, Positron, Dark Matter) or Mapbox styles via `--dart-define=TILE_API_KEY=...` or `TILE_URL_TEMPLATE=...`.
- **Automatic Cache Invalidation:** `TileCacheService` automatically purges disk cache if the configured tile template changes, preventing stale or watermarked tiles from persisting.
- **OSM Usage Policy Compliance:** Configures discrete offline disk caching ([constants.dart](lib/core/utils/constants.dart), 7-day TTL), user-agent identification (`com.territoryrunner.app`), and prefetch locks.

---

### 9. Athletic Auto-Pause Engine & Start-Line Pause Suppression

In outdoor running tracking, naive auto-pause triggers frequently stall runs during the first few seconds of a session or flap erratically during pedestrian stops. Territory Runner implements an athletic auto-pause engine with hysteresis and start-line suppression:
- **Calibrated Speed Thresholds:** The auto-pause ceiling triggers when athlete speed drops below **$< 2.5\text{ km/h}$** for 3 consecutive seconds ([auto_pause_engine.dart](lib/services/auto_pause_engine.dart)). Hysteresis requires speed to reach or exceed **$\ge 3.0\text{ km/h}$** to resume, preventing jitter while jogging or walking.
- **Start-Line Initial Movement Gate (`_hasInitialMovement`):** When athletes tap "Start Run", they are stationary ($0.0\text{ km/h}$) while putting the phone in an armband or waiting at a crosswalk. `AutoPauseEngine` remains unarmed until the runner crosses $2.5\text{ km/h}$ or accumulates active GPS coordinate displacement ($\ge 2.0\text{ m}$), eliminating premature auto-pauses at the start of a run.
- **10-Second Startup Grace Window:** In [map_run_controller.dart](lib/features/map/controllers/map_run_controller.dart), `startupGraceSeconds = 10` suppresses all pause transitions during the initial 10 seconds of a session.
- **Immediate Displacement Fast-Resume:** If auto-paused at a red light, detecting $\ge 3.0\text{ m}$ of coordinate displacement immediately calls `forceResume()` and shifts GPS back to active tracking mode ($1\text{ s}$ interval, $2\text{ m}$ filter).
- **GNSS Doppler Fallback Calculation:** If hardware reports $0.0\text{ km/h}$ or uncalibrated velocity despite physical movement, speed is computed dynamically from consecutive GPS fix displacement ($\Delta d / \Delta t$).

---

### 10. Modular Architecture & Provider Separation

To maintain clear boundaries and full unit testability, screens are decomposed into state controllers (`ChangeNotifier` via `Provider`), domain services, and focused presentational widgets:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    MODULAR COMPONENT DECOMPOSITION                         │
├───────────────────────┬────────────────────────────────────────────────────┤
│ Root Screen           │ Extracted Controllers & Sub-Components             │
├───────────────────────┼────────────────────────────────────────────────────┤
│ MapScreen             │ MapRunController (ChangeNotifier), MapTopBar,      │
│                       │ MapHudPanel, MapFloatingControls, MapRivalLayer,   │
│                       │ MapViewport, MapRunFinisher, MapDemoRunner         │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RunHud                │ RunHudClosureBar, RunHudMetricsCard,               │
│                       │ RunHudExpandedDrawer, RunHudControlsBar            │
├───────────────────────┼────────────────────────────────────────────────────┤
│ SummarySheet          │ SummaryVictoryHeader, SummaryStatsGrid,            │
│                       │ SummaryRouteReplay, SummaryCoachCard, LapSplits    │
├───────────────────────┼────────────────────────────────────────────────────┤
│ SocialHubSheet        │ SocialHubHeader, SocialFeedTab, SocialSquadTab,    │
│                       │ SocialDuelsTab, FriendRequestsInboxSheet, Moderation│
├───────────────────────┼────────────────────────────────────────────────────┤
│ Profile & Daily Habit │ ProfileScreen, ChallengesShelf, AchievementsSheet, │
│                       │ FactionLeaderboard, WardrobeSheet, TrainingPlans   │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RunShareCardModal     │ RunShareCardRenderer, RunShareCardPreview,         │
│                       │ RunShareCardPainters, RunShareCardActions          │
└───────────────────────┴────────────────────────────────────────────────────┘
```

- **Declarative `MapRunController`:** State management decoupled into [map_run_controller.dart](lib/features/map/controllers/map_run_controller.dart) implementing `ChangeNotifier`, exposed via `Provider`.
- **Constructor Injection:** Services and controllers support constructor/override injection in [main.dart](lib/main.dart) (`MultiProvider`) and across `test/`, allowing tests to run deterministically offline without live Firebase or PostGIS dependencies.

---

### 11. Daily Habit Mechanics, Exploration Fog & Guided Running

Beyond spatial claims, Territory Runner integrates complete daily athletic retention systems:
- **Daily Quests & Streaks (`DailyQuestService`):** Daily rotating objectives (distance, territory defense, new block exploration) paired with calendar-day streak calculation (`computeActiveStreakDays`) in [daily_quest_service.dart](lib/services/daily_quest_service.dart) and [daily_quests_home_card.dart](lib/features/home/widgets/daily_quests_home_card.dart).
- **100m Exploration Fog Grid (`ExplorationService`):** Tracks every $100\text{ m} \times 100\text{ m}$ grid cell visited across runs ([exploration_service.dart](lib/services/exploration_service.dart)), rendering subtle explored blocks on [map_viewport.dart](lib/features/map/widgets/map_viewport.dart) and awarding "New Blocks Explored" milestones on completion.
- **Ghost Runner Racing & Saved Loops:** Race against recorded personal-best ghosts ([ghost_runner_service.dart](lib/services/ghost_runner_service.dart)) or replay favorite neighborhood paths via [saved_loop_service.dart](lib/services/saved_loop_service.dart).
- **Training Plans, Structured Intervals & Voice Coach Cues:** Multi-week structured plans ([training_plan_service.dart](lib/services/training_plan_service.dart)), harmonic work/rest interval cues, and hands-free spoken pace/closure guidance ([countdown_audio_service.dart](lib/services/countdown_audio_service.dart)) engineered to mix quietly over background music.
- **Tiered Achievements & Run Share Cards:** Multi-tier progression milestones ([tiered_achievement_service.dart](lib/services/tiered_achievement_service.dart), [achievements_sheet.dart](lib/features/profile/widgets/achievements_sheet.dart)) and exportable vector route cards ([run_share_card_modal.dart](lib/features/history/widgets/run_share_card_modal.dart)).

---

### 12. Biomechanical Runner Avatar & Wardrobe (`RunnerAvatarPainter`)

- **Articulated Stride Kinematics:** [`RunnerAvatarPainter`](lib/ui/widgets/runner_avatar_painter.dart) renders a sculpted multi-joint athlete using tapered limb envelopes (`torso`, `deltoid/bicep/forearm`, `quad/calf`), asymmetrical stride phase, posterior knee fold during swing recovery, opposite arm counter-swing, depth shading between near/far limbs, dynamic ground contact shadow, and scrolling track dashes.
- **Customizable Progression Wardrobe:** [`WardrobeSheet`](lib/features/profile/widgets/wardrobe_sheet.dart) lets athletes preview live animations (`Dynamic Stride Cycle`) and equip progression-unlocked headwear, tops, bottoms, and running shoes (with sneaker midsole + upper + sole highlights).

---

### 13. Motion Sensor Cadence & Stillness Verification (`MotionSensorService`)

```
📱 Accelerometer + Gyroscope ──► Step Detector ──► Cadence (SPM) + Energy
                                                         │
   Motorized Transit Rejection ◄── Speed > 6 km/h & Cadence < 20 SPM
```

- **Sensor Fusion:** [motion_sensor_service.dart](lib/services/motion_sensor_service.dart) continuously samples device sensors at 50 Hz to extract cadence (steps per minute) and mechanical motion energy.
- **Tier 1 Cadence Stillness Rule:** Cross-validates GPS displacement velocity against physical cadence. If GPS speed exceeds 6.0 km/h while device cadence remains stationary (< 20 SPM) for > 10 seconds, the segment is rejected as passive motorized vehicular transit (e.g., driving a car or riding a bus).

---

<a id="level-4"></a><a id="-level-4-backend-engineering--distributed-spatial-systems-go--postgis"></a>
## 🖥️ Level 4: Backend Engineering & Distributed Spatial Systems (Go + PostGIS)

### 1. Server-Authoritative Spatial Concurrency (`pg_advisory_xact_lock`)

When multiple runners compete in the same contested city block, concurrent spatial mutations (`ST_Union`, `ST_Difference`) cause database race conditions, deadlocks, and corrupted geometries. 

Territory Runner serializes spatial transactions using PostgreSQL transaction-scoped advisory locks:

```sql
-- 1. Acquire transaction-scoped advisory lock
-- Released automatically by PostgreSQL on COMMIT or ROLLBACK
SELECT pg_advisory_xact_lock(hashtext('territory_mutation_lock'));

-- 2. Clean and validate submitted loop (handles bowties & antennas)
WITH valid_loop AS (
    SELECT ST_Multi(ST_CollectionExtract(
        ST_MakeValid(ST_SetSRID(ST_GeomFromText($1), 4326)), 3
    )) AS geom
),
-- 3. Cut overlapping vulnerable rival territories (strictly preserves shielded land where cooldown_until > NOW())
rival_cuts AS (
    UPDATE territories t
    SET geom = ST_Difference(t.geom, vl.geom),
        area_sqm = ST_Area(ST_Difference(t.geom, vl.geom)::geography),
        updated_at = NOW()
    FROM valid_loop vl
    WHERE t.owner_id != $2 
      AND ST_Intersects(t.geom, vl.geom)
      AND (t.cooldown_until IS NULL OR t.cooldown_until <= NOW())
    RETURNING t.id, t.owner_id, t.area_sqm
),
-- 4. Subtract shielded rival geometries from attacker's loop
claimable_loop AS (
    SELECT COALESCE(
        ST_Difference(
            vl.geom,
            (SELECT ST_Union(t.geom) FROM territories t WHERE t.owner_id != $2 AND ST_Intersects(t.geom, vl.geom) AND t.cooldown_until > NOW())
        ),
        vl.geom
    ) AS geom
    FROM valid_loop vl
),
-- 5. Union into runner's territory geometry and apply 120-minute (2h) defense shield
INSERT INTO territories (id, owner_id, geom, area_sqm, strength, cooldown_until, updated_at)
VALUES ($3, $2, (SELECT geom FROM claimable_loop), (SELECT ST_Area(geom::geography) FROM claimable_loop), 100.0, NOW() + INTERVAL '120 minutes', NOW())
ON CONFLICT (owner_id) DO UPDATE
SET geom = ST_Union(territories.geom, EXCLUDED.geom),
    area_sqm = ST_Area(ST_Union(territories.geom, EXCLUDED.geom)::geography),
    cooldown_until = NOW() + INTERVAL '120 minutes',
    updated_at = NOW();
```

#### Why `pg_advisory_xact_lock` over OCC or Redis Redlock?
- **vs. Optimistic Concurrency Control (OCC):** OCC aborts transactions on version conflict. In high-density running zones, OCC leads to cascading rollbacks and wasted CPU overhead re-executing expensive PostGIS difference calculations.
- **vs. Redis Redlock:** Redis requires dual-system state management. Network pauses, GC halts, or clock jumps can break mutual exclusion unless monotonic fencing tokens are used. `pg_advisory_xact_lock` runs directly inside the PostgreSQL kernel and automatically cleans up on `COMMIT` or `ROLLBACK`.

---

### 2. PostGIS Spatial Math & Algorithmic Parity

#### Geodesic Shoelace Area Calculation
Planar shoelace formulas fail on spherical earth coordinates. Territory Runner projects spherical coordinates into an equidistant azimuthal tangent plane centered at the polygon's centroid:

$$x_i = R \cdot (\lambda_i - \lambda_0) \cdot \cos\left(\frac{\phi_i + \phi_0}{2}\right), \quad y_i = R \cdot (\phi_i - \phi_0)$$

$$\text{Area} = \frac{1}{2} \left| \sum_{i=0}^{n-1} (x_i y_{i+1} - x_{i+1} y_i) \right|$$

- **Accuracy Guarantee:** Tested against 7 shared golden fixtures; Dart Clipper2 and Go PostGIS agree within $<0.5\%$ error margin across small city blocks ($5,000\text{ m}^2$) and large park perimeters ($100,000\text{ m}^2$).
- **Topological Sanitization:** Bowtie self-intersections and dangling collinear antennas are cleaned using `ST_MakeValid` followed by `ST_CollectionExtract(..., 3)` to discard degenerate points and linestrings.

---

### 3. Real-Time WebSocket Hub with Singleflight

Located in [backend/internal/ws/hub.go](backend/internal/ws/hub.go):
- **Decoupled Snapshotting:** Takes a quick read-lock snapshot of connected clients and releases `hub.mu.RUnlock()` immediately before evaluating spatial or friendship filtering, eliminating network framing deadlocks.
- **Singleflight Miss Coalescing:** Under multi-runner GPS presence broadcasts, concurrent friendship lookups coalesce through `hub.sfGroup.Do(senderID, ...)`. Exactly one database query fires while all waiting callers share the result.
- **Atomic Cache Invalidation:** When a friend request is accepted or removed, the HTTP handler notifies `hub.InvalidateFriends(userA, userB)` to evict cached relationships with zero staleness.

---

### 4. FCM HTTP v1 Push Infrastructure

Located in [backend/internal/notify/fcm.go](backend/internal/notify/fcm.go):
- **Pure Go OAuth2 RS256 Client:** Implemented using Go standard library (`crypto/rsa`, `crypto/sha256`) without heavy Google Cloud SDK dependencies.
- **Asynchronous Non-Blocking Fan-Out:** Push dispatches execute in detached goroutines with a 5-second timeout. Run submissions return `HTTP 201 Created` in $<50\text{ ms}$ without waiting on external Google push network round-trips.
- **Graceful Dev Fallback:** Operates as a safe no-op when service account credentials are omitted in local development.

---

### 5. REST & WebSocket API Specification

#### Core HTTP & WebSocket Endpoints (`backend/internal/api/router.go`)

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `GET` | `/healthz` | Liveness probe | Public |
| `GET` | `/readyz` | Database readiness probe | Public |
| `GET` | `/metrics` | Prometheus-style runtime metrics | Public / `METRICS_TOKEN` |
| `GET` | `/v1/ws` | Real-time WebSocket connection | Bearer JWT / Dev |
| `GET` | `/v1/me` | Retrieve athlete profile, Runner ID (`runner_code`), XP, level, and stats | Bearer JWT |
| `PUT` | `/v1/me` | Update athlete profile fields (`display_name`, `runner_code`, avatar) | Bearer JWT |
| `DELETE`| `/v1/me` | Account deletion; cascade purges territories, runs, and privacy zones | Bearer JWT |
| `GET` | `/v1/users/search` | Search athletes by `RUN-XXXXXX` Runner ID or display name | Bearer JWT |
| `GET` | `/v1/me/settings` | Fetch athlete server-synced preferences | Bearer JWT |
| `PUT` | `/v1/me/settings` | Save athlete server-synced preferences | Bearer JWT |
| `PUT` | `/v1/me/faction` | Update athlete faction allegiance (Unicode NFKC validated) | Bearer JWT |
| `GET` | `/v1/me/privacy-zones`| List athlete privacy exclusion zones | Bearer JWT |
| `PUT` | `/v1/me/privacy-zones`| Save or replace privacy exclusion zones | Bearer JWT |
| `POST` | `/v1/runs` | Submit completed run with coordinates & idempotency key (rate-limited) | Bearer JWT |
| `GET` | `/v1/runs` | Fetch athlete run history | Bearer JWT |
| `POST` | `/v1/runs/{id}/coach` | Generate post-run AI coaching analysis (rate-limited) | Bearer JWT |
| `GET` | `/v1/territories` | Fetch territories in bounding box (`minLat`, `maxLat`, `minLng`, `maxLng`) | Bearer JWT |
| `GET` | `/v1/leaderboard` | Top athlete leaderboard ranking | Bearer JWT |
| `GET` | `/v1/league/current` | Current weekly league division standings & percentile | Bearer JWT |
| `GET` | `/v1/factions/standings`| Global faction surface dominance | Bearer JWT |
| `POST` | `/v1/device-token` | Register FCM push notification token | Bearer JWT |
| `GET` | `/v1/friends` | List mutual squad friends | Bearer JWT |
| `GET` | `/v1/friends/requests` | List incoming and outgoing friend requests | Bearer JWT |
| `POST` | `/v1/friends/request` | Send friend request by Runner ID or athlete callsign | Bearer JWT |
| `PUT` | `/v1/friends/request/{id}`| Accept or decline friend request | Bearer JWT |
| `DELETE`| `/v1/friends/{friendID}` | Remove friend from squad | Bearer JWT |
| `GET` | `/v1/duels` | List active, pending, and past head-to-head duels | Bearer JWT |
| `POST` | `/v1/duels` | Issue 24-hour head-to-head duel challenge | Bearer JWT |
| `PUT` | `/v1/duels/{id}/accept` | Accept a pending duel challenge | Bearer JWT |
| `PUT` | `/v1/duels/{id}/decline`| Decline a pending duel challenge | Bearer JWT |
| `GET` | `/v1/feed` | Fetch mutual-friend activity feed | Bearer JWT |
| `POST` | `/v1/feed/{id}/kudos` | Send kudos reaction on a shared run | Bearer JWT |
| `DELETE`| `/v1/feed/{id}/kudos` | Remove kudos reaction from a shared run | Bearer JWT |
| `POST` | `/v1/feed/{id}/hide` | Hide a specific run post from the user's feed | Bearer JWT |
| `POST` | `/v1/moderation/block` | Block a user and dissolve any friendship | Bearer JWT |
| `DELETE`| `/v1/moderation/block/{id}`| Unblock a previously blocked user | Bearer JWT |
| `POST` | `/v1/moderation/report` | Report inappropriate content or abuse | Bearer JWT |
| `GET` | `/v1/seasons/current` | Fetch active season details & progress | Bearer JWT |
| `GET` | `/v1/crews/my` | Retrieve current athlete's runner crew | Bearer JWT |
| `POST` | `/v1/crews` | Create a new runner crew | Bearer JWT |
| `POST` | `/v1/crews/join` | Join an existing runner crew | Bearer JWT |
| `POST` | `/v1/crews/goals` | Create or update a crew goal | Bearer JWT |

#### WebSocket Protocol Frames (`/v1/ws` — `backend/internal/ws/messages.go`)

```json
// Client -> Server: Spatial Viewport Subscription & Live Position Update
{
  "type": "viewport_subscribe",
  "cells": ["gcpvj0", "gcpvj1", "gcpvj4"]
}

{
  "type": "presence_update",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "speed": 3.4,
  "heading": 85.0
}

// Server -> Client: Privacy-Preserving Rival Radar Broadcast (speed & heading omitted)
{
  "type": "runner_presence",
  "user_id": "rival_uuid",
  "username": "ShadowStrider",
  "faction": "Alpine Runners",
  "latitude": 37.7752,
  "longitude": -122.4198,
  "updated_at": "2026-11-26T16:40:00Z"
}

// Server -> Client: Territory Under Attack Alert
{
  "type": "territory_under_attack",
  "event": "territory_carved",
  "attacker_id": "rival_uuid",
  "attacker_name": "ShadowStrider",
  "area_claimed_sqm": 3500.0,
  "victim_user_id": "self_uuid",
  "message": "ShadowStrider carved 3,500 m² of your territory",
  "timestamp": "2026-11-26T16:40:02Z"
}
```

---

<a id="level-5"></a><a id="-level-5-cryptography-privacy--zero-trust-security"></a>
## 🔒 Level 5: Cryptography, Privacy & Zero-Trust Security

### 1. Firebase Auth RS256 JWT Verification

Located in [backend/internal/auth/auth.go](backend/internal/auth/auth.go):
1. Client sends `Authorization: Bearer <token>`.
2. Server extracts token header and reads the `kid` (Key ID).
3. Server fetches Google's public x509 certificates from Google's secure token endpoint.
4. Certificates cache in-memory respecting the HTTP `Cache-Control` max-age (typically 6 hours), avoiding outbound latency per request.
5. Server parses the RSA public key and verifies the RS256 signature using `rsa.VerifyPKCS1v15` with `crypto.SHA256`.
6. Enforces strict claims: `iss == "https://securetoken.google.com/" + projectID`, `aud == projectID`, `exp > now`, and non-empty `sub`.

---

### 2. Dual-Layer Privacy Zones

```
[ Private Zone (Radius 50m - 2000m) ] ──► Coordinates Redacted from DB & GPX
                 │
                 └──► WebSocket Hub suppresses presence on rival radar
```

- **Threat Mitigation:** Prevents doxxing residential homes, military bases, or workplaces from public fitness heatmaps.
- **Client-Side Redaction:** Athletes configure circular privacy zones ($50\text{ m} - 2,000\text{ m}$) centered around sensitive locations. Coordinates inside active zones are excised from public GPX 1.1 and GeoJSON exports.
- **Server Geodesic Suppression:** When an athlete is running within their active privacy zone, the WebSocket presence dispatcher automatically suppresses broadcast packets to rivals.

---

### 3. Social Anti-Abuse Integrity

- **Symmetric Unique Index:** `ON duels (LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id))` prevents race-condition duplicate challenges.
- **Database Self-Duel Guard:** Database check constraint `chk_duels_no_self` blocks users from dueling themselves.
- **Parametric Bounds:** XP stakes bounded $[0, 1000]$, area targets $[500, 500000]\text{ m}^2$, and distance $[0.5, 50.0]\text{ km}$.
- **Automatic 24-Hour Expiration:** Duels exceeding 24 hours resolve automatically upon read evaluation.

---

### 4. Encrypted Local Storage (Hive AES-256 + flutter_secure_storage)

All sensitive on-device offline caches are encrypted at rest using `HiveAesCipher` with 256-bit keys:
- **Key Derivation & Storage:** [hive_encryption_service.dart](lib/services/hive_encryption_service.dart) generates a 32-byte cryptographic key via `Hive.generateSecureKey()` and secures it in the hardware-backed keystore (Android KeyStore with AES/GCM or iOS Keychain) via `flutter_secure_storage`.
- **Encrypted Boxes:**
  - `active_run_recovery`: Active GPS track buffers and telemetry to prevent data loss on crash.
  - `unsynced_runs_v2`: Offline-first pending sync queue containing athlete tracks and claimed areas.
  - `rejected_runs_v1`: Permanent dead-letter archive for server-rejected runs (`422 ANOMALY_REJECTED`).
- **At-Rest Protection:** Protects against physical device theft, root/jailbreak filesystem inspection, and unauthorized exfiltration of sensitive location histories.

---

### 5. STRIDE Threat Model & Defense-in-Depth

The complete security posture is documented in the [STRIDE Threat Model](docs/THREAT_MODEL.md):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        STRIDE THREAT MITIGATIONS                       │
├─────────────────────┬──────────────────────────────────────────────────┤
│ STRIDE Category     │ Territory Runner Architectural Countermeasure    │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Spoofing            │ Firebase RS256 JWT verifier + is_mocked detector │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Tampering           │ Server-side PostGIS authority + Hive AES-256     │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Repudiation         │ Idempotent run UUIDs + unalterable run log audit │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Information Disc.   │ Dual-layer privacy zones (client + server mask)  │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Denial of Service   │ Token-bucket rate limiting + advisory xact locks │
├─────────────────────┼──────────────────────────────────────────────────┤
│ Elevation of Priv.  │ Role-based access control + unforgeable claims   │
└─────────────────────┴──────────────────────────────────────────────────┘
```

---

<a id="level-6"></a><a id="-level-6-machine-learning--anti-cheat-pipeline"></a>
## 🤖 Level 6: Machine Learning & Anti-Cheat Pipeline

The Territory Runner anti-cheat engine uses a defense-in-depth architecture combining deterministic physical constraints with server-side motion telemetry auditing:

```
Incoming GPS & Motion Fixes ──► Server Velocity Recalculation (Client Speed Untrusted)
                                                │
                                                ▼
                                Tier 1: Deterministic Physical Gate (Primary Defense)
                                • Speed Ceilings (25 km/h run, 10 km/h walk, 50 km/h cycle)
                                • Accel Ceilings (8.0 m/s²), Teleport (50m/s), Mock GPS
                                • Motion Window Sanity & Sustained Vehicle Stillness Heuristic
                                                │
                 ┌──────────────────────────────┼──────────────────────────────┐
                 ▼                              ▼                              ▼
      [verified_human]                [unverified_motion]                 [rejected]
   Full territory claimed &       Territory claimed; active duel       HTTP 422 Rejected
  competitive duels advanced      & 1.5x weak bonus restricted        Gross physics breach
```

---

### 1. Tier 1: Primary Deterministic Physical Gate & Motion Auditing

Evaluates physical kinematics server-side with zero reliance on client-reported speed:
- **Server Velocity Recalculation:** Client-reported `speed` telemetry is explicitly discarded; speed is recalculated from geodesic haversine distance and timestamps.
- **Hardware Mock Location Flag:** Inspects Android's `is_mocked` provider flag (scores $99.0$).
- **Instant Speed & Teleport Ceilings:** Exceeding sport ceilings ($25\text{ km/h}$ run, $10\text{ km/h}$ walk, $50\text{ km/h}$ cycle) or jumping $> 50\text{ m}$ in $\le 1\text{ s}$ triggers instant rejection.
- **Biomechanical Acceleration Limit:** Usain Bolt's peak acceleration is $\approx 4.5\text{ m/s}^2$. Any acceleration $\Delta v / \Delta t > 8.0\text{ m/s}^2$ ($> 12.0\text{ m/s}^2$ for cycling) across consecutive fixes physically indicates motorized transport or synthetic injection.
- **Identical-Step GPS Replay Detection:** When $\ge 50\%$ of adjacent GPS vertices share identical coordinates during movement, the trace is rejected.
- **Server-Side Motion Window Auditing (`SanityCheckMotionWindows`):** Audits client-supplied motion windows for duration inflation ($> 15\%$), sensor bounds ($[0, 300]\text{ SPM}$), and bot repeat patterns.
- **Three Verification States:**
  - `verified_human`: Physical GPS kinematics pass AND motion windows pass server sanity checks. Full territory and duel progression awarded.
  - `unverified_motion`: Physical GPS kinematics pass, but motion windows are missing or unverified. Territory is claimed, but duel challenge advancement and the $1.5\times$ weak-territory capture bonus are withheld.
  - `rejected`: Severe physical violations result in HTTP 422 rejection.

---

### 2. Tier 2: LightGBM Kinematic Anomaly Ensemble (Experimental)

> [!NOTE]
> **Status Disclosure**: Tier 2 ML is currently **experimental and disabled by default** (`EnableMLTier2: false`) pending collection of $\ge 30$ validated team app traces. Evaluated below across **311,383 real-world windows from 61 distinct users** in the **Microsoft GeoLife GNSS Dataset** using strictly **22 GPS kinematic features** (zero synthetic cadence leakage; see [`ml/reports/eval.md`](ml/reports/eval.md)):

- **Features (22 GPS Displacement Kinematics):** Speed quantiles, acceleration jerk variance, path sinuosity, heading entropy, accuracy stats, `dt` regularity, and stop ratio.
- **Validation Protocol:** 5-fold Leave-One-User-Out Cross-Validation (`GroupKFold` by `user_id`, zero user data leakage) with 1,000 bootstrap iterations.

| Model Architecture | PR-AUC (95% CI) | Recall @ 1% FPR (95% CI) | Recall @ 5% FPR (95% CI) | ECE | Latency |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.9129 `[0.9082, 0.9170]` | 39.17% `[37.18%, 40.47%]` | 53.61% `[52.48%, 54.67%]` | 0.1285 | 26.2 µs |
| **Logistic Regression** | 0.9377 `[0.9339, 0.9412]` | 47.18% `[42.63%, 52.13%]` | 79.37% `[78.30%, 80.38%]` | 0.0493 | 24.4 µs |
| **LightGBM** | **0.9456** `[0.9421, 0.9488]` | **55.36%** `[51.21%, 59.90%]` | **81.20%** `[80.32%, 81.99%]` | **0.0352** | 8.9 µs |
| **1D-CNN + GRU** | 0.9361 `[0.9324, 0.9395]` | 52.85% `[48.31%, 57.14%]` | 79.14% `[78.08%, 80.08%]` | 0.0378 | **4.3 µs** |

*Key Findings & Per-Modality Behavior (`@ 1% FPR` from [`ml/reports/eval.md`](ml/reports/eval.md)):*
- **Zero False Flags on Running & Low FPR on Walking**: At the 1% target FPR operating point, empirical FPR is **0.00%** on running (`run`), **0.64%** on cycling (`bike`), and **1.21%** on walking (`walk`) for LightGBM.
- **High-Speed Rail vs. Urban Bus Blindspot**: LightGBM catches **92.80%** of trains, **65.46%** of cars, **60.80%** of subways, and **60.78%** of taxis, whereas slow stop-and-go urban buses (**31.04%** recall) overlap with cycling kinematics when evaluated purely on GPS without accelerometer cadence.
- **Fail-Safe Fallback**: If model files fail cryptographic SHA-256 checksum verification, the system logs a warning and falls back to Tier 1 physical rules without crashing.

> For full statistical proofs, confusion matrices, and adversarial stress tests (`ml/data/generate_spoofs.py`), see [`ml/reports/eval.md`](ml/reports/eval.md) and **[AIML Technical Dossier](docs/AIML_EVALUATION.md)**.

---

### 3. Quantile Athletic Progression & Calorie Surrogate Models

- **Calorie Surrogate ([`ml/calories/report.md`](ml/calories/report.md)):** Monotone-constrained LightGBM `[P10, P50, P90]` quantile surrogate achieving **0.764 kcal/min MAE** (vs. **3.518** flat-factor legacy baseline — a 78.3% MAE reduction) and **83.35%** empirical `[P10, P90]` coverage (`model_version: 1.0.0`).
- **Pace & Distance Quantile Regressor (`assets/models/pace_distance_meta.json`):** Predicts personalized $[p_{10}, p_{50}, p_{90}]$ goals across 16 temporal/rolling features with pinball loss optimization on sequential user history ($\mathcal{L}_q(y, \hat{y}) = \max(q(y - \hat{y}), (1 - q)(\hat{y} - y))$), achieving **0.917 km MAE** and **75.3%** `[P10, P90]` coverage on distance predictions (cold-start threshold: 5 prior runs).

---

### 4. Real-Trace Cadence Validation & Safe Rollout

- **Collection Hygiene Validator (`import_app_traces.py`):** Audits imported mobile traces against strict data integrity requirements across multiple users, diverse activities (walking, running, cycling, motorized transit), and phone placements (pocket, hand, bag).
- **Leave-One-User-Out Cross-Validation (LOUO-CV):** Evaluates real cadence and kinematic sensor models strictly across held-out real users to guarantee zero identity leakage.
- **Safe Rollout Guardrail (`ENABLE_CADENCE_MODEL`):** Model inference is gated by the `ENABLE_CADENCE_MODEL` environment variable (defaults to `OFF`).
- **Cryptographic SHA-256 Checksum Verification:** Model assets are verified with SHA-256 integrity checks on startup; any mismatch immediately falls back to Tier 1 deterministic physical rules.
- **Unverified Motion State:** Runs logged without validated motion telemetry preserve the `unverified_motion` status—territory area is awarded, but duel challenge progression and the $1.5\times$ weak-territory capture bonus remain restricted.

---

<a id="level-7"></a><a id="-level-7-master-level-testing-verification--production-ops"></a>
## 🏆 Level 7: Master Level (Testing, Verification & Production Ops)

### 1. Test Verification Matrix

Territory Runner enforces strict automated testing across all client and backend layers:

```
┌────────────────────────────────────────────────────────┐
│                 TEST VERIFICATION SUITE                │
├─────────────────────────┬──────────────┬───────────────┤
│ Domain                  │ Scope        │ Status        │
├─────────────────────────┼──────────────┼───────────────┤
│ Flutter Client (test/)  │ 743 tests    │ ALL PASS      │
│ Go Backend (backend/)   │ 11 packages  │ ALL PASS      │
│ PostGIS Integration     │ store suite  │ CI VERIFIED   │
│ Integration Test Flow   │ E2E Run Sync │ ALL PASS      │
│ Shared Golden Parity    │ 17 fixtures  │ <0.5% diff    │
│ Static Code Analysis    │ 0 issues     │ 100% CLEAN    │
│ Dart Formatting         │ 325 files    │ 100% CLEAN    │
│ Go Quality & Security   │ gofmt/vet/vuln│ 100% CLEAN   │
└─────────────────────────┴──────────────┴───────────────┘
```

#### Running the Verification Suites

```bash
# 1. Verify Dart Formatting & Strict Static Analysis (CI Gate)
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings

# 2. Run All Flutter Unit and Widget Tests (743 tests)
flutter test --timeout 120s

# 3. Run Core Verification Suites (GPS, Mechanics, Motion, Theme, Integrity)
flutter test test/benchmarks/start_run_baseline_test.dart test/gps/ test/motion/ test/theme/ test/integrity/ test/gameplay/ test/smoke_tappables_test.dart

# 4. Run End-to-End Offline Sync Integration Test
flutter test integration_test/run_flow_sync_integration_test.dart

# 5. Run Design System & Accessibility Audits
flutter test test/theme/no_raw_colors_test.dart
flutter test test/theme/wcag_contrast_test.dart
flutter test test/theme/accessibility_test.dart
flutter test test/u6_polish_and_proof_test.dart
flutter test test/design_system_test.dart

# 6. Run Go Backend Quality Checks & Unit Tests (11 packages)
cd backend
gofmt -l .
go vet ./...
go test -v -race ./...

# 7. Run PostGIS Integration Tests (requires running PostgreSQL + PostGIS)
TEST_DATABASE_URL="postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable" \
  go test -v -race -tags=integration ./internal/store/...
```

---

### 2. Production Deployment Architecture

```
Internet ──► Cloudflare / Reverse Proxy (SSL Termination)
                     │
                     ▼
             Go Chi API (:8080)
             (Stateless Container on Render / Railway / Self-Hosted Docker)
                     │
                     ├─► Direct TCP (Port 5432) ──► PostgreSQL 16 + PostGIS 3.4
                     ├─► RS256 JWT Assertion ──► Google FCM HTTP v1
                     └─► HTTP / TLS ──► Google Gemini 2.5 Flash
```

> [!WARNING]
> **Database Connection Pooling Caveat:**  
> When connecting to hosted PostgreSQL (e.g. Supabase, Neon), connect via **Session Mode** or **Direct Connection (Port 5432)**, NOT Transaction-Mode poolers (Port 6543). Transaction-mode poolers break `pg_advisory_xact_lock` and invalidate binary prepared query execution plans in `pgx/v5`.  
> Recommended pool configuration: `pgxpool.Config{MaxConns: 20, MinConns: 2}`.

See **[Production Deployment Specification](docs/DEPLOYMENT.md)** for Docker multi-stage builds (`backend/Dockerfile`), Render/Railway deployment steps, and production Docker Compose configurations (`backend/docker-compose.prod.yml`), and **[Local Server & Spare-Laptop Recipe](docs/LOCAL_SERVER.md)** for LAN/hotspot field testing.

---

### 3. Master Viva Examiner Defense Cheatsheet

| Tough Examiner Question | Defensive Architectural Rationale |
| :--- | :--- |
| **Why not Optimistic Concurrency Control (OCC)?** | In physical conquest, multiple athletes contest the same city park. OCC version conflicts cause cascading rollbacks and high retry latency executing expensive PostGIS differences. `pg_advisory_xact_lock` serializes spatial mutations with zero rollbacks. |
| **Why not Redis Redlock?** | Redis introduces split-brain risks if the database transaction fails while the lock succeeds. Network pauses and GC halts violate mutual exclusion without monotonic fencing tokens. PostgreSQL advisory locks run inside the database kernel and release automatically on COMMIT/ROLLBACK. |
| **Why planar Shoelace on client vs PostGIS on server?** | Vincenty/Karney ellipsoidal trigonometry on mobile UI threads causes 60 FPS frame drops. Shoelace computes in $O(N)$ with $<0.2\%$ curvature error for $<5\text{ km}^2$ runs. Client is purely an optimistic preview; PostGIS `ST_Area(geom::geography)` is the sole authority. |
| **Why reject pure Figure-8 loops?** | In EvenOdd fill rules, opposing loops cancel each other out or create topological ambiguity regarding sovereign intent. Lasso loops (trail + single loop) are accepted; pure figure-8 loops are rejected with `INVALID_LOOP`. |
| **Why lazy territory decay on read instead of cron sweeps?** | Decaying strength lazily on read (`strength = max(0, 100 - 15 * dt)`) eliminates wasteful scheduled cron sweeps over millions of inactive geometric rows. Active defending runners reset strength on write, guaranteeing $O(1)$ query evaluation and zero I/O amplification. |
| **How does Singleflight prevent WebSocket deadlocks?** | Decouples connection snapshotting from database I/O by releasing the mutex before querying friendships. `singleflight.Group` coalesces concurrent cache misses per sender into a single DB query, eliminating cache stampedes. |
| **Why FCM HTTP v1 instead of legacy server keys?** | Legacy FCM server keys are deprecated by Google and represent permanent credentials. FCM HTTP v1 requires short-lived (60 min) OAuth2 tokens signed with RS256 assertions using service account keys. |
| **Why zero-interpolation on GPS signal dropouts?** | Signal dropouts $>15\text{s}$ segment the active buffer. Dead-reckoning across urban canyons risks hallucinating paths through impassable buildings or private property; resetting ensures every polygon represents physically verified movement. |
| **Why auto-pause at $< 2.5\text{ km/h}$ with hysteresis instead of instant pausing?** | GPS multi-path jitter and runner arm swing while walking/waiting at curbs cause instant speed fluctuations. Hysteresis ($< 2.5\text{ km/h}$ ceiling for 3s to pause, $\ge 3.0\text{ km/h}$ floor to resume) eliminates flapping. The initial movement gate (`_hasInitialMovement`) and 10s startup grace window prevent premature pausing at the start line. |
| **Why OpenStreetMap standard tiles by default?** | Standard OpenStreetMap tiles are open, unwatermarked, highly legible, and completely free of proprietary API keys or sudden policy enforcement locks. When an API key is configured, CARTO Voyager retina basemaps or Mapbox styles can be activated seamlessly. |
| **Why server-authoritative team name validation with Unicode NFKC?** | Prevents homoglyph spoofing, zero-width space squatting (`\u200B`), and administrative impersonation. Normalizing with NFKC and enforcing a 3/day modification rate limit protects social radar feeds without leaking PII. |

> For the complete 335-line comprehensive defense covering all questions, see **[Viva Examiner Defense Dossier](docs/VIVA.md)**.

---

<a id="troubleshooting"></a><a id="-troubleshooting--faq"></a>
## ❓ Troubleshooting & FAQ

#### Q1: GPS tracking drops points when the phone screen is turned off.
**A**: Ensure location permissions are set to "Allow all the time". Territory Runner runs an Android foreground service with a persistent sticky notification (`FOREGROUND_SERVICE_LOCATION`) and holds a CPU wake lock (`wakelock_plus`) to prevent OS battery management from sleeping the GPS chip.

#### Q2: The Flutter client cannot connect to `http://localhost:8080` on an Android Emulator.
**A**: Android emulators route `localhost` to the emulator loopback, not the host machine. Run:
```bash
adb reverse tcp:8080 tcp:8080
```
Or set `--dart-define=API_BASE_URL=http://10.0.2.2:8080` when launching Flutter.

#### Q3: Why does the Go server report `database connection refused`?
**A**: Ensure PostgreSQL with PostGIS is running (`docker compose up -d`). If developing without PostgreSQL, start the server with `ENV=development` and omit `DATABASE_URL`; it will fall back to the hermetic in-memory store.

#### Q4: How do I configure Google Gemini API for post-run coaching?
**A**: Set `GEMINI_API_KEY=AIzaSy...` in your backend `.env` file. If omitted, the server automatically uses an on-device sports physiology heuristic rule engine.

#### Q5: Can I build Territory Runner for Windows or macOS desktop?
**A**: Yes! Run `flutter run -d windows` or `flutter run -d macos`. Desktop builds include mock GPS telemetry injectors and interactive sliders for rapid UI and layout debugging.

---

<a id="contributing"></a><a id="-contributing--license"></a>
## 🤝 Contributing & License

Contributions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/UX_CHECKLIST.md](docs/UX_CHECKLIST.md) before opening a pull request.

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>🏃 Territory Runner • Server-Authoritative Real-Time GPS Territory Capture • Flutter + Go PostGIS</sub>
</div>
