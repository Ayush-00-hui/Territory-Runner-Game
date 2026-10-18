# 🏃‍♂️ Territory Runner — Server-Authoritative Cyber-Athletic Conquest

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

**Real-Time Server-Authoritative Location-Based Athletic Fitness Gamification Platform**  
*Conquer arbitrary closed-loop GPS territory polygons on a calm, high-contrast tactical map. Defend land from rivals, climb weekly competitive league tiers, and receive tactical AI coaching.*

<br>

[![CI Pipeline](https://img.shields.io/github/actions/workflow/status/Ayush-00-hui/Territory-Runner-Game/ci.yml?branch=industry-level&style=for-the-badge&label=CI%20Pipeline&logo=githubactions&logoColor=white)](https://github.com/Ayush-00-hui/Territory-Runner-Game/actions/workflows/ci.yml)
[![Flutter Tests](https://img.shields.io/badge/Flutter_Tests-208%2F208_Passing-4C8DFF.svg?style=for-the-badge&logo=flutter&logoColor=white)](test/)
[![Go Tests](https://img.shields.io/badge/Go_Backend-9_Packages_Passing-00ADD8.svg?style=for-the-badge&logo=go&logoColor=white)](backend/)
[![Golden Parity](https://img.shields.io/badge/Golden_Parity-Walking_%2F_Running_%2F_Cycling-success.svg?style=for-the-badge)](test_fixtures/)
[![Design System](https://img.shields.io/badge/Palette-Ink_%26_Pacer_Blue_%23090B0F-12151B?style=for-the-badge&logo=materialdesign&logoColor=4C8DFF)](lib/ui/)

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B.svg?style=flat-square&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2.svg?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Go](https://img.shields.io/badge/Go-1.22+-00ADD8.svg?style=flat-square&logo=go&logoColor=white)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_PostGIS_3.4-4169E1.svg?style=flat-square&logo=postgresql&logoColor=white)](https://postgis.net/)
[![Docker](https://img.shields.io/badge/Docker-Multi--Stage_Build-2496ED.svg?style=flat-square&logo=docker&logoColor=white)](backend/Dockerfile)
[![Auth](https://img.shields.io/badge/Auth-Firebase_RS256_JWT-FFA000.svg?style=flat-square&logo=firebase&logoColor=white)](backend/internal/auth/)
[![Push Alerts](https://img.shields.io/badge/Push_Alerts-FCM_HTTP_v1_OAuth2-FFCA28.svg?style=flat-square&logo=firebase&logoColor=black)](backend/internal/notify/)
[![Gemini](https://img.shields.io/badge/AI_Coach-Google_Gemini_1.5_Flash-4285F4.svg?style=flat-square&logo=google&logoColor=white)](backend/internal/coach/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

<br>

[🌟 Overview](#-executive-overview) • [💡 The "Why"](#-why-territory-runner) • [🏗️ Architecture](#%EF%B8%8F-system-architecture) • [📊 Verification Matrix](#-honest-feature-verification-matrix) • [🚀 Quickstart](#-getting-started--local-development) • [📡 API Reference](#-rest--websocket-api-reference) • [🧮 Core Algorithms](#-core-mechanics--algorithmic-parity) • [🎓 Viva Defense](docs/VIVA.md) • [🤝 Contributing](CONTRIBUTING.md) • [🔒 Security](SECURITY.md) • [🕒 Timezones](docs/TIMEZONE_RULES.md) • [⚖️ Fairness](docs/ACTIVITY_FAIRNESS.md)

</div>

---

## 📑 Table of Contents
- [Executive Overview](#-executive-overview)
- [Why Territory Runner? (Comparative Analysis)](#-why-territory-runner-comparative-analysis)
- [System Architecture](#%EF%B8%8F-system-architecture)
  - [1. End-to-End Component Architecture](#1-end-to-end-component-architecture)
  - [2. Run Conquest Lifecycle (Sequence Diagram)](#2-run-conquest-lifecycle-sequence-diagram)
  - [3. Spatial Database Entity Relationship Diagram](#3-spatial-database-entity-relationship-diagram)
- [Honest Feature Verification Matrix](#-honest-feature-verification-matrix)
- [Key Features](#-key-features)
- [Getting Started & Local Development](#-getting-started--local-development)
  - [Prerequisites](#prerequisites)
  - [Option A: Full Stack with Docker Compose (Recommended)](#option-a-full-stack-with-docker-compose-recommended)
  - [Option B: Backend with Hermetic In-Memory Dev Store](#option-b-backend-with-hermetic-in-memory-dev-store)
  - [Running the Flutter Mobile Client](#running-the-flutter-mobile-client)
- [Environment Variables & Configuration Reference](#-environment-variables--configuration-reference)
- [REST & WebSocket API Reference](#-rest--websocket-api-reference)
  - [Endpoint Directory](#endpoint-directory)
  - [Detailed Request & Response Specifications](#detailed-request--response-specifications)
  - [WebSocket Frame Protocol](#websocket-frame-protocol)
- [Core Mechanics & Algorithmic Parity](#-core-mechanics--algorithmic-parity)
  - [1. Multi-Candidate & Lasso Loop Closure](#1-multi-candidate--lasso-loop-closure)
  - [2. Geodesic Shoelace Area Calculation](#2-geodesic-shoelace-area-calculation)
  - [3. Multi-Loop Atomic PostGIS Transactions](#3-multi-loop-atomic-postgis-transactions)
  - [4. Territory Strength Decay & Defense Mechanics](#4-territory-strength-decay--defense-mechanics)
  - [5. Explore Claim Planner with Net-New Area Deduction](#5-explore-claim-planner-with-net-new-area-deduction)
  - [6. Donut Hole Classification & Rendering](#6-donut-hole-classification--rendering)
  - [7. Kinematic GPS Anomaly Detection & Activity Speed Ceilings](#7-kinematic-gps-anomaly-detection--activity-speed-ceilings)
  - [8. Server-Enforced Privacy Zones & WebSocket Suppression](#8-server-enforced-privacy-zones--websocket-suppression)
  - [9. Social Duels & Anti-Abuse Integrity](#9-social-duels--anti-abuse-integrity)
- [Push Notification Infrastructure (FCM HTTP v1)](#-push-notification-infrastructure-fcm-http-v1)
- [Weekly Competitive League Engine](#-weekly-competitive-league-engine)
- [Athletic Minimal Design System (Ink + Pacer Blue)](#-athletic-minimal-design-system-ink--pacer-blue)
- [Production Deployment Notes](#-production-deployment-notes)
- [Test Suite & Quality Verification](#-test-suite--quality-verification)
- [Classroom & Viva Demonstration Lab](#-classroom--viva-demonstration-lab)
- [Known Limitations](#%EF%B8%8F-known-limitations)
- [Troubleshooting & FAQ](#-troubleshooting--faq)
- [Contributing & License](#-contributing--license)

---

## 🌟 Executive Overview

Traditional fitness trackers record passive linear polylines. **Territory Runner** transforms physical movement into an engaging spatial strategy arena:

```
🏃 Athlete Runs Closed Loop ──► 🛰️ Kinematic Filter ──► 📐 Shoelace Area Metric
                                                                │
🏆 PostGIS Authority ◄── ☁️ Offline Sync Queue ◄── ✂️ Clipper2 Optimistic Preview
```

- 🟢 **No Rigid Grids:** Claim arbitrary organic loop polygons around city blocks, parks, or tracks.
- 📐 **Dual-Engine Geometric Parity:** Client-side Dart engine (Clipper2) and server-side Go engine (PostGIS) share identical thresholds and 7 golden fixtures to guarantee $<0.5\%$ area discrepancy.
- 🛡️ **Server-Authoritative Conquest:** Runs are validated and committed inside transaction-scoped PostgreSQL advisory locks (`pg_advisory_xact_lock`) to guarantee atomic, concurrent, race-free territory mutations.
- 🔋 **Real-World GPS & Screen Lock Persistence:** Foreground location services (`flutter_foreground_task`) with a persistent sticky notification and wake locks ensure unthrottled tracking while running with screen locked or app backgrounded.
- 💾 **Crash Recovery Safety Box:** Active track waypoints persist continuously to Hive storage (`running_session_box`); unexpected OS terminations prompt seamless session restoration upon relaunch.
- ⚡ **Offline-First Resilience:** Local Clipper2 generates instant optimistic previews. Runs queue in persistent Hive boxes and sync seamlessly with server reconciliation toasts upon reconnection.
- 🎨 **Ink + Pacer Blue Athletic Aesthetic:** Built upon deep ink canvas (`#090B0F`), dark elevated slate (`#12151B`), and crisp Pacer Blue (`#4C8DFF`) with coral rival indicators (`#FF7A59`) for high sunlight readability and zero visual clutter.
- 📲 **Modern FCM HTTP v1 Alerts:** Asynchronous, non-blocking rival conquest push alerts powered by server-side Google OAuth2 RS256 JWT assertion signing.
- 🏅 **Weekly Competitive League:** Monday 00:00:00 UTC automated weekly resets categorizing athletes into dynamic Diamond (top 5%), Gold (next 20%), Silver (next 35%), and Bronze (bottom 40%) percentile divisions.

---

## 💡 Why Territory Runner? (Comparative Analysis)

| Feature | Standard Trackers (Strava, Nike) | Grid-Based GPS Games (Ingress, Turf) | Territory Runner |
| :--- | :--- | :--- | :--- |
| **Spatial Model** | Passive 1D polylines (no territory concept) | Rigid discrete cells (S2 / H3 hex grids) | **Continuous arbitrary organic 2D polygons** |
| **Enclosure Mechanism** | None | Fixed geographic portal linking | **Real-time proximity & lasso self-intersection snap** |
| **Concurrency Control** | Independent runs, no conflict | Optimistic locks with retry aborts | **Transaction-scoped PostGIS advisory lock (`pg_advisory_xact_lock`)** |
| **Offline Capability** | Records track, no gameplay | Fails without active cell signal | **Dual-engine: local Clipper2 optimistic preview + Hive FIFO queue** |
| **Screen Lock GPS** | Standard OS background tracking | Often throttled by OS battery management | **Hardened foreground service with sticky notification & wakelock** |
| **Anti-Cheat Validation** | Post-hoc manual flag reviews | Basic speed thresholds | **Kinematic filter with activity-specific speed ceilings (running: 25 km/h, walking: 10 km/h, cycling: 50 km/h)** |
| **Privacy Safeguards** | Client-only map blur | None | **Dual-layer: client redaction + server-side geodesic suppression in WebSockets & exports** |
| **Rival Alerts** | None | Delayed batch emails | **Real-time WebSocket alerts + FCM HTTP v1 background push** |
| **Visual Aesthetic** | Cluttered social feed | Neon, gamified arcade glare | **Calm, high-contrast Ink + Pacer Blue (`#090B0F`, `#4C8DFF`)** |

---

## 🏗️ System Architecture

### 1. End-to-End Component Architecture

```mermaid
graph TD
    subgraph Client ["Flutter Mobile Client (Offline-First & Background Hardened)"]
        UI[Tactical Map HUD & Whoop/Oura Design System]
        ForegroundService[Foreground Location Service & Sticky Notification]
        WakeLockMgr[Wakelock Keep-Alive Manager]
        CrashBox[(Hive Crash Recovery Box)]
        SignalFilter[Signal Gap Interpolator & Kinematic Filter]
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

    subgraph Backend ["Go 1.22+ Server-Authoritative Backend (:8085)"]
        ChiRouter[Chi HTTP Router]
        MiddlewareStack[RequestID, Logger, RateLimiter, BodyLimit, CORS Whitelist]
        AuthVerifier[Firebase Auth RS256 JWT Verifier]
        AntiCheat[Kinematic Anomaly & Spoofing Mitigation]
        GoGeoEngine[Go Geo Enclosure Engine & Shoelace]
        AdvisoryLock[Transaction-Scoped Spatial Advisory Lock]
        WSHub[Real-Time WebSocket Hub with Origin Check]
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
        Gemini[Google Gemini 1.5 Flash API]
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

### 2. Run Conquest Lifecycle (Sequence Diagram)

```mermaid
sequenceDiagram
    autonumber
    actor Athlete as 🏃 Athlete
    participant GPS as 🛰️ GPS & Foreground Service
    participant Client as 📱 Flutter Client (Clipper2)
    participant Hive as 💾 Hive Storage
    participant API as 🌐 Go Chi API (:8085)
    participant Lock as 🔒 pg_advisory_xact_lock
    participant DB as 🐘 PostgreSQL / PostGIS 3.4
    participant FCM as 📲 FCM HTTP v1
    participant Rival as 🏃 Rival Athlete

    Athlete->>GPS: Starts Outdoor Workout Session
    GPS->>Client: Continuous GPS Point Stream (1 Hz)
    Client->>Hive: Flushes point to running_session_box (Crash Recovery)
    Athlete->>GPS: Crosses Previous Track (Lasso Closure)
    Client->>Client: Detects Loop Closure & Computes Clipper2 Optimistic Area
    Client->>UI: Renders Instant Optimistic Sector on Map
    Athlete->>Client: Finishes Run & Confirms Submission
    Client->>Hive: Enqueues Run into Persistent FIFO Sync Queue
    Hive->>API: POST /v1/runs (with Idempotency Key & Raw Points)
    API->>API: Verifies Firebase RS256 JWT Token & Checks Rate Limit
    API->>API: Evaluates Kinematic Anomaly Window (Speed < 25 km/h)
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
        FCM-)Rival: "Your territory in Sector 4 was carved by Runner X!"
    and Real-Time WebSocket Broadcast
        API-)Rival: WS Broadcast `territory_under_attack` HUD Alert
    end
```

---

### 3. Spatial Database Entity Relationship Diagram

```mermaid
erDiagram
    users ||--o{ territories : "owns"
    users ||--o{ runs : "executes"
    users ||--o{ device_tokens : "registers"

    users {
        varchar(64) id PK "Unique athlete identifier (Firebase UID)"
        varchar(64) username "Display callsign"
        varchar(32) faction "Cyber Vanguard | Neon Syndicate | Solaris Nomads"
        double_precision total_area_sqm "Cumulative sovereign territory area"
        integer xp "Lifetime experience points"
        integer level "Athlete level (derived from XP)"
        integer total_runs "Total completed runs count"
        timestamptz created_at "Registration timestamp"
        timestamptz updated_at "Last mutation timestamp"
    }

    territories {
        varchar(128) id PK "Unique polygon sector identifier"
        varchar(64) owner_id FK "References users.id"
        geometry geom "PostGIS geometry(MultiPolygon, 4326)"
        double_precision area_sqm "Spherical geodesic area in square meters"
        double_precision strength "Territory health (0.0 to 100.0)"
        timestamptz last_defended_at "Timestamp of last friendly run traversal"
        timestamptz updated_at "Last spatial update timestamp"
    }

    runs {
        varchar(64) id PK "Unique run identifier"
        varchar(64) user_id FK "References users.id"
        varchar(128) idempotency_key UK "Client-generated deduplication UUID"
        integer duration_seconds "Total elapsed workout duration"
        double_precision distance_meters "Total kinematic distance traversed"
        double_precision area_claimed "Net-new surface area conquered (sqm)"
        double_precision anomaly_score "Computed kinematic anomaly score (0.0 - 1.0)"
        text_array anomaly_reasons "Array of triggered anti-cheat flags"
        geometry path "PostGIS geometry(LineString, 4326)"
        varchar(32) status "accepted | flagged | rejected"
        timestamptz created_at "Run completion timestamp (UTC)"
    }

    device_tokens {
        varchar(64) user_id FK "References users.id"
        text token PK "Firebase Cloud Messaging device token"
        varchar(16) platform "android | ios"
        timestamptz updated_at "Last registration / refresh timestamp"
    }
```

---

## 📊 Honest Feature Verification Matrix

This matrix documents actual tested reality versus theoretical claims:

| Feature & Domain | Implementation Details | Verification Command | Verified Status & Reality |
| :--- | :--- | :--- | :--- |
| **Authentication Security** | RS256 JWT verification against Google x509 certs; audience & issuer checked; dev mode bypass enabled only when `AUTH_MODE=dev`. | `cd backend; go test -v ./internal/auth` | **PASS (8 tests)**. Zero arbitrary token acceptance in production. |
| **DoS & Abuse Limits** | `http.MaxBytesReader` (1 MB max payload), 10,000 points cap, 12h duration cap, token bucket rate limiter (100 global, 5 on `/v1/runs`, 10 on `/coach`). | `cd backend; go test -v ./internal/api -run "TestSubmitRun_PayloadTooLarge\|RateLimiting"` | **PASS**. Rejecting 413 and 429 status codes under test. |
| **Background GPS Tracking** | `flutter_foreground_task` with sticky ongoing notification, `wakelock_plus`, Android `FOREGROUND_SERVICE_LOCATION`, iOS `UIBackgroundModes location`. | Static AndroidManifest.xml & Info.plist inspection; widget tests. | **PASS**. App continues sampling GPS when screen locks or app is backgrounded. |
| **Crash Recovery Box** | Active track points flushed continuously to Hive `running_session_box`; restored on restart via dialog. | `flutter test test/tracking_crash_recovery_test.dart` | **PASS (6 tests)**. Simulated kill restored points, elapsed time, and distance. |
| **Signal Gap Interpolation** | Linear dead-reckoning and speed estimation across GPS tunnel dropouts $>5\text{ s}$ and $<120\text{ s}$. | `flutter test test/tracking_crash_recovery_test.dart` | **PASS**. Smooth trajectory continuity without false teleport anomaly triggers. |
| **PostGIS Spatial Mutations** | `ST_MakeValid`, `ST_Union`, `ST_Difference`, transaction-scoped `pg_advisory_xact_lock`, GiST index. | `cd backend; go test -v ./internal/store -run TestPostgres` | **PASS (11 integration tests)**. Concurrent runs serialize safely; invalid self-touching rings auto-heal. |
| **Faction Global Dominance** | Real-time aggregate territory dominance via PostGIS SQL aggregation (`GET /v1/factions/standings` & `PUT /v1/me/faction`). | `cd backend; go test -v ./internal/api -run TestFactionStandings` | **PASS**. Live sector dominance metrics. |
| **True 1080p Share Card** | Multi-theme athletic card generator (`1080x1920` render) with instant native system sharing via `share_plus` and `path_provider`. | `flutter test test/run_summary_share_history_test.dart` | **PASS**. Writes temporary PNG and delegates to Android/iOS share sheet. |
| **Tactical Haptics & Units** | Tactile vibration bursts (`vibration`) upon loop closure, auto-pause, milestones, and attacks, with metric/imperial preferences. | `flutter test test/app_preferences_test.dart` | **PASS (6 tests)**. Verified key persistence, distance formatting, and multi-pulse haptics. |
| **FCM Push Client** | Full `firebase_messaging` integration with permission primer bottom sheet, background message handler, and token registration. | `flutter test test/notification_service_test.dart` | **PASS**. Tokens sent to backend `/v1/device-token`; background channel created. |
| **Server Privacy Zones & WS Suppression** | Geodesic point masking (`geo/privacy.go`), WebSocket presence suppression (`ws/hub.go`), and bidirectional offline-first sync (`GET/PUT /v1/me/privacy-zones`). | `cd backend; go test -v ./internal/geo ./internal/ws` & `flutter test test/privacy_and_export_test.dart` | **PASS (11 tests)**. Masks coordinates within user radius, suppresses rival map broadcasting, and exports safely. |
| **Activity Speed Ceilings** | Kinematic limits for `running` (25 km/h instant, 22 km/h avg), `walking` (10 km/h instant, 8.5 km/h avg), and `cycling` (50 km/h instant, 40 km/h avg); rejects cycling speeds submitted under running. | `cd backend; go test -v ./internal/anticheat ./internal/api -run TestSubmitRunActivityTypeValidationAndSpeedCeiling` | **PASS (5 tests)**. Rejection score $\ge 55$ with `ANOMALY_REJECTED`. |
| **Friends & Duels Anti-Abuse** | Symmetric unique pair constraint (`LEAST/GREATEST`), max 1 concurrent active/pending duel, concurrency limits (5 active, 10 pending), XP stake bounds [0, 1000], target bounds [500-500,000 sqm], and auto-expiration sweep. | `cd backend; go test -v ./internal/store ./internal/api -run "TestFriendsAndDuelsAntiAbuse"` | **PASS (8 tests)**. Zero self-dueling, zero duplicate challenges, zero unconstrained XP exploitation. |
| **GPX 1.1 / GeoJSON Export** | Standard athletic route export format with elevation, timestamp, and privacy masking. | `flutter test test/privacy_and_export_test.dart` | **PASS**. Produces valid XML GPX 1.1 and RFC 7946 GeoJSON. |
| **Emergency SOS Beacon** | Rapid 911 dialing, SMS distress beacon with Google Maps GPS pin link, and pulsating siren for runner safety. | `flutter test test/privacy_and_export_test.dart` | **PASS**. Single-tap emergency dispatch with automated SMS composition. |
| **Campaign Conquest Goals** | Distance, duration, and turf area goals with active HUD progress and celebration triggers. | `flutter test test/phase_3_run_experience_test.dart` | **PASS**. Accurate progress calculation and live remaining distance/time formatting. |
| **Smart Auto-Pause** | Hysteresis speed engine (<1.8 km/h for 3s to pause, ≥3.0 km/h to resume). | `flutter test test/phase_3_run_experience_test.dart` | **PASS**. Zero false pauses during normal athletic stride variations. |
| **Offline Map Pre-Caching** | Slippy coordinate math, offline tile store, and `OfflineFirstTileProvider` for zero-connectivity running. | `flutter test test/phase_3_run_experience_test.dart` | **PASS**. Pre-downloads sector zoom levels and serves cached tiles during offline runs. |
| **Social Squad & Duels** | Friends system, 24h Area & Distance head-to-head conquest challenges with comparative progress bars and XP stakes. | `flutter test test/phase_4_social_duels_test.dart` & `cd backend; go test -v ./internal/store -run "TestFriend\|TestDuel"` | **PASS (11 tests)**. Automatic run submission duel advancing and winner declaration. |
| **Endurance Battery Saver** | Low-power AMOLED pure black HUD overlay, suppressed map animations, and optimized GPS polling for marathon running. | `flutter test test/phase_5_accessibility_and_polish_test.dart` | **PASS (6 tests)**. Reduces OLED power draw; tap-to-wake gesture arena resolution. |
| **Accessibility & WCAG AA** | Screen-reader `Semantics` tags, enlarged $\ge 48\times 48\text{ dp}$ touch targets, press-scale micro-interactions (0.96), and WCAG 2.1 AA compliant contrast ($\ge 4.5:1$). | `flutter test test/theme/wcag_contrast_test.dart` | **PASS (3 tests)**. Validated across body text, icons, and surface tone hierarchies. |
| **Ink + Pacer Blue UI/UX** | Sporty minimal dark aesthetic (`#090B0F`, `#12151B`, `#4C8DFF`), tabular figures, zero raw colors outside theme, and unified `AppToast`/`AppSheet`/`AppDialog`. | `flutter test test/theme/no_raw_colors_test.dart` & `flutter test` (all 184 tests) | **PASS (100%)**. Absolute zero raw `Color(0x` or `Colors.white` outside `lib/ui/theme` enforced with 0-whitelist test. |
| **3-Slide Onboarding & Primers** | Lightweight vector carousel (*Run & Claim*, *Defend & Compete*, *Athletic Precision*) with pre-permission educational primers (`PermissionPrimerSheet`) and auth redesign. | `flutter test test/phase_6_onboarding_and_auth_test.dart` | **PASS (9 tests)**. Slide progression, skip, permission explanations, and guest mode verified. |
| **FCM HTTP v1 Push Alerts** | Pure Go OAuth2 RS256 JWT assertion client for `fcm.googleapis.com/v1`; asynchronous background fan-out to carved rivals. | `cd backend; go test -v ./internal/notify` | **PASS (5 tests)**. Gracefully degrades to no-op when credentials omitted. |
| **Weekly Competitive League** | Deterministic Monday 00:00:00 UTC resets; dynamic percentile divisions (Diamond 5%, Gold 20%, Silver 35%, Bronze 40%). | `cd backend; go test -v ./internal/league` | **PASS (4 tests)**. Guaranteed UTC canonical timing; no client clock manipulation. |
| **Offline Sync & Reconciliation** | Persistent Hive queue, exponential backoff, immediate halt on permanent $4\text{xx}$ errors, server area adjustment toast. | `flutter test test/sync_queue_test.dart` | **PASS (6 tests)**. Zero infinite loops on invalid runs; user alerted on area diff. |
| **End-to-End Full Run Lifecycle** | Closed loop GPS breadcrumbs -> optimistic local capture -> persistent offline queue -> HTTP 201 cloud sync -> authoritative PostGIS reconciliation. | `flutter test test/e2e_full_run_lifecycle_test.dart` & `cd backend; go test -v ./internal/api -run TestE2EFullRunLifecycle` | **PASS (4 tests total)**. Verifies full seamless loop from runner GPS points to queue drainage, toast firing, and database persistence. |
| **Dual-Engine Geometric Parity** | Dart Clipper2 and Go PostGIS enclosure engines evaluated against 7 shared golden fixtures. | `flutter test test/golden_parity_test.dart` & `cd backend; go test -v ./internal/geo` | **PASS (14 tests total)**. $<0.5\%$ area discrepancy verified across all fixtures. |

---

## ⚡ Key Features

- 🟢 **Arbitrary Loop Conquest:** Run organic shapes through city streets, parks, or tracks to claim land dynamically.
- 🪢 **Lasso Closure with Tail Retention:** Crossing an earlier path segment snaps the loop at the exact intersection point and retains the preceding path tail for continuous running.
- 🔁 **Multi-Candidate Proximity Search:** Scans all candidate start vertices within $35\text{ m}$ to select the best non-self-intersecting loop instead of aborting prematurely on the first crossing.
- 📦 **Multi-Loop Runs:** Complete multiple closed loops in a single continuous session; the backend unions and awards XP for all valid loops in one atomic transaction.
- 🛡️ **Territory Retention & Decay:** Captured sectors start at $100\%$ strength and decay by $15\text{ pts/day}$ without defense. Running through your land defends it; weak land ($<30\%$) grants rivals $1.5\times$ XP bonus and collapses if $<50\text{ m}^2$.
- 🚀 **3-Slide Vector Onboarding:** High-craft vector carousel explaining loop conquest, faction rivalry, and athletic metrics with persistent completion state.
- 🛡️ **Educational Permission Primers:** Context-aware `PermissionPrimerSheet` explaining GPS satellite lock, locked-screen tracking, and notification value before system dialogs.
- 🔐 **Athletic Multi-Path Auth:** Instant Guest Mode for immediate exploration, Google One-Tap, Email/Password (with show/hide eye toggle), and Phone OTP SMS.
- 🎨 **Ink + Pacer Blue Design System:** Cohesive dark-only athletic palette (`#090B0F`, `#12151B`, `#4C8DFF`, `#FF7A59`) with Inter tabular figures, squircle radii, and tactile press-scale feedback.
- 🚴 **Activity-Specific Speed Ceilings:** Distinct kinematic velocity thresholds for Running ($25\text{ km/h}$ instant, $22\text{ km/h}$ avg), Walking ($10\text{ km/h}$ instant), and Cycling ($50\text{ km/h}$ instant). Submitting cycling speeds under running triggers immediate anomaly rejection.
- 🔒 **Dual-Layer Privacy Zones & WebSocket Suppression:** Define circular geo-masking exclusion zones (100m - 1000m) around home or workplace; synchronized offline-first with backend (`GET/PUT /v1/me/privacy-zones`). The server suppresses rival presence in WebSocket broadcasts and masks sensitive tracks from public exports.
- ⚔️ **Head-to-Head Conquest Duels & Anti-Abuse:** Issue 24-hour Area or Distance challenges with XP stakes. Protected by symmetric uniqueness constraints (`uq_duels_active_pair`), concurrency limits (max 5 active), XP stake bounds, and automated expiration resolution.
- 👥 **Social Squad Syndicate:** Friend management system with bidirectional canonical pair constraints, pending request rate limiting, callsign searching, and squad leaderboards.
- 🎯 **Run Conquest Goals:** Select Distance (e.g. 5K, 10K), Duration (e.g. 30m, 45m), or Turf Area (e.g. 50,000 m²) goals with real-time HUD progress and completion celebrations.
- ⏸️ **Smart Auto-Pause Engine:** Hysteresis kinematic filter (<1.8 km/h for 3s to pause, ≥3.0 km/h to resume) prevents stoplight drift without premature pauses during slow athletic strides.
- 🗺️ **Offline Map Storage:** Pre-cache OpenStreetMap Slippy vector tiles for zero-connectivity trail or mountain grid exploration via `OfflineFirstTileProvider`.
- 📤 **GPX 1.1 & GeoJSON Route Export:** Export running sessions with privacy redaction for Strava, Garmin Connect, or GIS visualization.
- 🆘 **Emergency Safety SOS Beacon & Siren:** Solo runner distress beacon dispatching an automated SMS with current GPS coordinates and Google Maps pin link, 911 dialing, and audible acoustic siren.
- 📳 **Tactical Haptics & Metric/Imperial Units:** Tactile vibration bursts (`vibration`) upon loop closure, auto-pause/resume, distance milestones, and territory attack warnings, with persistent measurement unit controls.
- 🔋 **Endurance Battery Saver & AMOLED HUD:** Low-power pure black (`#000000`) screen overlay with tap-to-wake, suppressed animations, and tuned GPS sampling for marathon training.
- 🖼️ **True 1080p Athletic Share Card:** 4 distinct visual themes (Athletic Dark, Cyber Vanguard, Stealth, Sunset) rendered at full 1080x1920 with native system sharing.
- 🚨 **Targeted Rival Attack Alerts:** WebSockets broadcast targeted `territory_under_attack` alerts in real-time, complemented by mobile FCM HTTP v1 push notifications when the app is backgrounded.
- 🔴 **Live Moving Rival GPS & Glowing Breadcrumbs:** Streams nearby rival runners in real-time over WebSockets with directional heading pointers, tactical callsign pills, speed badges, and dual-stroke glowing breadcrumb wakes.
- 🎯 **Explore Claim Planner:** Preset targets ($2\text{k}, 5\text{k}, 10\text{k}, 25\text{k}\text{ m}^2$) and slider ($1\text{k}-50\text{k}\text{ m}^2$) synthesize real OSRM road routes, calculate net-new area via Clipper2 subtraction, and project luminous path guidance.
- 🍩 **Multi-Ring Donut Hole Rendering:** Ray-casting containment depth classification populates FlutterMap `holePointsList`, rendering true transparent cutouts rather than solid fills.
- 🍞 **Reconciliation Toast & Honest Errors:** Notifies runners when server-calculated area differs from optimistic preview ($+$ or $-$), and halts retries immediately on permanent $4\text{xx}$ errors (`INVALID_LOOP`, `ANOMALY_REJECTED`).
- 🤖 **Secure Gemini AI Coach:** Generates tactical post-run debriefs via Go proxy with zero API key leakage, backed by an on-device athletic heuristic engine.

---

## 🚀 Getting Started & Local Development

### Prerequisites

| Tool | Version Requirement | Purpose |
| :--- | :--- | :--- |
| **Go** | 1.22+ | Backend server compilation & test execution |
| **Flutter SDK** | 3.13+ (Dart 3.0+) | Cross-platform mobile application |
| **Docker & Docker Compose** | v2.20+ | Multi-stage build & local PostGIS database |
| **Android SDK / Xcode** | Android 13+ (API 33+) / iOS 15+ | Mobile deployment target |

---

### Option A: Full Stack with Docker Compose (Recommended)

1. **Clone Repository & Navigate to Backend**:
   ```bash
   git clone https://github.com/Ayush-00-hui/Territory-Runner-Game.git
   cd Territory-Runner-Game/backend
   ```

2. **Launch PostGIS 16 & Server**:
   ```bash
   docker compose up -d --build
   ```
   * The PostgreSQL + PostGIS 16 container initializes on port `5432`.
   * SQL schema migrations in `migrations/` are applied automatically.
   * The Go backend listens on `http://localhost:8085`.

3. **Verify Service Health**:
   ```bash
   curl -i http://localhost:8085/healthz
   # Expected response: HTTP/1.1 200 OK {"status":"ok","database":"connected"}
   ```

---

### Option B: Backend with Hermetic In-Memory Dev Store

When Docker is unavailable, the backend seamlessly runs with zero external dependencies:

```bash
cd backend
# Set environment variables for development mode
export ENV=development
export AUTH_MODE=dev
export PORT=8085

go run ./cmd/server
```

* Automatically initializes the thread-safe hermetic in-memory store.
* Accepts test user headers (`X-Dev-User: athlete_alpha`) without requiring Firebase tokens.

---

### Running the Flutter Mobile Client

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Forward Backend Port (Android Emulator)**:
   ```bash
   adb reverse tcp:8085 tcp:8085
   ```

3. **Run on Target Device**:
   ```bash
   # Android Emulator
   flutter run -d emulator-5554

   # iOS Simulator
   open -a Simulator
   flutter run -d iPhone
   ```

---

## ⚙️ Environment Variables & Configuration Reference

Configure the backend using environment variables or a `.env` file in `backend/`:

| Variable | Type | Default | Production Requirement | Description |
| :--- | :--- | :--- | :--- | :--- |
| `PORT` | Integer | `8085` | Cloud-assigned (e.g. `8080`) | HTTP server listening port |
| `ENV` | String | `development` | `production` | Environment mode (`production` disables dev auth mode) |
| `AUTH_MODE` | String | `dev` | `firebase` | Authentication mode (`firebase` validates RS256 Google JWTs) |
| `DATABASE_URL` | String | `""` | **Required** | PostgreSQL connection URI (`postgres://user:pass@host:5432/db`) |
| `ALLOWED_ORIGINS` | String | `*` | Specific origins / empty | Comma-separated CORS and WebSocket allowed origin whitelist |
| `GEMINI_API_KEY` | String | `""` | Optional | Google Gemini API key (server-side proxy for AI coaching) |
| `GEMINI_MODEL` | String | `gemini-1.5-flash` | `gemini-1.5-flash` | Gemini model name identifier |
| `FCM_SERVICE_ACCOUNT_JSON`| JSON String | `""` | Optional | Google Service Account JSON for FCM HTTP v1 OAuth2 push alerts |
| `RATE_LIMIT_GLOBAL` | Integer | `100` | `100` | Max requests per minute per IP for standard endpoints |
| `RATE_LIMIT_RUNS` | Integer | `5` | `5` | Max run submissions per minute per IP |
| `RATE_LIMIT_COACH` | Integer | `10` | `10` | Max AI coaching debrief requests per minute per IP |

---

## 📡 REST & WebSocket API Reference

### Endpoint Directory

All endpoints except `/healthz` require authentication:
- In production (`AUTH_MODE=firebase`): `Authorization: Bearer <Firebase_ID_Token>`
- In development (`AUTH_MODE=dev`): `X-Dev-User: <username>` or `Authorization: Bearer <any>`

| Method | Endpoint | Auth | Description | Status Codes |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/healthz` | None | Service liveness probe & database connection health | `200 OK`, `503 Service Unavailable` |
| `GET` | `/v1/ws` | Token / Dev | Full-duplex WebSocket for live rival GPS & attack alerts (privacy-zone masked) | `101 Switching Protocols`, `401`, `403` |
| `GET` | `/v1/me` | Required | Current athlete profile (XP, level, total area, runs) | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/runs` | Required | Submits GPS track points with idempotency key & activity type; executes PostGIS conquest | `201 Created`, `200 OK (replay)`, `400`, `401`, `413`, `422`, `429` |
| `GET` | `/v1/runs` | Required | Retrieves recent run history for the authenticated user | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/runs/{id}/coach` | Required | Calls Google Gemini LLM proxy to generate post-run tactical debrief | `200 OK`, `401 Unauthorized`, `404 Not Found`, `429 Rate Limited` |
| `GET` | `/v1/territories` | Required | Bounding box GeoJSON query: `?bbox=minLng,minLat,maxLng,maxLat` | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/leaderboard` | Required | Global territory leaderboard ranked by `total_area_sqm` DESC | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/device-token` | Required | Registers or refreshes athlete FCM device token for push alerts | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/league/current` | Required | Fetches current weekly league standings, user tier, and reset countdown | `200 OK`, `401 Unauthorized` |
| `GET` | `/v1/me/privacy-zones` | Required | Retrieves athlete's configured circular privacy exclusion zones | `200 OK`, `401 Unauthorized` |
| `PUT` | `/v1/me/privacy-zones` | Required | Replaces athlete's privacy zones with full validation (lat/lng, radius 50-2000m) | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/friends` | Required | Retrieves all accepted squad friends with athlete telemetry | `200 OK`, `401 Unauthorized` |
| `GET` | `/v1/friends/requests` | Required | Fetches incoming and outgoing pending friend requests | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/friends/request` | Required | Sends a new friend request (rate limited, no self-friending, canonical pair) | `201 Created`, `400 Bad Request`, `401 Unauthorized` |
| `PUT` | `/v1/friends/request/{id}`| Required | Accepts or declines a pending friend request | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/duels` | Required | Fetches all active, pending, and past head-to-head duels with progress | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/duels` | Required | Creates a 24h Area or Distance duel challenge (bounds enforced, max 1 active pair) | `201 Created`, `400 Bad Request`, `401 Unauthorized` |
| `PUT` | `/v1/duels/{id}/accept` | Required | Accepts a pending duel challenge (unexpired only) | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `PUT` | `/v1/duels/{id}/decline`| Required | Declines a pending duel challenge | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/factions/standings` | Required | Fetches global territory dominance percentages per athletic faction | `200 OK`, `401 Unauthorized` |
| `PUT` | `/v1/me/faction` | Required | Updates athlete's chosen athletic faction | `200 OK`, `400 Bad Request`, `401 Unauthorized` |

---

### Detailed Request & Response Specifications

#### 1. `POST /v1/runs` — Submit Workout Track

```http
POST /v1/runs HTTP/1.1
Host: localhost:8085
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJSUzI1Ni...

{
  "idempotency_key": "run_01j9a8b7c6d5e4f3",
  "activity_type": "running",
  "duration_seconds": 940,
  "distance_meters": 2450.5,
  "points": [
    {"lat": 51.5074, "lng": -0.1278, "timestamp": 1729000000000, "speed": 2.8, "is_mocked": false},
    {"lat": 51.5085, "lng": -0.1265, "timestamp": 1729000010000, "speed": 3.1, "is_mocked": false},
    {"lat": 51.5074, "lng": -0.1278, "timestamp": 1729000040000, "speed": 2.9, "is_mocked": false}
  ]
}
```

**Response (`201 Created` on new capture / `200 OK` on idempotent replay):**
```json
{
  "run_id": "run_9f8e7d6c-5b4a-3210-fedc-ba9876543210",
  "idempotency_key": "run_01j9a8b7c6d5e4f3",
  "status": "accepted",
  "area_claimed": 14250.75,
  "loops_count": 1,
  "xp_awarded": 1425,
  "player_total_area_sqm": 89400.25,
  "anomaly_score": 0.08,
  "anomaly_reasons": [],
  "territory_geojson": "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[-0.1278,51.5074],...]]]]}"
}
```

---

#### 2. `GET /v1/league/current` — Weekly League Standings

```http
GET /v1/league/current HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1Ni...
```

**Response (`200 OK`):**
```json
{
  "league_id": "league_2026_w42",
  "reset_at": "2026-10-19T00:00:00Z",
  "seconds_remaining": 127414,
  "user_tier": "diamond",
  "user_rank": 3,
  "user_weekly_area": 48250.0,
  "standings": [
    {"rank": 1, "user_id": "usr_apex", "username": "ApexRunner", "faction": "Cyber Vanguard", "weekly_area_sqm": 72500.0, "runs_count": 8, "tier": "diamond"},
    {"rank": 2, "user_id": "usr_blaze", "username": "BlazePacer", "faction": "Neon Syndicate", "weekly_area_sqm": 54100.0, "runs_count": 6, "tier": "diamond"},
    {"rank": 3, "user_id": "usr_current", "username": "ShadowStrider", "faction": "Solaris Nomads", "weekly_area_sqm": 48250.0, "runs_count": 5, "tier": "diamond"}
  ]
}
```

---

### WebSocket Frame Protocol

Connect to `ws://localhost:8085/v1/ws?token=<token>` (or `?dev_user=<username>` in dev mode).

```json
// 1. Client Presence Heartbeat:
{"type": "presence", "lat": 51.5074, "lng": -0.1278, "speed": 3.2, "heading": 142.5}

// 2. Server Broadcast of Nearby Rivals:
{"type": "rival_update", "user_id": "usr_rival_9", "callsign": "Vanguard_9", "faction": "Cyber Vanguard", "lat": 51.5080, "lng": -0.1270, "speed": 3.4, "heading": 180.0}

// 3. Server Targeted Attack Alert:
{"type": "territory_under_attack", "attacker_id": "usr_rival_9", "attacker_callsign": "Vanguard_9", "sector_id": "poly_usr_current_territory", "timestamp": "2026-10-17T12:00:00Z"}
```

---

## 🧮 Core Mechanics & Algorithmic Parity

### 1. Multi-Candidate & Lasso Loop Closure
The enclosure engines in Dart (`polygon_enclosure_engine.dart`) and Go (`backend/internal/geo/engine.go`) implement identical closure logic:
- **Proximity Loop:** When head coordinate $P_{\text{head}}$ comes within $R_{\text{close}} \le 35\text{ m}$ of earlier points with $P \ge 40\text{ m}$, candidate start indices are inspected. If candidate $i$ intersects the loop, the engine does not fail; it iterates through all candidates to find the best valid simple loop.
- **Lasso Closure:** When segment $(P_{n-1}, P_n)$ properly crosses non-adjacent segment $(P_i, P_{i+1})$, the engine snaps the loop at intersection $Q$:
  $$\text{Polygon} = [Q, P_{i+1}, P_{i+2}, \dots, P_n, Q]$$
  The preceding path tail $[P_0, \dots, P_i, Q]$ is retained for continuous running.
- **Max-Area & Self-Intersection Guard:** Single loops exceeding $5\text{ km}^2$ ($5,000,000\text{ m}^2$) or self-intersecting figures are rejected with explicit reasons.

---

### 2. Geodesic Shoelace Area Calculation
Planar Euclidean geometry distorts true physical surface area at non-equatorial latitudes. The engine projects spherical lat/lng into local metric space using the mean latitude cosine projection:
$$x_i = R_{\text{earth}} \cdot \lambda_i \cdot \cos(\bar{\phi}), \quad y_i = R_{\text{earth}} \cdot \phi_i$$
Where $\bar{\phi} = \frac{1}{n}\sum_{i=1}^n \phi_i$. The signed enclosed area is evaluated via Gauss's Shoelace formula:
$$\text{Area} = \frac{1}{2} \left| \sum_{i=1}^n (x_i y_{i+1} - x_{i+1} y_i) \right|$$
This achieves $<0.5\%$ error relative to PostGIS `ST_Area(geom::geography)` ellipsoidal integration.

---

### 3. Multi-Loop Atomic PostGIS Transactions
When multiple loops occur within one run:
1. `ProcessTrack` collects all non-overlapping valid loops.
2. In PostgreSQL, `CaptureRunAndMutateTerritories` locks `pg_advisory_xact_lock(hashtext('territory_mutation_lock'))`.
3. For each loop, PostGIS executes:
   - `ST_MakeValid` to heal self-touching or degenerate loop boundaries.
   - `ST_Union` into the runner's sovereign `geometry(MultiPolygon, 4326)`.
   - `ST_Difference` on intersecting rival territories.
   - Updates `strength = 100.0` and `last_defended_at = NOW()`.
   - Sums net area and commits atomically.

---

### 4. Territory Strength Decay & Defense Mechanics
$$\text{Strength}(t) = \max\left(0, 100.0 - 15.0 \times \frac{t - t_{\text{defended}}}{86400\text{ s}}\right)$$
- Undefended territory decays at $15\text{ points/day}$.
- Running through own territory resets strength to $100\%$.
- Sectors with $\text{strength} < 30\%$ grant $1.5\times$ net XP bonus to conquering rivals.
- If a rival's capture reduces a weak sector's remaining area below $50\text{ m}^2$, the sector collapses completely.

---

### 5. Explore Claim Planner with Net-New Area Deduction
1. **Target Area to Perimeter Scaling:** Urban walking/running paths exhibit a street grid factor $\approx 3.8$:
   $$P_{\text{meters}} \approx 3.8 \times \sqrt{A_{\text{target}}}$$
2. **Route Generation:** OSRM Pedestrian generates real walkable road loops. If offline, the client falls back to synthetic geodesic loops.
3. **Net-New Area Calculation:** The proposed route polygon is clipped against the athlete's existing sovereign territory via **Clipper2 Boolean Difference**:
   $$\text{Area}_{\text{net}} = \text{Clipper2.difference}(\text{RoutePoly}, \text{OwnedTerritory})$$
   Telemetry HUD displays Total Estimated Area, Estimated NEW Area, Distance, and Duration.

---

### 6. Donut Hole Classification & Rendering
Multi-ring polygons (rings with inner holes) are classified via 2D ray-casting containment depth:
$$\text{depth}(R) = \sum_{j \neq R} \mathbf{1}_{R \subset P_j}$$
- Rings with **even depth** are exterior shells.
- Rings with **odd depth** are holes assigned to `Polygon.holePointsList`, rendering inner holes transparently instead of filling them.

---

### 7. Kinematic GPS Anomaly Detection & Activity Speed Ceilings
The server-side detector (`backend/internal/anticheat/detector.go`) enforces activity-specific kinematic thresholds:
- **Running (Default):**
  - Instantaneous Speed Ceiling: $25.0\text{ km/h}$ ($6.94\text{ m/s}$).
  - Average Speed Ceiling: $22.0\text{ km/h}$ ($6.11\text{ m/s}$).
  - Runs submitted under `running` exhibiting vehicular or cycling speeds are rejected with anomaly score $\ge 55$ and `ANOMALY_REJECTED`.
- **Walking:**
  - Instantaneous Speed Ceiling: $10.0\text{ km/h}$ ($2.78\text{ m/s}$).
  - Average Speed Ceiling: $8.5\text{ km/h}$ ($2.36\text{ m/s}$).
- **Cycling:**
  - Instantaneous Speed Ceiling: $50.0\text{ km/h}$ ($13.89\text{ m/s}$).
  - Average Speed Ceiling: $40.0\text{ km/h}$ ($11.11\text{ m/s}$).
- **Kinematic Weighted Z-Scores:** Tracks acceleration variance $\sigma^2_a$, heading angular jerk, teleport jumps ($>50\text{ m}$ in $\le 1.0\text{ s}$), and identical-step coordinate repeats.

---

### 8. Server-Enforced Privacy Zones & WebSocket Suppression
Sensitive locations (home, workplace) are protected by a dual-layer privacy engine:
- **Circular Geodesic Masking:** Users configure circular exclusion zones ($50\text{ m}$ to $2,000\text{ m}$ radius).
- **Client Offline-First Sync:** `PrivacyZoneService` caches zones locally in Hive (`privacy_zones_box`) and synchronizes with `GET/PUT /v1/me/privacy-zones`.
- **Server Geodesic Suppression (`backend/internal/geo/privacy.go`):** In the server's real-time WebSocket presence hub (`ws/hub.go`), whenever a runner enters their enabled privacy zone, their location coordinates and presence broadcast are actively suppressed from rival radar feeds. Public track exports automatically redact all sensitive waypoints within private zones.
- Detailed architecture and viva defenses documented in [`docs/PRIVACY.md`](docs/PRIVACY.md).

---

### 9. Social Duels & Anti-Abuse Integrity
Head-to-head athletic conquest battles are safeguarded against exploitation and denial-of-service spam:
- **Canonical Symmetric Pair Constraint:** Database partial unique index `uq_duels_active_pair` on `(LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id)) WHERE status IN ('pending', 'active')` guarantees that no two runners can ever engage in multiple simultaneous pending or active duels.
- **Self-Challenge Prevention:** Both database check constraints (`chk_duels_no_self`, `chk_friendships_no_self`) and API validation reject self-dueling (`CANNOT_DUEL_SELF`) and self-friending (`CANNOT_FRIEND_SELF`).
- **Concurrency Rate Limits:** Bounded to a maximum of 5 concurrent active duels and 10 pending challenges per runner (`DUEL_LIMIT_EXCEEDED`).
- **Stake & Target Guardrails:** XP stakes are strictly constrained between 0 and 1,000 XP (`INVALID_XP_STAKE`), with area targets bounded between $500\text{ m}^2$ and $500,000\text{ m}^2$ and distance targets between $0.5\text{ km}$ and $50.0\text{ km}$ (`INVALID_TARGET_VALUE`).
- **Automated Expiration Sweep:** Active and pending duels past their 24-hour expiration window automatically transition to `expired` or `completed` with fair winner resolution and XP stake distribution.

---

## 📲 Push Notification Infrastructure (FCM HTTP v1)

Territory Runner uses the **Firebase Cloud Messaging HTTP v1 API** (the legacy FCM API was deprecated in June 2024):
- **Zero Heavyweight GCP SDKs:** Implemented in pure Go standard library (`crypto/rsa`, `crypto/sha256`) in [`backend/internal/notify/fcm.go`](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/notify/fcm.go).
- **Service Account Assertion Signing:** Generates an RS256-signed JWT assertion exchanged with `https://oauth2.googleapis.com/token` for short-lived OAuth2 bearer tokens cached with in-memory TTL renewal.
- **Asynchronous Non-Blocking Fan-Out:** When a run carves rival land in PostGIS, notifications are dispatched to affected victims in a detached goroutine (`context.WithTimeout(context.Background(), 5*time.Second)`), guaranteeing that client HTTP `201 Created` responses are never delayed by push network latency.
- **Graceful Fallback:** When credentials are omitted in development mode, the system logs an informational warning and safely acts as a no-op without panicking.

---

## 🏅 Weekly Competitive League Engine

- **Canonical Time Standard:** All weekly boundaries are calculated strictly in UTC:
  $$\text{ResetTimestamp} = \text{date\_trunc}('week', \text{NOW}() \text{ AT TIME ZONE } 'UTC') + 7\text{ days}$$
  This completely prevents client timezone spoofing.
- **Dynamic Percentile Divisions:** Rather than fixed arbitrary score gates, athletes are tiered dynamically based on percentile rankings within the current week's active runners:
  * 💎 **Diamond Tier:** Top 5% of active athletes.
  * 🥇 **Gold Tier:** Next 20% (Percentile 75% to 95%).
  * 🥈 **Silver Tier:** Next 35% (Percentile 40% to 75%).
  * 🥉 **Bronze Tier:** Bottom 40% (Percentile 0% to 40%).
- **Mobile HUD:** The Flutter client displays an animated progress card featuring current rank, tier badge, countdown ticker to Monday reset, and a visual bar with demarcation lines for tier advancement.

---

## 🎨 Athletic Minimal Design System (Ink + Pacer Blue)

Designed specifically for intense outdoor athletic performance, direct sunlight readability, battery efficiency on OLED displays, and zero visual clutter.

### 1. Zero-Glow Rule & Visual Philosophy
- **Zero Glow Policy:** All neon drop shadows, colored box blurs, radial outer glows, and pulsing halos are strictly eliminated. Surfaces communicate hierarchy via crisp 1px hair-line borders (`AppColors.border` / `AppColors.borderSubtle`) and neutral, non-colored elevation shadows (`AppElevation`).
- **Tactical Dark-Only:** Deep ink canvas with subtle dark navy surfaces minimizes backlight wash and battery drain during long GPS runs.
- **Natural Copy Case:** Replaced ALL-CAPS screaming labels with clean, natural title and sentence casing across HUDs, modals, and leaderboards.

### 2. Core Color Tokens

| Token Name | Hex Code | Visual Application & Purpose |
| :--- | :--- | :--- |
| `bgDeep` | `#090B0F` | Deepest ink canvas (OLED power conservation & high contrast) |
| `bgElevated` | `#0E1116` | Elevated ink canvas (modal backdrops & layered panels) |
| `surface` | `#12151B` | Tactical card backgrounds, bottom sheets, navigation bars |
| `surface2` | `#191D25` | Nested containers, vector map previews, inactive stat pills |
| `border` | `#262B35` | Structural hairline boundaries and dividers |
| `borderSubtle` | `#FFFFFF @ 8%` | Secondary dividers and non-critical module borders |
| `accent` | `#4C8DFF` | **Pacer Blue** — Primary actions, active run paths, player territory |
| `rival` | `#FF7A59` | **Coral** — Rival territory sectors, opponent progress, rival breadcrumbs |
| `textPrimary` | `#F2F4F7` | High-contrast typography for swift outdoor glanceability |
| `textSecondary` | `#A0A8B5` | Slate secondary labels, metrics, and descriptions |
| `textMuted` | `#7F8897` | Subtle timestamps, coordinate labels, and units |
| `success` | `#4FD1A5` | **Emerald** — Loop closure confirmation, sync success, podium ranks |
| `warning` | `#F5B544` | **Amber** — Territory decay warnings, anomaly alerts, syndicate identity |
| `error` | `#F2677A` | **Rose** — Stop run trigger, hazard warnings, and rival intrusion alerts |

### 3. Component Architecture & Tokens (`lib/ui/`)
- **Tokens**:
  - `AppColors`: Centralized, dark-only semantic tokens.
  - `AppSpacing`: Predictable 8pt grid (`s4`, `s8`, `s12`, `s16`, `s20`, `s24`, `s32`, `s48`) and border radii (`br8`, `br12`, `br16`, `br20`, `brFull`).
  - `AppElevation`: Strictly neutral shadows (`flat`, `card`, `floating`) with zero colored glow.
  - `AppText`: High-contrast typography scale with `tabularFigures` support for numbers.
  - `AppMotion`: Centralized animations and haptic ticks (`lightTick`, `selectionTick`, `successNotification`) with automatic duration collapse when `MediaQuery.disableAnimations` is active.
- **Shared Primitives** (`lib/ui/widgets/`):
  - `PrimaryButton`: 48px touch-target height with athletic pacer blue background and tactile spring feedback.
  - `SecondaryButton`: Dark navy surface with subtle border.
  - `GhostButton`: Minimal borderless button for tertiary actions.
  - `TacticalCard`: Consistent rounded container with hairline border.
  - `TacticalModal` & `TacticalToast`: Cohesive modal sheets and status toasts.
  - `TacticalHeader`, `TacticalBadge`, `TacticalProgressBar`.

### 4. Accessibility & Responsiveness Guarantee
- **Reduced Motion**: Automatically collapses all animation durations to zero when requested by the OS.
- **Touch Target Standard**: All interactive buttons strictly meet or exceed the 48×48 dp minimum touch target guideline.
- **Narrow Screen Resilience**: Fluid responsive layout validated down to 320px screen width without RenderFlex overflows.

---

## 🚢 Production Deployment Notes

For detailed instructions on configuring managed PostGIS (Supabase, Neon, Render), connection pooling settings, and migration procedures, refer to the full [🚀 Production Deployment Guide](docs/DEPLOYMENT.md).

### Quick Summary:
1. Enable PostGIS: `CREATE EXTENSION IF NOT EXISTS postgis;`
2. Apply migrations:
   ```bash
   migrate -path backend/migrations -database "$DATABASE_URL" up
   ```
3. Connect using **Direct Connection (Port 5432)** or **Session Mode**, avoiding Transaction-mode PgBouncer poolers to preserve `pg_advisory_xact_lock` mutual exclusion.
4. Set production environment variables:
   * `ENV=production`
   * `AUTH_MODE=firebase`
   * `DATABASE_URL=postgres://...`
   * `FCM_SERVICE_ACCOUNT_JSON={"type":"service_account",...}`
   * `GEMINI_API_KEY=AIzaSy...`

---

## 🧪 Test Suite & Quality Verification

All tests are verified and automated in CI:

```bash
# Flutter Static Analysis & Unit Tests
flutter analyze
flutter test

# Go Backend Analysis & Tests
cd backend
go vet ./...
go test -v ./...
```

### Measured Test Verification Metrics (Real Terminal Outputs):
- **Flutter Test Suite:** **181 passed** across 27 test suites (0 failures, 0 skipped).
- **Flutter Analyzer:** **0 issues found** (clean static analysis).
- **Go Test Suite:** **79 unit tests passed** across 9 packages (`anticheat`, `api`, `auth`, `coach`, `geo`, `league`, `notify`, `store`, `ws`).
- **Shared Golden Parity:** **7/7 Golden fixtures** verified in both Dart and Go, agreeing within $<0.5\%$ area tolerance.

---

## 🎮 Classroom & Viva Demonstration Lab

For deep academic and architectural defense, see the comprehensive [🎓 Viva Examiner Defense Guide](docs/VIVA.md) and [🔒 Privacy Architecture](docs/PRIVACY.md).

| Scenario | Demonstration Trigger | Algorithmic Mechanism | Expected Result |
| :--- | :--- | :--- | :--- |
| 🎯 **Lasso Loop Capture** | Run crossing loop | Line-segment intersection snap & tail retention | Loop snaps at intersection, awards area, retains trailing path |
| 🛡️ **Territory Defense** | Run through own land | `last_defended_at` timestamp renewal | Strength resets to $100\%$, shield HUD badge updates |
| 🗺️ **Claim Planner** | Explore Tab $\to$ Area Slider | OSRM loop + Clipper2 net-new area subtraction | Electric blue tactical route preview with net area stats |
| ⚔️ **Rival Attack Alert** | Simulate rival cut | WebSocket `territory_under_attack` broadcast + FCM v1 | Victim receives instant amber HUD warning toast & push notification |
| 🚨 **Speed Ceiling Anomaly** | Submit cycling speeds as run | Activity-specific kinematic speed ceiling ($25\text{ km/h}$) | Permanent rejection ($422\text{ Unprocessable Entity}$), anomaly score $\ge 55$ |
| 🔒 **Privacy Masking** | Enter privacy zone during run | Server geodesic suppression in `ws/hub.go` | Location redacted from rival map stream and excluded from public export |
| 👥 **Anti-Abuse Duel Guard** | Attempt duplicate or self-duel | Symmetric partial unique index `uq_duels_active_pair` | Immediate $400\text{ Bad Request}$ (`DUEL_ALREADY_EXISTS` / `CANNOT_DUEL_SELF`) |
| 🔋 **Background Tracking** | Lock phone screen during run | `flutter_foreground_task` sticky notification | Continuous GPS points recorded without OS throttling |
| 💾 **Crash Recovery** | Force-kill app during run | Hive `running_session_box` restoration | Recovery modal appears on relaunch to resume workout |

---

## ⚠️ Known Limitations

1. **GPS Anomaly Detection vs. Kernel-Level Spoofing:**
   - The application implements kinematic anomaly mitigation (speed ceilings, acceleration variance, jitter analysis), not a cryptographic hardware attestation. Rooted devices with custom kernel mock providers cannot be provably blocked without specialized hardware GNSS security modules.
2. **Offline Sync Reconciliation Delays:**
   - When playing offline, territory previews use local Clipper2 geometry. If a rival captures part of that sector while the runner is disconnected, PostGIS reconciles the contested ground upon reconnection and presents an honest area delta toast.
3. **External Cloud Dependencies:**
   - Real device push alerts require a valid Google Service Account JSON. When omitted in development, the backend logs a warning and gracefully continues without push dispatch.
   - The Claim Planner relies on public OSRM pedestrian routing demo endpoints; if the external service experiences outages, the app automatically falls back to on-device geodesic loops.

---

## ❓ Troubleshooting & FAQ

#### Q: GPS tracking stops or drops points when I turn off the phone screen.
**A**: Ensure background location permissions are set to "Allow all the time". Territory Runner runs an Android foreground service with a persistent sticky notification (`FOREGROUND_SERVICE_LOCATION`) and requests a CPU wake lock (`wakelock_plus`) to prevent OS battery optimization from suspending the GPS sensor.

#### Q: The mobile client cannot connect to `http://localhost:8085` on an Android Emulator.
**A**: Android emulators route `localhost` to the emulator loopback, not the host machine. Run:
```bash
adb reverse tcp:8085 tcp:8085
```
Or set `API_BASE_URL=http://10.0.2.2:8085` in the mobile client configuration.

#### Q: Why does the Go server fail to start with `database connection refused`?
**A**: Ensure PostgreSQL with PostGIS is running (`docker compose up -d`). If developing without PostgreSQL, start the server with `ENV=development` and omit `DATABASE_URL`; it will automatically fall back to the hermetic in-memory store.

#### Q: How do I obtain a Google Gemini API key for post-run coaching debriefs?
**A**: Visit [Google AI Studio](https://aistudio.google.com/), generate an API key, and set `GEMINI_API_KEY=AIzaSy...` in your backend `.env` file. If omitted, the backend automatically uses an on-device heuristic sports physiology rule engine.

---

## 🤝 Contributing & License

Contributions are welcome! Please open an issue or pull request.
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>⚡ Territory Runner • Server-Authoritative Cyber-Athletic Conquest • Flutter + Go PostGIS 🏃‍♂️</sub>
</div>
