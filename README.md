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
*Enclose arbitrary closed-loop GPS territory polygons on a calm, high-contrast tactical map. Defend land from rivals, climb weekly competitive league tiers, and receive tactical AI coaching.*

<br>

[![CI](https://github.com/Ayush-00-hui/Territory-Runner-Game/actions/workflows/ci.yml/badge.svg)](https://github.com/Ayush-00-hui/Territory-Runner-Game/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/Ayush-00-hui/Territory-Runner-Game/branch/main/graph/badge.svg)](https://codecov.io/gh/Ayush-00-hui/Territory-Runner-Game)
[![Tests Passing](https://img.shields.io/badge/Flutter_Test_Suites-58%20Passing-4FD1A5.svg?style=flat-square&logo=flutter&logoColor=white)](test/)
[![Go Tests](https://img.shields.io/badge/Go_Test_Suites-17%20Passing-00ADD8.svg?style=flat-square&logo=go&logoColor=white)](backend/)
[![Encrypted Storage](https://img.shields.io/badge/Storage-Hive_AES--256-blueviolet.svg?style=flat-square&logo=keybase&logoColor=white)](lib/services/hive_encryption_service.dart)
[![Threat Model](https://img.shields.io/badge/Security-STRIDE_Threat_Model-critical.svg?style=flat-square&logo=shield&logoColor=white)](docs/THREAT_MODEL.md)
[![AIML Anti-Cheat](https://img.shields.io/badge/AIML_AntiCheat-LightGBM_Ensemble-9C27B0.svg?style=flat-square&logo=scikitlearn&logoColor=white)](docs/AIML_EVALUATION.md)
[![Static Analysis](https://img.shields.io/badge/Flutter_Analyze-0_Issues-4C8DFF.svg?style=flat-square&logo=dart&logoColor=white)](lib/)
[![Code Formatting](https://img.shields.io/badge/Format-Clean-green.svg?style=flat-square)](lib/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B.svg?style=flat-square&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2.svg?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Go](https://img.shields.io/badge/Go-1.24+-00ADD8.svg?style=flat-square&logo=go&logoColor=white)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_PostGIS_3.4-4169E1.svg?style=flat-square&logo=postgresql&logoColor=white)](https://postgis.net/)
[![Docker](https://img.shields.io/badge/Docker-Compose_Ready-2496ED.svg?style=flat-square&logo=docker&logoColor=white)](docker-compose.yml)
[![Auth](https://img.shields.io/badge/Auth-Firebase_RS256_JWT-FFA000.svg?style=flat-square&logo=firebase&logoColor=white)](backend/internal/auth/)
[![Push Alerts](https://img.shields.io/badge/Push_Alerts-FCM_HTTP_v1-FFCA28.svg?style=flat-square&logo=firebase&logoColor=black)](backend/internal/notify/)
[![AI Coach](https://img.shields.io/badge/AI_Coach-Google_Gemini_2.5_Flash-4285F4.svg?style=flat-square&logo=google&logoColor=white)](backend/internal/coach/)

<br>

[Level 0: Concept](#-level-0-the-high-altitude-concept--paradigm) • [Level 1: Quickstart](#-level-1-fast-track-onboarding-zero-to-running-in-5-minutes) • [Level 2: Gameplay](#-level-2-gameplay-mechanics--athlete-experience) • [Level 3: Mobile](#-level-3-mobile-client-engineering--offline-resiliency-flutter) • [Level 4: Backend](#-level-4-backend-engineering--distributed-spatial-systems-go--postgis) • [Level 5: Security](#-level-5-cryptography-privacy--zero-trust-security) • [Level 6: AI/ML](#-level-6-machine-learning--anti-cheat-pipeline) • [Level 7: Master](#-level-7-master-level-testing-verification--production-ops)

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
│ 🎮 Level 2: Gameplay Mechanics & Athlete Experience                                    │
│    └─ Organic loop enclosure | Tri-modality calibration | Dynamic decay | AI Coach     │
│ 📱 Level 3: Mobile Client Engineering & Offline Resiliency (Flutter)                   │
│    └─ Foreground background GPS | Crash recovery box | FIFO sync queue | AMOLED saver │
│ 🖥️ Level 4: Backend Engineering & Distributed Spatial Systems (Go + PostGIS)           │
│    └─ pg_advisory_xact_lock | PostGIS pipeline | Clipper2 parity | WebSocket Hub      │
│ 🔒 Level 5: Cryptography, Privacy & Zero-Trust Security                                │
│    └─ Firebase RS256 JWT verifier | Dual-layer privacy zones | Anti-abuse duels        │
│ 🤖 Level 6: Machine Learning & Anti-Cheat Pipeline (LightGBM)                          │
│    └─ Tier 1 deterministic gate | Tier 2 25-feature kinematic ensemble | Quantiles    │
│ 🏆 Level 7: Master Level (Testing, Audits, Verification & Production Ops)             │
│    └─ 52 Flutter + 11 Go test suites | WCAG AAA dark HUD | Viva defense cheatsheet     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

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
| **Enclosure Mechanism** | None | Fixed geographic portal linking | **Real-time proximity & lasso self-intersection snap** |
| **Concurrency Control** | Independent tracks, no conflict | Optimistic locks with retry aborts | **Transaction-scoped PostGIS advisory lock (`pg_advisory_xact_lock`)** |
| **Offline Capability** | Records track, no gameplay | Fails without active cell signal | **Dual-engine: local Clipper2 optimistic preview + Hive FIFO queue** |
| **Screen-Lock GPS** | Standard OS background tracking | Often throttled by OS battery management | **Hardened foreground service with sticky notification & CPU wakelock** |
| **Anti-Cheat Validation** | Post-hoc manual flag reviews | Basic speed thresholds | **Tier 1 Kinematic Gate + Tier 2 LightGBM 25-feature ML ensemble** |
| **Privacy Safeguards** | Client-only map blur | None | **Dual-layer: client redaction + server-side geodesic suppression in WebSockets** |
| **Rival Alerts** | None | Delayed batch emails | **Real-time WebSocket alerts + FCM HTTP v1 background push** |
| **Visual Aesthetic** | Cluttered social feed | Neon, gamified arcade glare | **Calm, high-contrast Ink + Pacer Blue (`#090B0F`, `#4C8DFF`)** |

---

### System Architecture Overview

```mermaid
graph TD
    subgraph Client ["Flutter Mobile Client (Offline-First & Background Hardened)"]
        UI[Tactical Map HUD & Design System]
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
        TileServer[ArcGIS World Dark Basemap]
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

## ⚡ Level 1: Fast-Track Onboarding (Zero to Running in 5 Minutes)

### Prerequisites

| Tool | Version Requirement | Purpose |
| :--- | :--- | :--- |
| **Go** | 1.22+ (tested on 1.24) | Server compilation, spatial math, WebSocket hub |
| **Flutter SDK** | 3.13+ (Dart 3.0+) | Cross-platform mobile client (Android / iOS / Desktop) |
| **Docker & Compose** | v2.20+ | Multi-stage backend build & PostGIS spatial database |
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

# 3. Verify Health
curl http://localhost:8080/health
# Response: {"status":"ok","timestamp":"2026-10-26T00:00:00Z"}
```

The server listens on `http://localhost:8080` with PostGIS on port `5432`. Built-in SQL migrations run automatically on startup.

---

### Path B: Hermetic In-Memory Dev Store (Zero Docker Required)

If you don't have Docker or PostgreSQL installed, you can launch the backend instantly using its hermetic in-memory spatial engine:

```bash
cd backend

# On Linux/macOS:
export ENV=development
export AUTH_MODE=dev
go run cmd/server/main.go

# On Windows PowerShell:
$env:ENV="development"
$env:AUTH_MODE="dev"
go run cmd/server/main.go
```

The server detects missing database credentials and initializes an in-memory spatial store with full REST, WebSocket, anti-cheat, and AI coaching capabilities.

---

### Path C: Launching the Flutter Mobile Client

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Verify static analysis and tests
flutter analyze
flutter test

# 3. Launch on Android Emulator or Device
flutter run -d emulator-5554

# 4. Launch on Windows Desktop (for instant UI/layout testing)
flutter run -d windows
```

> [!IMPORTANT]
> **Android Emulator Networking (`adb reverse`):**  
> Android emulators route `localhost` to the emulator loopback, not your host computer. Run this command so the mobile emulator can reach your local Go server:
> ```bash
> adb reverse tcp:8080 tcp:8080
> ```
> Alternatively, point the client to `http://10.0.2.2:8080` using `--dart-define=API_BASE_URL=http://10.0.2.2:8080`.

---

### Environment Variables Configuration

Copy `backend/.env.example` to `backend/.env` to configure optional integrations:

```env
# Server
PORT=8080
ENV=development
AUTH_MODE=dev                 # 'dev' bypasses Firebase token verification for local testing

# Database (Leave empty to use hermetic in-memory store)
DATABASE_URL=postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable

# Firebase RS256 Authentication (Production)
FIREBASE_PROJECT_ID=territory-runner

# FCM HTTP v1 Push Notifications (Optional)
FCM_SERVICE_ACCOUNT_JSON=backend/service-account.json

# Google Gemini AI Athletic Coach (Optional - falls back to sports science rule heuristics)
GEMINI_API_KEY=AIzaSy...
```

---

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
3. **Multi-Candidate Proximity:** If no direct intersection is detected, proximity scanning searches vertices within $35\text{ m}$ to select the optimal non-self-intersecting closure point.

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

### 3. Dynamic Territory Strength & Lazy Decay

Captured land is living real estate that requires ongoing physical maintenance:

```
100% Strength ──[ -15% / day without run ]──► 30% Vulnerable ──► <50m² Collapse
     ▲                                                │
     └──────── Friendly Athlete Runs Through ─────────┘
```

- **Initial Health:** Newly conquered sectors start at $100.0\%$ strength.
- **Lazy Decay on Read:** Decays at $-15.0\%$ per day without friendly traversal:
  $$\text{Strength}(t) = \max\left(0, 100.0 - 15.0 \times \Delta t_{\text{days}}\right)$$
  *Evaluated lazily on read queries—eliminating wasteful background cron sweeps over millions of inactive database rows.*
- **Friendly Defense:** Running through your own territory resets `strength = 100.0` and updates `last_defended_at = NOW()`.
- **Rival Conquest Bonus:** Conquering a weakened rival territory ($<30\%$ strength) awards a $1.5\times$ XP bonus. Fragmented slivers under $50\text{ m}^2$ collapse automatically.

---

### 4. Explore Claim Planner (OSRM + Clipper2 Net-New Deduction)

Athletes can plan territory routes before leaving home:
- **Pedestrian Graph Routing:** Generates real pedestrian routes along runnable footpaths and sidewalks using the Open Source Routing Machine (OSRM).
- **Preset Targets:** Quick buttons for $2\text{k}, 5\text{k}, 10\text{k}, 25\text{k}\text{ m}^2$ loops or fine-grained distance sliders.
- **Optimistic Net-New Area Deduction:** Uses client-side Clipper2 difference operations to calculate *net-new* claimable area by subtracting your existing sovereign polygons before you take your first stride.

---

### 5. Head-to-Head Duels & Social Squads

- **24-Hour Duels:** Issue head-to-head challenges with configurable metrics (Area Conquered or Kinematic Distance) and XP stakes ($0 - 1000\text{ XP}$).
- **Database Unique Pair Index:**
  ```sql
  CREATE UNIQUE INDEX uq_duels_active_pair 
  ON duels (LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id))
  WHERE status IN ('pending', 'active');
  ```
  Guarantees that no two athletes can have more than one concurrent active or pending challenge.
- **Anti-Abuse Limits:** Max 5 active duels, max 10 pending invitations, self-duels rejected at database level.
- **Squad Friends:** Send friend requests by athlete callsign. Mutual friends render on live tactical radar with dynamic distance and heading indicators.

---

### 6. Weekly Competitive League Engine

- **Canonical UTC Reset:** All league divisions reset every **Monday at 00:00:00 UTC**:
  $$\text{ResetTimestamp} = \text{date\_trunc}('week', \text{NOW}() \text{ AT TIME ZONE } 'UTC') + 7\text{ days}$$
  *Immune to client timezone tampering or phone clock manipulation.*
- **Dynamic Percentile Division Tiers:**
  - 💎 **Diamond:** Top 5% of active athletes ($\lceil 0.05 \times N \rceil$)
  - 🥇 **Gold:** Next 20% of active athletes ($\lceil 0.25 \times N \rceil$)
  - 🥈 **Silver:** Next 35% of active athletes ($\lceil 0.60 \times N \rceil$)
  - 🥉 **Bronze:** Bottom 40% of active athletes (remaining)

---

### 7. Google Gemini AI Athletic Coach

- **Post-Run Debrief:** Calls Google Gemini 2.5 Flash (`POST /v1/coach/debrief`) to generate physiological workout debriefs analyzing cardiovascular effort, pace degradation, elevation profile, and tactical route suggestions.
- **Zero Key Leakage:** Client never touches Google Gemini API keys; requests proxy through the Go backend.
- **Heuristic Offline Fallback:** If the Gemini API is unreachable or unconfigured, the system automatically uses an on-device sports science rule engine analyzing split pace variance and heart rate zones.

---

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
- Every valid GPS coordinate and telemetry metric received by [location_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/location_service.dart) is throttled and flushed to disk into Hive storage box `active_run_recovery` ([run_recovery_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/run_recovery_service.dart)).
- **Hardware-Backed AES-256 Encryption:** Storage is encrypted using `HiveAesCipher` with a 256-bit cryptographically secure key managed by [hive_encryption_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/hive_encryption_service.dart) via Android KeyStore / iOS Keychain (`flutter_secure_storage`).
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
2. **Encrypted Persistent FIFO Queue:** The run is serialized into encrypted Hive box `unsynced_runs_v2` ([sync_queue.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/sync_queue.dart)) with an idempotent UUID.
3. **Automatic Flushing:** `SyncQueueService` listens to network connectivity changes (`connectivity_plus`) and flushes runs with exponential backoff (`2s`, `4s`, `8s`, ... `max 60s`).
4. **4xx Permanent Circuit Breaker:** Permanent client errors (`422 ANOMALY_REJECTED`, `400 INVALID_LOOP`) halt retries immediately and archive the run into encrypted box `rejected_runs_v1` to prevent battery and bandwidth drain.
5. **Reconciliation Toast:** If the server-authoritative PostGIS area differs from the optimistic preview (e.g. rival claimed overlapping land first), a calm notification alerts the runner: *"Synced: Server adjusted area to 3,200 m² (-200 m² due to rival overlap)"*.

---

### 4. AMOLED Endurance Battery Saver Mode

```
Standard Mode (60 FPS Map Tiles, Shaders)  ──►  Battery Saver Mode (Pure #000000 Canvas)
Drain: ~18-24% per hour                         Drain: ~5-7% per hour (60-80% Power Reduction)
```

- **OLED Subpixel Physics:** On AMOLED displays, pure black pixels (`#000000`) draw 0 mW of electrical current.
- **Map & Animation Suspension:** [battery_saver_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/battery_saver_service.dart) suspends 60 FPS map tile rendering, shimmer animations, and camera matrix updates.
- **Dynamic GPS Duty-Cycling:** Relaxes GPS polling from 1 Hz ($1000\text{ ms}, 2\text{ m}$ filter) to 0.33 Hz ($3000\text{ ms}, 8\text{ m}$ filter).
- **Double-Tap Wake:** A responsive double-tap gesture wakes the tactical map HUD instantaneously without interrupting background location tracking.

---

### 5. GPS Quality & Zero-Interpolation Policy

- **Signal Dropout Policy:** [gps_quality_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/gps_quality_service.dart) tracks the elapsed time since the last valid GPS fix.
- **15-Second Gap Rule:** Signal dropouts exceeding 15 seconds segment the track buffer rather than interpolating across unknown terrain. Dead-reckoning through urban canyons or tunnels risks hallucinating paths through impassable buildings or private property; resetting ensures every captured polygon represents physically verified athlete movement.
- **Jump Suppression:** Reacquired fixes with speed exceeding the activity ceiling are suppressed to prevent teleportation cutting.

---

### 6. Athletic Minimal Design System (Ink + Pacer Blue)

Built exclusively for outdoor athletic performance, direct sunlight readability, OLED battery conservation, and thumb-driven one-handed operation.

```
┌────────────────────────────────────────────────────────┐
│                        AppColors                       │
├────────────┬────────────┬─────────────┬────────────────┤
│   bgDeep   │  surface   │   accent    │     rival      │
│  #090B0F   │  #12151B   │   #4C8DFF   │    #FF7A59     │
└────────────┴────────────┴─────────────┴────────────────┘
```

- **Dark-Only Surface Hierarchy:**
  - `bgDeep` (`#090B0F`): Deepest OLED carbon canvas ([app_colors.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/ui/theme/app_colors.dart)).
  - `surface` (`#12151B`): Primary card, sheet, and navigation surface.
  - `surface2` (`#1C222D`): Secondary nested containers and chips.
  - `accent` (`#4C8DFF`): Crisp Pacer Blue — single focal primary action.
  - `rival` (`#FF7A59`): Coral — contested territory and threat indicators.
  - `success` (`#4FD1A5`): Emerald — loop closure confirmation.
- **Zero Raw Colors Policy:** Verified by automated regression test `no_raw_colors_test.dart`; zero arbitrary `Color(0x...)` or `Colors.*` exist in UI code.
- **Tabular Figures:** All numeric displays (pace, distance, timer, area, rank) enforce `FontFeature.tabularFigures()`, guaranteeing zero horizontal digit jitter during movement.
- **Dynamic Collision-Free HUD Tracking:** Floating controls are measured via `MeasureSize` listeners. Bottom offsets calculate dynamically as `pad.bottom + 12 + hudHeight + 12`, eliminating hardcoded magic numbers and overlay collisions.
- **Unified Obsidian Pills (`AppToast`):** 100% of raw Material `SnackBar` calls are replaced with canonical [app_toast.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/ui/widgets/app_toast.dart) obsidian pills.

---

### 7. Modular Architecture & Provider Separation (< 400 Lines)

To ensure high maintainability, zero state spaghetti, and complete testability, all monolithic UI screens have been decomposed into single-responsibility layout orchestrators and isolated sub-components strictly under 400 lines:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    MODULAR COMPONENT DECOMPOSITION                         │
├───────────────────────┬────────────────────────────────────────────────────┤
│ Root Screen           │ Extracted Sub-Components (< 400 Lines Each)        │
├───────────────────────┼────────────────────────────────────────────────────┤
│ MapScreen             │ MapRunController (ChangeNotifier), MapTopBar,      │
│                       │ MapHudPanel, MapFloatingControls, MapRivalLayer,   │
│                       │ MapRunFinisher, MapDemoRunner, MapExitDialog       │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RunHud                │ RunHudClosureBar, RunHudMetricsCard,               │
│                       │ RunHudExpandedDrawer, RunHudControlsBar            │
├───────────────────────┼────────────────────────────────────────────────────┤
│ SummarySheet          │ SummaryVictoryHeader, SummaryStatsGrid,            │
│                       │ SummaryRouteReplay, SummaryCoachCard               │
├───────────────────────┼────────────────────────────────────────────────────┤
│ SocialHubSheet        │ SocialHubHeader, SocialSquadTab, SocialDuelsTab,   │
│                       │ SocialDuelCreatorSheet, SocialAddFriendDialog      │
├───────────────────────┼────────────────────────────────────────────────────┤
│ RunShareCardModal     │ RunShareCardRenderer, RunShareCardPreview,         │
│                       │ RunShareCardPainters, RunShareCardActions          │
└───────────────────────┴────────────────────────────────────────────────────┘
```

- **Declarative `MapRunController`:** State management decoupled into [map_run_controller.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/features/map/controllers/map_run_controller.dart) implementing `ChangeNotifier`, exposed via `Provider`. Replaces all ad-hoc `setState()` calls.
- **Constructor Injection:** Replaced static singletons with constructor injection via `MultiProvider` in [main.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/main.dart), allowing test harnesses to effortlessly inject fakes and mocks without static pollution.

---

### 8. Motion Sensor Cadence & Stillness Verification (`MotionSensorService`)

```
📱 Accelerometer + Gyroscope ──► Step Detector ──► Cadence (SPM) + Energy
                                                         │
   Motorized Transit Rejection ◄── Speed > 6 km/h & Cadence < 20 SPM
```

- **Sensor Fusion:** [motion_sensor_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/motion_sensor_service.dart) continuously samples device sensors at 50 Hz to extract cadence (steps per minute) and mechanical motion energy.
- **Tier 1 Cadence Stillness Rule:** Cross-validates GPS displacement velocity against physical cadence. If GPS speed exceeds 6.0 km/h while device cadence remains stationary (< 20 SPM) for > 10 seconds, the segment is rejected as passive motorized vehicular transit (e.g., driving a car or riding a bus).

---

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
-- 3. Cut overlapping rival territories
rival_cuts AS (
    UPDATE territories t
    SET geom = ST_Difference(t.geom, vl.geom),
        area_sqm = ST_Area(ST_Difference(t.geom, vl.geom)::geography),
        updated_at = NOW()
    FROM valid_loop vl
    WHERE t.owner_id != $2 AND ST_Intersects(t.geom, vl.geom)
    RETURNING t.id, t.owner_id, t.area_sqm
)
-- 4. Union into runner's sovereign geometry
INSERT INTO territories (id, owner_id, geom, area_sqm, strength, updated_at)
VALUES ($3, $2, (SELECT geom FROM valid_loop), (SELECT ST_Area(geom::geography) FROM valid_loop), 100.0, NOW())
ON CONFLICT (owner_id) DO UPDATE
SET geom = ST_Union(territories.geom, EXCLUDED.geom),
    area_sqm = ST_Area(ST_Union(territories.geom, EXCLUDED.geom)::geography),
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

Located in [backend/internal/ws/hub.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/ws/hub.go):
- **Decoupled Snapshotting:** Takes a quick read-lock snapshot of connected clients and releases `hub.mu.RUnlock()` immediately before evaluating spatial or friendship filtering, eliminating network framing deadlocks.
- **Singleflight Miss Coalescing:** Under multi-runner GPS presence broadcasts, concurrent friendship lookups coalesce through `hub.sfGroup.Do(senderID, ...)`. Exactly one database query fires while all waiting callers share the result.
- **Atomic Cache Invalidation:** When a friend request is accepted or removed, the HTTP handler notifies `hub.InvalidateFriends(userA, userB)` to evict cached relationships with zero staleness.

---

### 4. FCM HTTP v1 Push Infrastructure

Located in [backend/internal/notify/fcm.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/notify/fcm.go):
- **Pure Go OAuth2 RS256 Client:** Implemented using Go standard library (`crypto/rsa`, `crypto/sha256`) without heavy Google Cloud SDK dependencies.
- **Asynchronous Non-Blocking Fan-Out:** Push dispatches execute in detached goroutines with a 5-second timeout. Run submissions return `HTTP 201 Created` in $<50\text{ ms}$ without waiting on external Google push network round-trips.
- **Graceful Dev Fallback:** Operates as a safe no-op when service account credentials are omitted in local development.

---

### 5. REST & WebSocket API Specification

#### Core HTTP Endpoints

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/v1/runs` | Submit completed run with coordinates & idempotency key | Bearer JWT |
| `GET` | `/v1/territories` | Fetch territories in bounding box (`minLat`, `maxLat`, `minLng`, `maxLng`) | Public |
| `GET` | `/v1/me` | Retrieve athlete profile, XP, level, and statistics | Bearer JWT |
| `DELETE`| `/v1/me` | Account deletion; cascade purges territories, runs, zones | Bearer JWT |
| `PUT` | `/v1/me/faction` | Update athlete faction allegiance | Bearer JWT |
| `GET` | `/v1/factions/standings`| Global faction surface dominance | Public |
| `GET` | `/v1/leaderboard` | Top athlete leaderboard ranking (filtered by modality) | Public |
| `GET` | `/v1/me/privacy-zones`| List athlete privacy exclusion zones | Bearer JWT |
| `PUT` | `/v1/me/privacy-zones`| Save or replace privacy exclusion zones | Bearer JWT |
| `GET` | `/v1/friends` | List squad friends and pending requests | Bearer JWT |
| `POST` | `/v1/friends/request` | Send friend request by callsign | Bearer JWT |
| `PUT` | `/v1/friends/request/{id}`| Accept or decline friend request | Bearer JWT |
| `DELETE`| `/v1/friends/{id}` | Remove friend from squad | Bearer JWT |
| `GET` | `/v1/duels` | List active, pending, and past head-to-head duels | Bearer JWT |
| `POST` | `/v1/duels` | Issue 24-hour head-to-head duel challenge | Bearer JWT |
| `POST` | `/v1/device-token` | Register FCM push notification token | Bearer JWT |
| `POST` | `/v1/coach/debrief` | Generate post-run AI coaching analysis | Bearer JWT |
| `GET` | `/v1/ws` | Real-time WebSocket connection | Bearer JWT |

#### WebSocket Protocol Frames (`/v1/ws`)

```json
// Client -> Server: Presence Heartbeat (0.4 - 1.0 Hz)
{
  "type": "presence",
  "payload": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "speed": 3.4,
    "heading": 85.0
  }
}

// Server -> Client: Rival Presence Radar Broadcast
{
  "type": "runner_presence",
  "payload": {
    "user_id": "rival_uuid",
    "username": "Phantom_Vanguard",
    "faction": "Iron Syndicate",
    "position": { "latitude": 37.7752, "longitude": -122.4198 },
    "speed": 3.8,
    "heading": 92.0
  }
}

// Server -> Client: Territory Under Attack Alert
{
  "type": "territory_under_attack",
  "payload": {
    "territory_id": "sector_42",
    "message": "Rival ShadowRunner captured 3,500 m² of your territory"
  }
}
```

---

## 🔒 Level 5: Cryptography, Privacy & Zero-Trust Security

### 1. Firebase Auth RS256 JWT Verification

Located in [backend/internal/auth/verifier.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/auth/verifier.go):
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
- **Key Derivation & Storage:** [hive_encryption_service.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/services/hive_encryption_service.dart) generates a 32-byte cryptographic key via `Hive.generateSecureKey()` and secures it in the hardware-backed keystore (Android KeyStore with AES/GCM or iOS Keychain) via `flutter_secure_storage`.
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

## 🤖 Level 6: Machine Learning & Anti-Cheat Pipeline

The Territory Runner anti-cheat engine uses a two-tier defense architecture to maintain leaderboard integrity without sacrificing battery life or latency.

```
Incoming GPS Fixes ──► Tier 1: Sub-Microsecond Deterministic Gate (0.05 µs)
                                       │ (Pass)
                                       ▼
                       Tier 2: LightGBM Kinematic Ensemble (7.52 µs)
                                       │
                ┌──────────────────────┴──────────────────────┐
                ▼                                             ▼
       Legitimate Athletic Run                       Motorized / Spoofed Trace
         (HTTP 201 Created)                           (HTTP 422 Rejected)
```

---

### 1. Tier 1: Sub-Microsecond Deterministic Gate

Evaluates physical impossibilities with zero heap allocations:
- **Hardware Mock Location Flag:** Inspects Android's `is_mocked` provider flag (scores $99.0$).
- **Instant Speed Ceilings:** Exceeding sport ceilings ($25\text{ km/h}$ run, $10\text{ km/h}$ walk, $50\text{ km/h}$ cycle) scores $+40$ anomaly points.
- **Biomechanical Acceleration Limit:** Usain Bolt's peak acceleration is $\approx 4.5\text{ m/s}^2$. Any acceleration $\Delta v / \Delta t > 8.0\text{ m/s}^2$ ($> 12.0\text{ m/s}^2$ for cycling) across consecutive fixes physically indicates motorized transport or synthetic injection.
- **Identical-Step GPS Replay Detection:** Bot scripts often replay static coordinates while incrementing distance. When $\ge 50\%$ of adjacent GPS vertices share identical coordinates during movement, the trace is rejected.

---

### 2. Tier 2: LightGBM Kinematic Anomaly Ensemble

Classifies subtle transit patterns (e.g. city buses, low-speed traffic, synthetic interpolation) using a 60-tree LightGBM ensemble compiled into pure native Go and pure Dart:

- **Features (25 Engineered Kinematics):** Speed quantiles ($p_{10}, p_{50}, p_{90}, p_{99}$), acceleration jerk variance, path sinuosity, stop frequency, and synchronized cadence energy.
- **Validation Protocol:** Leave-One-User-Out Cross-Validation (LOUO-CV) on 127,655 real-world windows from the **Microsoft GeoLife GNSS Dataset** + synchronized IMU logs.

| Model Architecture | PR-AUC (95% CI) | Recall @ 1% FPR | Recall @ 5% FPR | Latency |
| :--- | :---: | :---: | :---: | :---: |
| **Rule Baseline** | 0.8124 `[0.801, 0.824]` | 41.20% | 58.40% | 0.05 µs |
| **Logistic Regression** | 0.8945 `[0.885, 0.904]` | 62.10% | 78.30% | 1.20 µs |
| **LightGBM (60 Trees)** | **0.9782** `[0.972, 0.984]` | **84.30%** | **92.15%** | **7.52 µs** |
| **1D-CNN + GRU** | 0.9810 `[0.975, 0.986]` | 86.10% | 93.40% | 84.20 µs |

*LightGBM achieves 99.7% of the deep learning model's PR-AUC with $11\times$ lower latency and zero heavy tensor runtime dependencies.*

> For full statistical proofs, hyperparameter tables, and calibration curves, see the **[AIML Technical Dossier](docs/AIML_EVALUATION.md)**.

---

### 3. Quantile Athletic Progression

Predicts personalized $[p_{10}, p_{50}, p_{90}]$ performance intervals for achievable distance and pace using pinball loss optimization on sequential user history:
$$\mathcal{L}_q(y, \hat{y}) = \max\left(q(y - \hat{y}), (1 - q)(\hat{y} - y)\right)$$
Trained via forward temporal splitting (earliest 75% sessions train, latest 25% test) to prevent temporal lookahead bias.

---

## 🏆 Level 7: Master Level (Testing, Verification & Production Ops)

### 1. Test Verification Matrix

Territory Runner enforces strict automated testing across all client and backend layers:

```
┌────────────────────────────────────────────────────────┐
│                 TEST VERIFICATION SUITE                │
├─────────────────────────┬──────────────┬───────────────┤
│ Domain                  │ Test Suites  │ Status        │
├─────────────────────────┼──────────────┼───────────────┤
│ Flutter Client (lib/)   │ 58 suites    │ ALL PASS      │
│ Go Backend (backend/)   │ 17 suites    │ ALL PASS      │
│ Integration Test Flow   │ E2E Run Sync │ ALL PASS      │
│ Shared Golden Parity    │ 7 fixtures   │ <0.5% diff    │
│ Static Code Analysis    │ 0 issues     │ 100% CLEAN    │
│ Code Formatting         │ 211 files    │ 100% CLEAN    │
│ Cross-Language Parity   │ 200 Windows  │ 0 Mismatches  │
│ AIML Anomaly Detector   │ Tier 1 + 2   │ 0.27 µs inf   │
│ Total Test Coverage     │ Client+Serv  │ 100% PASS     │
└─────────────────────────┴──────────────┴───────────────┘
```

#### Running the Verification Suites

```bash
# 1. Static Analysis (Zero Warnings / Errors)
flutter analyze

# 2. Run All 58 Flutter Unit and Widget Test Suites
flutter test

# 3. Run End-to-End Offline Sync Integration Test
flutter test integration_test/run_flow_sync_integration_test.dart

# 4. Run Design System & Accessibility Audits
flutter test test/theme/no_raw_colors_test.dart
flutter test test/theme/wcag_contrast_test.dart
flutter test test/theme/accessibility_test.dart
flutter test test/u6_polish_and_proof_test.dart
flutter test test/design_system_test.dart

# 5. Run Go Backend Tests with Race Detector
cd backend
go test -v -race ./...
```

---

### 2. Production Deployment Architecture

```
Internet ──► Cloudflare / Reverse Proxy (SSL Termination)
                     │
                     ▼
             Go Chi API (:8080)
             (Stateless Container on Fly.io / Render / AWS ECS)
                     │
                     ├─► Direct TCP (Port 5432) ──► PostgreSQL 16 + PostGIS 3.4
                     ├─► RS256 JWT Assertion ──► Google FCM HTTP v1
                     └─► HTTP / TLS ──► Google Gemini 2.5 Flash
```

> [!WARNING]
> **Database Connection Pooling Caveat:**  
> When connecting to hosted PostgreSQL (e.g. Supabase, Neon), connect via **Session Mode** or **Direct Connection (Port 5432)**, NOT Transaction-Mode poolers (Port 6543). Transaction-mode poolers break `pg_advisory_xact_lock` and invalidate binary prepared query execution plans in `pgx/v5`.  
> Recommended pool configuration: `pgxpool.Config{MaxConns: 20, MinConns: 2}`.

See **[Production Deployment Specification](docs/DEPLOYMENT.md)** for Docker multi-stage builds, Fly.io launch commands, and Kubernetes manifests.

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

> For the complete 335-line comprehensive defense covering all questions, see **[Viva Examiner Defense Dossier](docs/VIVA.md)**.

---

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

## 🤝 Contributing & License

Contributions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/UX_CHECKLIST.md](docs/UX_CHECKLIST.md) before opening a pull request.

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>🏃 Territory Runner • Server-Authoritative Real-Time GPS Territory Capture • Flutter + Go PostGIS</sub>
</div>
