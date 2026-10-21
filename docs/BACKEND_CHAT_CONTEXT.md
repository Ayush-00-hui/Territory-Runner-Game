# Territory Runner — Backend Chat Context & Architecture History

This document consolidates key architectural decisions, resolved issues, and development state extracted from previous conversation sessions (including `a9b6caa8-6e04-466f-8c2c-747c9d5b2094`, `609e5cda-50db-4629-bd31-5f339039e1b4`, and `da53c548-d222-4732-b848-2382d5accd9e`).

---

## 1. System Overview & Tech Stack

- **Client**: Flutter mobile app with OpenStreetMap, MapLibre/vector rendering, GPS location streaming, background sync queue, and local Hive/SQLite caching.
- **Backend**: Go (1.22+) REST API + WebSocket presence and telemetry engine.
- **Database**: PostgreSQL 16 with PostGIS extension for spatial polygon math, territory enclosures, and geospatial queries.
- **Concurrency**: Gorilla WebSocket, `golang.org/x/sync/singleflight`, sync.RWMutex, atomic counters.

---

## 2. Key Hardening & Concurrency Fixes (Branch `v6-hardening` / `v7-critical-fixes`)

### A. WebSocket Presence Deadlock Resolution ([backend/internal/ws/hub.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/ws/hub.go))
- **The Problem**: Broadcast loops held `h.mu.RLock()` while querying `store.GetFriends()`. Under high concurrency, database latency cascaded into blocking connection registrations, unregistrations, and ping handlers across all goroutines.
- **The Solution**: 
  - Decoupled connection mapping from database queries. Connections are snapshotted under a brief read-lock, and IO/DB queries execute completely outside the lock.
  - Introduced `singleflight.Group` to collapse duplicate friend-list queries into a single execution during simultaneous connection events.
  - Implemented atomic friend cache invalidation via `hub.InvalidateFriends(userA, userB)` inside [backend/internal/api/handlers.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/api/handlers.go).

### B. Socket Buffering & Channel Teardown
- Added bounded outbound channel buffers (`WithOutboundBufferSize`) to prevent slow clients from blocking broadcaster routines.
- Handled socket drops gracefully with atomic client teardown and channel drain guards, resolving race detector warnings under `go test -race ./...`.

### C. Anti-Cheat & GPS Anomaly Detection ([backend/internal/anticheat/detector.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/anticheat/detector.go))
- Telemetry points validate human running speeds (hard caps on impossible speed bursts > 12 m/s or altitude teleportation).
- Haversine and Shoelace polygon intersection validations prevent forged claim loops.

---

## 3. Important Workspace References

- WebSocket Hub: [backend/internal/ws/hub.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/ws/hub.go)
- API Handlers & Routes: [backend/internal/api/handlers.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/api/handlers.go)
- Anti-Cheat Engine: [backend/internal/anticheat/detector.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/anticheat/detector.go)
- Database Store: [backend/internal/store/postgres.go](file:///c:/Users/AYUSH/Desktop/territory_runner/backend/internal/store/postgres.go)
- Verification Docs: [docs/VERIFICATION.md](file:///c:/Users/AYUSH/Desktop/territory_runner/docs/VERIFICATION.md)
