# 🏃‍♂️ Territory Runner — Server-Authoritative Cyber-Athletic Conquest

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Go](https://img.shields.io/badge/Go-1.22+-00ADD8.svg?style=for-the-badge&logo=go&logoColor=white)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_PostGIS-4169E1.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgis.net/)
[![Docker](https://img.shields.io/badge/Docker-Multi--Stage_Build-2496ED.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Clipper2](https://img.shields.io/badge/Polygon_Clipping-Clipper2-22c55e.svg?style=for-the-badge)](https://pub.dev/packages/clipper2)
[![Flutter Tests](https://img.shields.io/badge/Flutter_Tests-100%2F100_Passing-brightgreen.svg?style=for-the-badge)](test/)
[![Go Tests](https://img.shields.io/badge/Go_Backend_Tests-6%2F6_Passing-brightgreen.svg?style=for-the-badge)](backend/)
[![Golden Fixtures](https://img.shields.io/badge/Golden_Fixtures-7%2F7_Parity-success.svg?style=for-the-badge)](test_fixtures/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

<br>

**Territory Runner** is a real-time location-based athletic fitness gamification platform. By running, jogging, or walking in the physical world, athletes conquer arbitrary closed-loop GPS territory polygons on an interactive dark cybernetic tactical map, competing for territory sovereignty, defending land from rivals, and receiving AI coaching insights.

[✨ Key Features](#-key-features) • [🏗️ Architecture](#%EF%B8%8F-system-architecture) • [📡 API Reference](#-rest--websocket-api-reference) • [🧮 Core Mechanics & Parity](#-core-mechanics--algorithmic-parity) • [🚢 Free-Tier Deployment](#-production-deployment-notes) • [⚠️ Known Limitations](#%EF%B8%8F-known-limitations)

</div>

---

## 📑 Table of Contents
- [Executive Overview](#-executive-overview)
- [System Architecture](#%EF%B8%8F-system-architecture)
- [Key Features](#-key-features)
- [REST & WebSocket API Reference](#-rest--websocket-api-reference)
- [Core Mechanics & Algorithmic Parity](#-core-mechanics--algorithmic-parity)
  - [1. Multi-Candidate & Lasso Loop Closure](#1-multi-candidate--lasso-loop-closure)
  - [2. Multi-Loop Atomic PostGIS Transactions](#2-multi-loop-atomic-postgis-transactions)
  - [3. Territory Strength, Decay & Defense](#3-territory-strength-decay--defense)
  - [4. Explore Claim Planner with Net-New Area Deduction](#4-explore-claim-planner-with-net-new-area-deduction)
  - [5. Donut Hole Classification & Rendering](#5-donut-hole-classification--rendering)
  - [6. GPS Anomaly Detection & Spoofing Mitigation](#6-gps-anomaly-detection--spoofing-mitigation)
- [Classroom & Viva Demonstration Lab](#-classroom--viva-demonstration-lab)
- [Technology Stack](#%EF%B8%8F-technology-stack)
- [Project Directory Structure](#-project-directory-structure)
- [Getting Started & Local Development](#-getting-started--local-development)
- [Production Deployment Notes](#-production-deployment-notes)
- [Test Suite & Quality Verification](#-test-suite--quality-verification)
- [Known Limitations](#%EF%B8%8F-known-limitations)
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
- 🛡️ **Server-Authoritative Conquest:** Runs are validated and committed inside transaction-scoped PostgreSQL advisory locks to guarantee atomic, concurrent, race-free territory mutations.
- ⚡ **Offline-First Resilience:** Local Clipper2 generates instant optimistic previews. Runs queue in persistent Hive boxes and sync seamlessly with server reconciliation toasts upon reconnection.
- ⚔️ **Territory Decay & Under Attack Alerts:** Territories lose strength over time ($15\text{ pts/day}$) unless defended; weak sectors ($<30\%$ strength) yield $1.5\times$ XP bonus to rivals, who trigger instant WebSocket alerts to the victim.
- 🗺️ **Explore Claim Planner:** Suggests real-road pedestrian loops matching target area budgets ($2,000\text{ m}^2 - 50,000\text{ m}^2$) with Clipper2 net-new territory estimation.

---

## 🏗️ System Architecture

```mermaid
graph TD
    subgraph Client ["Flutter Mobile Client (Offline-First)"]
        UI[Tactical Map HUD & Leaderboard]
        ClaimPlanner[Explore Claim Planner & Net-New Area]
        LocalEngine[Clipper2 Optimistic Engine & Loop Enclosure]
        HiveQueue[(Hive Offline Sync Queue)]
        ApiClient[ApiClient with Exponential Backoff]
        HoleClassifier[Ray-Casting Hole Classifier]
        
        UI --> LocalEngine
        UI --> ClaimPlanner
        ClaimPlanner --> LocalEngine
        LocalEngine --> HiveQueue
        HiveQueue --> ApiClient
        UI --> HoleClassifier
    end

    subgraph Backend ["Go 1.22+ Server-Authoritative Backend (:8085)"]
        ChiRouter[Chi HTTP Router]
        RequestID[middleware.RequestID & Logger]
        AntiCheat[Kinematic Anomaly & Spoofing Mitigation]
        GoGeoEngine[Go Geo Enclosure Engine]
        AdvisoryLock[Transaction-Scoped Spatial Advisory Lock]
        WSHub[Real-Time WebSocket Hub]
        CoachProxy[Gemini LLM Coach Proxy]

        ChiRouter --> RequestID
        RequestID --> AntiCheat
        RequestID --> GoGeoEngine
        RequestID --> WSHub
        RequestID --> CoachProxy
        GoGeoEngine --> AdvisoryLock
    end

    subgraph Persistence ["Spatial Persistence Layer"]
        PostGIS[(PostgreSQL 16 + PostGIS)]
        GiSTIndex[GiST Spatial Index on geom]
        MemStore[(Hermetic In-Memory Dev Store)]
        
        AdvisoryLock --> PostGIS
        PostGIS --- GiSTIndex
        AdvisoryLock -.->|Local Dev Fallback| MemStore
    end

    subgraph External ["External Services"]
        OSRM[OSRM Pedestrian Graph Routing]
        Gemini[Google Gemini 1.5 Flash API]
        TileServer[ArcGIS World Dark Basemap]
    end

    ApiClient -->|HTTP REST /v1| ChiRouter
    ApiClient -->|WebSocket /v1/ws| WSHub
    ClaimPlanner -->|Pedestrian Route Query| OSRM
    CoachProxy -->|Server-Side Key Isolation| Gemini
    UI -->|Map Tiles| TileServer
```

### Architectural Highlights:
1. **Server-Authoritative Authority:** Client provides raw GPS waypoints; Go backend validates loop closure, enforces anomaly filters, and executes PostGIS `ST_Union` / `ST_Difference` transactions.
2. **Transaction-Scoped Advisory Locking:** Concurrent captures serialize via `pg_advisory_xact_lock(hashtext('territory_mutation_lock'))` without requiring an external Redis coordinator.
3. **Hermetic In-Memory Fallback:** When PostgreSQL is offline in development mode (`ENV=development`), the Go server seamlessly falls back to a thread-safe in-memory store.
4. **Zero Client Secrets:** The Google Gemini API key resides solely on the Go server (`POST /v1/runs/{id}/coach`), with zero exposure in mobile app bundles.

---

## ⚡ Key Features

- 🟢 **Arbitrary Loop Conquest:** Run organic shapes through streets or trails to claim land dynamically.
- 🪢 **Lasso Closure with Tail Retention:** Crossing an earlier path segment snaps the loop at the exact intersection point and retains the preceding path tail for subsequent captures.
- 🔁 **Multi-Candidate Proximity Search:** Scans all candidate start vertices within $35\text{ m}$ to select the best non-self-intersecting loop instead of aborting on the first crossing.
- 📦 **Multi-Loop Runs:** Complete multiple closed loops in a single continuous session; the backend unions and awards XP for all valid loops in one atomic transaction.
- 🛡️ **Territory Retention & Decay:** Captured sectors start at $100\%$ strength and decay by $15\text{ pts/day}$ without defense. Running through your land defends it; weak land ($<30\%$) grants rivals $1.5\times$ XP bonus and collapses if $<50\text{ m}^2$.
- 🚨 **Real-Time Attack Alerts:** WebSockets broadcast targeted `territory_under_attack` alerts to victims the moment a rival carves away their sovereign land.
- 🔴 **Live Moving Rival GPS & Glowing Breadcrumbs:** Streams nearby rival runners in real-time over WebSockets with directional heading pointers, tactical callsign pills, speed badges, and dual-stroke glowing breadcrumb wakes. Tap the live radar pill to auto-center and track rival movements.
- 🎯 **Explore Claim Planner:** Preset targets ($2\text{k}, 5\text{k}, 10\text{k}, 25\text{k}\text{ m}^2$) and slider ($1\text{k}-50\text{k}\text{ m}^2$) synthesize real OSRM road routes, calculate net-new area via Clipper2 subtraction, and project luminous solar orange path guidance.
- 🍩 **Multi-Ring Donut Hole Rendering:** Ray-casting containment depth classification populates FlutterMap `holePointsList`, rendering true transparent cutouts rather than solid fills.
- 🍞 **Reconciliation Toast & Honest Errors:** Notifies runners when server-calculated area differs from optimistic preview ($+$ or $-$), and halts retries immediately on permanent $4\text{xx}$ errors (`INVALID_LOOP`, `ANOMALY_REJECTED`).
- 🤖 **Secure Gemini AI Coach:** Generates tactical post-run debriefs via Go proxy with zero API key leakage, backed by an on-device athletic heuristic engine.

---

## 📡 REST & WebSocket API Reference

The Go server serves all endpoints on port `8085` (default). All routes except `/healthz` and dev-mode WebSocket query authentication require a Firebase ID Token (`Authorization: Bearer <token>`) or `X-Dev-User: <username>` when `AUTH_MODE=dev`.

| Method | Endpoint | Auth | Description | Status Codes |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/healthz` | None | Service liveness probe & database connectivity status | `200 OK`, `503 Service Unavailable` |
| `GET` | `/v1/ws` | Token / Dev | Full-duplex WebSocket for live runner GPS presence & attack alerts | `101 Switching Protocols`, `401 Unauthorized` |
| `GET` | `/v1/me` | Required | Current authenticated athlete profile (XP, level, total area, runs) | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/runs` | Required | Submits GPS track points with idempotency key; executes PostGIS conquest | `201 Created`, `200 OK (replay)`, `400 Bad Request`, `401`, `422 Anomaly` |
| `GET` | `/v1/runs` | Required | Retrieves recent run history for the authenticated user | `200 OK`, `401 Unauthorized` |
| `POST` | `/v1/runs/{id}/coach` | Required | Calls Google Gemini LLM proxy to generate post-run tactical debrief | `200 OK`, `401 Unauthorized`, `404 Not Found`, `429 Rate Limited` |
| `GET` | `/v1/territories` | Required | Bounding box GeoJSON query: `?bbox=minLng,minLat,maxLng,maxLat` | `200 OK`, `400 Bad Request`, `401 Unauthorized` |
| `GET` | `/v1/leaderboard` | Required | Global territory leaderboard ranked by `total_area_sqm` DESC | `200 OK`, `401 Unauthorized` |

### Key Payloads

#### `POST /v1/runs` Request:
```json
{
  "idempotency_key": "run_01j9a8b7c6d5e4f3",
  "duration_seconds": 940,
  "distance_meters": 2450.5,
  "points": [
    {"lat": 51.5074, "lng": -0.1278, "timestamp": 1729000000000, "speed": 2.8, "is_mocked": false},
    {"lat": 51.5085, "lng": -0.1265, "timestamp": 1729000010000, "speed": 3.1, "is_mocked": false}
  ]
}
```

#### `POST /v1/runs` Response:
```json
{
  "run_id": "run_9f8e7d6c-5b4a-3210-fedc-ba9876543210",
  "status": "accepted",
  "area_claimed": 14250.75,
  "loops_count": 1,
  "xp_awarded": 1425,
  "anomaly_score": 0.08,
  "anomaly_reasons": []
}
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

### 2. Multi-Loop Atomic PostGIS Transactions
When multiple loops occur within one run:
1. `ProcessTrack` collects all non-overlapping valid loops.
2. In PostgreSQL, `CaptureRunAndMutateTerritories` locks `pg_advisory_xact_lock(hashtext('territory_mutation_lock'))`.
3. For each loop, PostGIS executes:
   - `ST_Union` into the runner's sovereign `geometry(MultiPolygon, 4326)`.
   - `ST_Difference` on intersecting rival territories.
   - Updates `strength = 100.0` and `last_defended_at = NOW()`.
   - Sums net area and commits atomically.

### 3. Territory Strength, Decay & Defense
$$\text{Strength}(t) = \max\left(0, 100.0 - 15.0 \times \frac{t - t_{\text{defended}}}{86400\text{ s}}\right)$$
- Undefended territory decays at $15\text{ points/day}$.
- Running through own territory resets strength to $100\%$.
- Sectors with $\text{strength} < 30\%$ grant $1.5\times$ net XP bonus to conquering rivals.
- If a rival's capture reduces a weak sector's remaining area below $50\text{ m}^2$, the sector collapses completely.

### 4. Explore Claim Planner with Net-New Area Deduction
1. **Target Area to Perimeter Scaling:** Urban walking/running paths exhibit a street grid factor $\approx 3.8$:
   $$P_{\text{meters}} \approx 3.8 \times \sqrt{A_{\text{target}}}$$
2. **Route Generation:** OSRM Pedestrian generates real walkable road loops. If offline, the client falls back to synthetic geodesic loops.
3. **Net-New Area Calculation:** The proposed route polygon is clipped against the athlete's existing sovereign territory via **Clipper2 Boolean Difference**:
   $$\text{Area}_{\text{net}} = \text{Clipper2.difference}(\text{RoutePoly}, \text{OwnedTerritory})$$
   Telemetry HUD displays Total Estimated Area, Estimated NEW Area, Distance, and Duration.

### 5. Donut Hole Classification & Rendering
Multi-ring polygons (rings with inner holes) are classified via 2D ray-casting containment depth:
$$\text{depth}(R) = \sum_{j \neq R} \mathbf{1}_{R \subset P_j}$$
- Rings with **even depth** are exterior shells.
- Rings with **odd depth** are holes assigned to `Polygon.holePointsList`, rendering inner holes transparently instead of filling them.

### 6. GPS Anomaly Detection & Spoofing Mitigation
The telemetry evaluator operates on sliding windows without false claims of impenetrable security:
- **Instant Hard Rejections:** `isMocked == true`, speed $> 25\text{ km/h}$ ($6.94\text{ m/s}$), teleport jump $> 50\text{ m}$ in $\le 1.0\text{ s}$.
- **Kinematic Weighted Z-Scores:** Tracks acceleration variance $\sigma^2_a$, heading angular jerk, and identical-step coordinate repeats.

---

## 🎮 Classroom & Viva Demonstration Lab

| Scenario | Demonstration Trigger | Algorithmic Mechanism | Expected Result |
| :--- | :--- | :--- | :--- |
| 🎯 **Lasso Loop Capture** | Run crossing loop | Line-segment intersection snap & tail retention | Loop snaps at intersection, awards area, retains trailing path |
| 🛡️ **Territory Defense** | Run through own land | `last_defended_at` timestamp renewal | Strength resets to $100\%$, glowing shield HUD badge |
| 🗺️ **Claim Planner** | Explore Tab $\to$ Area Slider | OSRM loop + Clipper2 net-new area subtraction | Solar orange glowing route preview with net area stats |
| ⚔️ **Rival Attack Alert** | Simulate rival cut | WebSocket `territory_under_attack` broadcast | Victim receives instant amber HUD warning toast |
| 🚨 **Spoofing Mitigation** | Inject speed $>25\text{ km/h}$ | Kinematic speed ceiling rule | Permanent rejection ($422$), zero silent retries |

---

## 🛠️ Technology Stack

| Component | Technology | Version | Purpose |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter / Dart | 3.13+ / 3.0+ | Cross-platform athletic HUD & UI |
| **Backend Server** | Go | 1.22+ | High-throughput server-authoritative API |
| **HTTP Router** | Chi | v5.0.12 | Lightweight idiomatic Go router |
| **Spatial Database**| PostgreSQL + PostGIS | 16-3.4-alpine | GiST-indexed geometric storage & Boolean operations |
| **Database Driver** | pgx / v5 | v5.5.5 | High-performance PostgreSQL toolkit |
| **Geometry Client** | Clipper2 | ^0.2.1 | Integer-scaled 2D polygon Boolean operations |
| **Map Rendering** | FlutterMap | ^8.3.2 | Fast vector/raster tile rendering with hole support |
| **Offline DB** | Hive | ^2.2.3 | High-speed local binary NoSQL storage |
| **Road Routing** | OSRM Pedestrian | v5 | Open-source road network pedestrian loop routing |
| **AI Coach Proxy** | Google Gemini | 1.5 Flash | Structured tactical workout debriefs |

---

## 📂 Project Directory Structure

```text
territory_runner/
├── .github/workflows/ci.yml         # CI: flutter analyze+test, go vet+test, docker build
├── backend/                         # Go 1.22+ server-authoritative backend
│   ├── cmd/server/main.go           # Server entrypoint, graceful shutdown, slog config
│   ├── internal/
│   │   ├── anticheat/               # Kinematic anomaly detection & spoofing mitigation
│   │   ├── api/                     # Chi HTTP handlers, router, and middleware
│   │   ├── auth/                    # Firebase ID token verifier & dev auth mode
│   │   ├── coach/                   # Gemini LLM coach proxy & heuristic fallback
│   │   ├── config/                  # Environment variable configuration loader
│   │   ├── geo/                     # Loop enclosure, lasso closure & Shoelace area
│   │   ├── store/                   # PostGIS store & hermetic in-memory store
│   │   └── ws/                      # Real-time WebSocket hub & targeted attack alerts
│   ├── migrations/                  # Versioned SQL migrations (000001, 000002)
│   ├── Dockerfile                   # Multi-stage production container build
│   └── docker-compose.yml           # PostGIS 16 + Backend local composition
├── lib/                             # Flutter mobile application
│   ├── features/
│   │   ├── gameplay/                # PolygonEnclosureEngine & TerritoryService
│   │   ├── map/                     # MapScreen, MapLayers, ClaimPlannerSheet
│   │   ├── routing/                 # RouteService (OSRM + Clipper2 net area)
│   │   └── security/                # AnomalyService (kinematic validator)
│   ├── services/
│   │   ├── api_client.dart          # HTTP client with retry and error parsing
│   │   ├── sync_queue.dart          # Offline Hive queue, reconciliation toast & 4xx handling
│   │   └── websocket_service.dart   # Live presence & territory attack listener
│   └── main.dart                    # Application bootstrap & dependency injection
├── test/                            # 94 passing automated unit & widget tests
└── test_fixtures/                   # 7 shared golden JSON tracks read by Dart and Go
```

---

## 🚀 Getting Started & Local Development

### 1. Start Backend & PostGIS via Docker Compose
```bash
cd backend
docker compose up -d
```
The server will start listening on `http://localhost:8085`.

### 2. Or Run Backend Locally with In-Memory Store
If PostgreSQL is not running locally, the server automatically starts in dev mode:
```bash
cd backend
go run ./cmd/server
```

### 3. Connect Flutter Client
```bash
# Android Emulator (forward port 8085)
adb reverse tcp:8085 tcp:8085

# Launch Flutter
flutter run -d emulator-5554
```

---

## 🚢 Production Deployment Notes

Deploying the Go backend to a free-tier hosting provider (Render, Fly.io, or Railway) with managed PostgreSQL and PostGIS:

### Recommended Providers:
1. **Render.com** (Web Service + Managed PostgreSQL with PostGIS extension).
2. **Fly.io** (`fly launch` using `backend/Dockerfile` + Fly Postgres).
3. **Railway.app** (Deploy from GitHub repo + PostgreSQL database template).

### Deployment Steps (Render Example):
1. **Create Managed PostgreSQL Instance:**
   - In Render Dashboard, click **New + $\to$ PostgreSQL**.
   - Connect via `psql` and ensure PostGIS is enabled:
     ```sql
     CREATE EXTENSION IF NOT EXISTS postgis;
     ```
2. **Apply Database Migrations:**
   Run the versioned migration scripts against your connection string:
   ```bash
   psql "$DATABASE_URL" -f backend/migrations/000001_init_schema.up.sql
   psql "$DATABASE_URL" -f backend/migrations/000002_add_territory_strength.up.sql
   ```
3. **Deploy Backend Web Service:**
   - Click **New + $\to$ Web Service**, select your GitHub repository.
   - Set **Root Directory** to `backend`.
   - Set **Environment** to `Docker` (Render automatically uses `backend/Dockerfile`).
   - Configure **Environment Variables**:
     | Variable | Recommended Value | Notes |
     | :--- | :--- | :--- |
     | `ENV` | `production` | Rejects dev auth mode; requires PostGIS |
     | `PORT` | `8080` | Render maps incoming web traffic to 8080 |
     | `AUTH_MODE` | `firebase` | Verifies client Firebase ID tokens |
     | `DATABASE_URL` | `postgres://user:pass@host:5432/dbname?sslmode=require` | Provided by managed database |
     | `GEMINI_API_KEY` | `AIzaSy...` | Server-authoritative Gemini key |
4. **Health Check Probe:**
   - Configure health check path: `/healthz`.
   - The probe verifies database connectivity and returns `200 OK`.
5. **Observability & Graceful Shutdown:**
   - Logs are output as structured JSON via `log/slog` to `stdout`.
   - Each HTTP request includes `X-Request-Id` via Chi middleware.
   - On `SIGTERM` / `SIGINT`, the server gracefully drains active connections for up to 10 seconds.

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

### Measured Test Verification Metrics (Real Output):
- **Flutter Test Suite:** **100 passed** across 21 test files (0 failures, 0 skipped).
- **Flutter Analyzer:** **0 issues found** (clean static analysis).
- **Go Test Suite:** **6 Go packages passed** (`anticheat`, `api`, `coach`, `geo`, `store`, `ws`).
- **Shared Golden Parity:** **7/7 Golden fixtures** verified in both Dart and Go, agreeing within $<0.5\%$ area tolerance.

---

## ⚠️ Known Limitations

1. **GPS Anomaly Detection vs. OS-Level Spoofing:**
   - The application implements **GPS anomaly detection and spoofing mitigation**, not an uncrackable anti-cheat.
   - If an attacker runs on a rooted device with custom kernel mock-location hooks that simulate realistic acceleration and jitter, client telemetry cannot be cryptographically proven without dedicated hardware GNSS attestation chips.
2. **Offline Sync Reconciliation Delays:**
   - When playing offline, territory previews use local Clipper2 geometry.
   - If a rival captured part of that sector while the runner was offline, the server PostGIS reconciliation will carve away the contested ground once internet is restored and display an area reconciliation toast.
3. **OSRM Server Availability:**
   - The Claim Planner relies on public OSRM pedestrian routing demo endpoints. If the external OSRM service suffers downtime, the app falls back to on-device geodesic loop synthesis.

---

## 🤝 Contributing & License

Contributions are welcome! Please open an issue or pull request.
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>⚡ Territory Runner • Server-Authoritative Cyber-Athletic Conquest • Flutter + Go PostGIS 🏃‍♂️</sub>
</div>
