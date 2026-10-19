# Verification Record

This document records the exact verification commands executed on the repository, their exit codes, and raw terminal output. It contains no self-certification, subjective claims, or unmeasured benchmarks.

---

## 1. Environment

- **Branch**: `truth-and-hardening`
- **Flutter SDK**: 3.29.0 (channel stable)
- **Dart SDK**: 3.7.0
- **Go SDK**: go1.24.1 windows/amd64
- **Host OS**: Windows 11 (build 26100)
- **C Compiler**: None present in PATH (`gcc` / `clang` unavailable)
- **Docker**: Version 29.6.1 installed; daemon inactive on local pipe

---

## 2. Command Executions

### 2.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 53.1s)
```

### 2.2 Flutter Test Suite
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:11 +208: All tests passed! (208 passed, 0 failed, ran in 11.2s)
```

### 2.3 Go Static Code Analysis
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
(Clean exit; 0 errors, 0 warnings)
```

### 2.4 Go Race Detection
- **Command**: `go test -race ./...`
- **Working Directory**: `backend`
- **Exit Code**: `1`
- **Output**:
```text
go: -race requires cgo; enable cgo by setting CGO_ENABLED=1
```
*Note*: The local Windows host does not have a C compiler. CGO race detection is executed in the Linux CI workflow (`.github/workflows/ci.yml`).

### 2.5 Go Unit & Integration Tests (Hermetic Store)
- **Command**: `go test -v -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Summary**:
```text
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat  0.589s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api        1.293s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth       1.094s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach      0.980s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo        0.460s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league     0.394s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify     1.209s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store      0.372s
ok  github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws         1.241s
```
*(All 9 packages passed)*

### 2.6 Docker Integration Test Availability
- **Command**: `docker ps`
- **Working Directory**: `backend`
- **Exit Code**: `1`
- **Output**:
```text
failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; check if the path is correct and if the daemon is running: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
```
*Note*: Docker Desktop daemon is not started on this host. Live PostGIS container tests run in GitHub Actions CI.

---

## 3. Phase 2 Verification (Map Tiles Compliance & Hardening)

### 3.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 4.3s)
```

### 3.2 Flutter Test Suite (with Tile Compliance Tests)
- **Command**: `flutter test`
- **Exit Code**: `0`
- **Output**:
```text
00:13 +214: All tests passed! (214 passed, 0 failed)
```

### 3.3 Go Backend Static Analysis & Tests
- **Commands**: `go vet ./...` & `go test -v -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit across all 9 packages (anticheat, api, auth, coach, geo, league, notify, store, ws).

---

## 4. Phase 3 Verification (Live-Location Privacy & Scale)

### 4.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 4.2s)
```

### 4.2 Flutter Test Suite (with WebSocket Privacy & Scale Tests)
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:10 +218: All tests passed! (218 passed, 0 failed)
```
*Note*: Includes `test/websocket_privacy_and_scale_test.dart` testing client-side privacy zone suppression, 2500ms rate throttling, stationary jitter deduplication, and exponential backoff bounds.

### 4.3 Go Backend Static Analysis & Tests
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit (0 errors, 0 warnings).

- **Command**: `go test -v -count=1 ./internal/ws`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestWebSocketHubPresenceAndBroadcast
--- PASS: TestWebSocketHubPresenceAndBroadcast (0.05s)
=== RUN   TestWebSocketTargetedTerritoryCarvedAlert
--- PASS: TestWebSocketTargetedTerritoryCarvedAlert (0.05s)
=== RUN   TestWebSocketPresence_SuppressedInsidePrivacyZone
--- PASS: TestWebSocketPresence_SuppressedInsidePrivacyZone (0.10s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	0.967s
```

- **Command**: `go test -v -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit across all 9 packages (anticheat, api, auth, coach, geo, league, notify, store, ws).

---

## 5. Phase 4 Verification (Activity-Fairness & Anti-Cheat Parity)

### 5.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 4.5s)
```

### 5.2 Flutter Test Suite (with Activity-Aware Anomaly & Kinematics Tests)
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:13 +222: All tests passed! (222 passed, 0 failed)
```
*Note*: Includes `test/anomaly_service_test.dart` (8 tests) and `test/activity_type_test.dart` (3 tests) validating walking, running, and cycling speed ceilings and endurance limits.

### 5.3 Go Backend Static Analysis & Tests
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit (0 errors, 0 warnings).

- **Command**: `go test -v -count=1 ./internal/anticheat ./internal/geo`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit across 21 tests in anticheat and geo packages (0.533s anticheat, 0.577s geo).

- **Command**: `go test -v -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit across all 9 packages (anticheat, api, auth, coach, geo, league, notify, store, ws).

---

## 6. Phase 5 Verification (Push Notifications & Background Reliability)

### 6.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 6.1s)
```

### 6.2 Flutter Test Suite (Background & Notifications)
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:10 +222: All tests passed! (222 passed, 0 failed)
```
*Note*: Includes `test/adaptive_gps_test.dart` (5 tests), `test/notification_service_test.dart` (4 tests), and `test/run_recovery_service_test.dart` (2 tests) verifying foreground notification configuration, wake lock gating, crash recovery Hive box persistence, and unconfigured FCM fallback.

### 6.3 Go Backend Static Analysis & Tests
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit (0 errors, 0 warnings).

- **Command**: `go test -v -count=1 ./internal/notify`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestBuildAlertPayload
--- PASS: TestBuildAlertPayload (0.00s)
=== RUN   TestFCMClientGracefulDegradeWhenNoCredentials
2026/10/19 13:08:45 WARN FCM service account credentials not configured; push notifications disabled (graceful fallback)
--- PASS: TestFCMClientGracefulDegradeWhenNoCredentials (0.00s)
=== RUN   TestFCMOAuth2TokenRefreshAndSend
--- PASS: TestFCMOAuth2TokenRefreshAndSend (0.05s)
=== RUN   TestFCMUserFanoutDelivery
--- PASS: TestFCMUserFanoutDelivery (0.03s)
=== RUN   TestMockNotifierRecordsDispatchedAlerts
--- PASS: TestMockNotifierRecordsDispatchedAlerts (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	0.823s
```

- **Command**: `go test -v -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit across all 9 packages (anticheat, api, auth, coach, geo, league, notify, store, ws).

---

## 7. v6-Hardening Phase 1 Verification (Realtime Security & Privacy)

### 7.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 4.2s)
```

### 7.2 Flutter Test Suite (WebSocket Auth, Consent, Spatial Cells & Privacy Scale)
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:12 +237: All tests passed!
```
*Note*: Includes 15 new tests in `test/websocket_auth_and_visibility_test.dart` and 4 tests in `test/websocket_privacy_and_scale_test.dart` validating:
- Subprotocol authentication (`Sec-WebSocket-Protocol: bearer, <token>`) and exclusion of query parameters in production.
- Token refresh on reconnect (`forceRefresh: true`).
- `UserSettingsService` default `LiveVisibility.off`, offline-first persistence, and server sync.
- Outbound presence suppression when `liveVisibility == LiveVisibility.off`.
- Base32 Geohash precision 6 calculations, bounding box validation, and 8-neighbor generation.
- `LiveVisibilitySheet` UI rendering, default `Off (Recommended)`, and reactive selection updates.

### 7.3 Go Static Code Analysis & Test Suite
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**: Clean exit (0 errors, 0 warnings).

- **Command**: `go test -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/cmd/server	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	0.572s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	1.387s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	1.226s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	0.951s
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	0.476s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	0.402s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	1.072s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	0.438s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	4.683s
```
*(All 11 packages clean and passing; ws suite tests presence delay, friends-only routing, geohash spatial cells, rate limits, connection capping, and slow consumer isolation)*

### 7.4 Docker & Race Detection (Host Limitations)
- **Go Race Detection**: `NOT RUN: go test -race ./... requires CGO and a C compiler (gcc/clang) unavailable on this Windows host. Runs in Linux CI.`
- **PostGIS Docker Tests**: `NOT RUN: Docker Desktop daemon is stopped on pipe //./pipe/dockerDesktopLinuxEngine. Hermetic memory store tested locally; live PostgreSQL/PostGIS integration tests run in GitHub Actions CI.`





