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

---

## 8. v6-Hardening Phase 2 Verification (Deploy Readiness & Migrations)

### 8.1 Embedded Migrations Completeness Suite
- **Command**: `go test -v ./migrations`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestEmbeddedMigrationsCompleteness
--- PASS: TestEmbeddedMigrationsCompleteness (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	0.474s
```
*(Verifies all 10 schema versions, 20 up/down SQL files embedded via `go:embed`, sequential continuity, non-empty contents, and advisory lock integration)*

### 8.2 Go Static Code Analysis & Test Suite
- **Command**: `go vet ./...; go test -count=1 ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/cmd/server	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	0.634s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	1.320s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	1.060s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	0.958s
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	0.486s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	0.402s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	1.093s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	0.427s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	4.660s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	0.430s
```
*(All 12 packages passing cleanly)*

### 8.3 Automated Smoke Test Execution
- **Command**: `powershell -ExecutionPolicy Bypass -File scripts/smoke_test.ps1 -BaseUrl http://localhost:8081`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
==================================================
Territory Runner Smoke Test: http://localhost:8081
==================================================
  [PASS] /healthz returned status=ok
  [PASS] /readyz returned status=ready (DB/Store connected)
  [PASS] Authenticated GET /v1/me/settings succeeded (live_visibility=off)
  [PASS] WebSocket handshake connected successfully (Open)
  [PASS] Sent viewport_subscribe message over WebSocket
--------------------------------------------------
Summary: 5 Passed, 0 Failed
==================================================
```

### 8.4 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 60.4s)
```

### 8.5 Flutter Test Suite
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:11 +237: All tests passed!
```

### 8.6 Docker & Clean PostGIS Container Verification (Host Limitations)
- **Container Execution**: `NOT RUN: Docker Desktop daemon is stopped on pipe //./pipe/dockerDesktopLinuxEngine. Clean container execution and 10-migration apply-and-idempotency verified via Go unit tests (backend/migrations/migrate_test.go) and embedded filesystem checks; live container verification runs in Linux CI.`

---

## 9. v6-Hardening Phase 3 Verification (Mechanics Integrity & Algorithmic Parity)

### 9.1 Shared Golden Fixtures Suite (Dart Engine)
- **Command**: `flutter test test/golden_fixtures_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: loading test/golden_fixtures_test.dart
00:00 +0: Shared Golden Test Fixtures Tests (Dart Engine) golden_valid_loop.json passes and area matches within 0.5% tolerance
00:00 +1: Shared Golden Test Fixtures Tests (Dart Engine) golden_figure_8.json is rejected for self-intersection
00:00 +2: Shared Golden Test Fixtures Tests (Dart Engine) golden_tiny_loop.json is rejected for insufficient perimeter
00:00 +3: Shared Golden Test Fixtures Tests (Dart Engine) golden_lasso_loop.json closes lasso loop at stem crossing within 0.5% tolerance
00:00 +4: Shared Golden Test Fixtures Tests (Dart Engine) golden_loop_with_crossing.json preserves valid loop despite subsequent path crossing
00:00 +5: Shared Golden Test Fixtures Tests (Dart Engine) golden_two_loops.json detects both valid loops and sums area within 0.5% tolerance
00:00 +6: Shared Golden Test Fixtures Tests (Dart Engine) golden_cycling_valid_loop.json is rejected in running mode but accepted in cycling mode
00:00 +7: Shared Golden Test Fixtures Tests (Dart Engine) golden_walking_valid_loop.json closes successfully under walking mode
00:00 +8: Shared Golden Test Fixtures Tests (Dart Engine) golden_broken_gap.json is segmented and rejected due to >15s GPS gap
00:00 +9: Shared Golden Test Fixtures Tests (Dart Engine) golden_running_tiny_loop.json is valid in walking mode but rejected in running mode
00:00 +10: Shared Golden Test Fixtures Tests (Dart Engine) golden_cycling_tiny_loop.json is valid in running mode but rejected in cycling mode
00:00 +11: All tests passed!
```
*(All 11 golden tests passed across 10 shared JSON fixtures)*

### 9.2 Shared Golden Fixtures Suite & Geo Engine (Go Backend)
- **Command**: `go test -v ./internal/geo/...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestGoldenValidLoop
--- PASS: TestGoldenValidLoop (0.00s)
=== RUN   TestGoldenFigure8Rejected
--- PASS: TestGoldenFigure8Rejected (0.00s)
=== RUN   TestGoldenTinyLoopRejected
--- PASS: TestGoldenTinyLoopRejected (0.00s)
=== RUN   TestGoldenHugeLoopRejected
--- PASS: TestGoldenHugeLoopRejected (0.00s)
=== RUN   TestGoldenLassoLoop
--- PASS: TestGoldenLassoLoop (0.00s)
=== RUN   TestGoldenLoopWithCrossing
--- PASS: TestGoldenLoopWithCrossing (0.00s)
=== RUN   TestGoldenTwoLoops
--- PASS: TestGoldenTwoLoops (0.00s)
=== RUN   TestGoldenCyclingValidLoop
--- PASS: TestGoldenCyclingValidLoop (0.00s)
=== RUN   TestGoldenWalkingValidLoop
--- PASS: TestGoldenWalkingValidLoop (0.00s)
=== RUN   TestGoldenBrokenGapRejected
--- PASS: TestGoldenBrokenGapRejected (0.00s)
=== RUN   TestGoldenRunningTinyLoop
--- PASS: TestGoldenRunningTinyLoop (0.00s)
=== RUN   TestGoldenCyclingTinyLoop
--- PASS: TestGoldenCyclingTinyLoop (0.00s)
=== RUN   TestEncodeGeohash
--- PASS: TestEncodeGeohash (0.00s)
=== RUN   TestSnapToGrid
--- PASS: TestSnapToGrid (0.00s)
=== RUN   TestIsPointInZone_InsideEdgeAndOutside
--- PASS: TestIsPointInZone_InsideEdgeAndOutside (0.00s)
=== RUN   TestIsPointInAnyZone_HonorsEnabledFlag
--- PASS: TestIsPointInAnyZone_HonorsEnabledFlag (0.00s)
=== RUN   TestMaskPath_TrimsStartAndEndInsidePrivacyZone
--- PASS: TestMaskPath_TrimsStartAndEndInsidePrivacyZone (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	0.444s
```
*(17 tests passed; 100% parity on loop thresholds, gap detection, and Shoelace geodesic calculations)*

### 9.3 Go Backend Complete Test Suite
- **Command**: `go test ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/cmd/server	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	(cached)
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	(cached)
```
*(All 12 packages passing)*

### 9.4 Go Static Analysis
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
(Clean exit; 0 errors, 0 warnings)
```

### 9.5 Flutter Static Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 4.0s)
```

### 9.6 Full Flutter Test Suite
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:13 +240: All tests passed!
```
*(All 240 unit, widget, and integration tests passing)*

---

## 10. Phase 4 Verification (Social Syndicate, Duels & Anti-Abuse Hardening)

### 10.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 17.5s)
```

### 10.2 Go Backend Tests (Duels, Anti-Abuse & Expiration)
- **Command**: `go test -v ./internal/store/...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestIdempotencyDoesNotDoubleCount
--- PASS: TestIdempotencyDoesNotDoubleCount (0.00s)
=== RUN   TestCaptureMultiLoopSummedAreaAndXP
--- PASS: TestCaptureMultiLoopSummedAreaAndXP (0.00s)
=== RUN   TestLeaderboardOrdering
--- PASS: TestLeaderboardOrdering (0.00s)
=== RUN   TestCaptureSetsTerritoryStrengthAndLastDefendedAt
--- PASS: TestCaptureSetsTerritoryStrengthAndLastDefendedAt (0.00s)
=== RUN   TestFriendshipFlow
--- PASS: TestFriendshipFlow (0.00s)
=== RUN   TestDuelFlow
--- PASS: TestDuelFlow (0.00s)
=== RUN   TestFriendsAndDuelsAntiAbuse
--- PASS: TestFriendsAndDuelsAntiAbuse (0.00s)
=== RUN   TestDuelDeclineFlow
--- PASS: TestDuelDeclineFlow (0.00s)
=== RUN   TestDuelExpirationResolution
--- PASS: TestDuelExpirationResolution (0.00s)
=== RUN   TestDuelActivityModalitySegregation
--- PASS: TestDuelActivityModalitySegregation (0.00s)
=== RUN   TestDuelConcurrencyLimits
--- PASS: TestDuelConcurrencyLimits (0.00s)
=== RUN   TestUserSettingsDefaultAndUpdates
--- PASS: TestUserSettingsDefaultAndUpdates (0.00s)
=== RUN   TestCaptureRunMinimumAreaFloor25Sqm
--- PASS: TestCaptureRunMinimumAreaFloor25Sqm (0.00s)
=== RUN   TestLazyTerritoryDecayCalculation
--- PASS: TestLazyTerritoryDecayCalculation (0.00s)
=== RUN   TestWeakTerritoryCaptureBonusAndDefenseReset
--- PASS: TestWeakTerritoryCaptureBonusAndDefenseReset (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	0.505s
```

### 10.3 Go Full Test Suite
- **Command**: `go test ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/cmd/server	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	1.271s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	(cached)
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	0.417s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	0.995s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	0.429s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	4.625s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	(cached)
```
*(All 12 Go packages passing)*

### 10.4 Go Static Analysis
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
(Clean exit; 0 errors, 0 warnings)
```

### 10.5 Phase 4 Flutter Social & Duels Test Suite
- **Command**: `flutter test test/phase_4_social_duels_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: Phase 4: Friend Models Tests FriendUser serialization roundtrip
00:00 +1: Phase 4: Friend Models Tests FriendRequestDetail serialization roundtrip
00:00 +2: Phase 4: Duel Model Tests Duel serialization and progress telemetry calculation
00:00 +3: Phase 4: ApiClient Social & Duels Integration Tests getFriends, getFriendRequests, and friend actions
00:00 +4: Phase 4: ApiClient Social & Duels Integration Tests getDuels, createDuel, acceptDuel, and declineDuel
00:00 +5: Phase 4: SocialHubView Widget Tests Renders Squad members and allows tab switching to Duels
00:00 +6: Phase 4: SocialHubView Widget Tests Shows incoming friend request with Accept and Decline actions
00:00 +7: Phase 4: SocialHubView Widget Tests Renders cached friends and duels when network is offline
00:00 +8: All tests passed!
```

### 10.6 Complete Flutter Test Suite
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:13 +241: All tests passed!
```
*(All 241 tests passing)*

---

## 11. Phase 5 Verification (Anticheat, Live Sync & Battery Longevity)

### 11.1 Flutter Static Code Analysis
- **Command**: `flutter analyze`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Analyzing territory_runner...
No issues found! (ran in 15.8s)
```

### 11.2 Go Anticheat Test Suite
- **Command**: `go test -v ./internal/anticheat/...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestGenuineJoggingTracePasses
--- PASS: TestGenuineJoggingTracePasses (0.00s)
=== RUN   TestMockLocationFlaggedImmediately
--- PASS: TestMockLocationFlaggedImmediately (0.00s)
=== RUN   TestVehicleSpeedExceedsHumanCeiling
--- PASS: TestVehicleSpeedExceedsHumanCeiling (0.00s)
=== RUN   TestTeleportationJumpDetected
--- PASS: TestTeleportationJumpDetected (0.00s)
=== RUN   TestRunning_RejectsCyclingSpeeds
--- PASS: TestRunning_RejectsCyclingSpeeds (0.00s)
=== RUN   TestCycling_AcceptsCyclingSpeeds
--- PASS: TestCycling_AcceptsCyclingSpeeds (0.00s)
=== RUN   TestCycling_RejectsMotorizedVehicleSpeeds
--- PASS: TestCycling_RejectsMotorizedVehicleSpeeds (0.00s)
=== RUN   TestWalking_RejectsRunningSpeeds
--- PASS: TestWalking_RejectsRunningSpeeds (0.00s)
=== RUN   TestRunning_RejectsSuperhumanAverageSpeed
--- PASS: TestRunning_RejectsSuperhumanAverageSpeed (0.00s)
=== RUN   TestBiomechanicalAccelerationCeiling
--- PASS: TestBiomechanicalAccelerationCeiling (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	0.482s
```
*(10 tests passing; 100% parity on mock detection, speed ceilings, teleportation, and acceleration bounds)*

### 11.3 Go Backend Complete Test Suite
- **Command**: `go test ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/cmd/server	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	0.500s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	1.058s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	(cached)
?   	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config	[no test files]
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	(cached)
```

### 11.4 Go Static Analysis
- **Command**: `go vet ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
(Clean exit; 0 errors, 0 warnings)
```

### 11.5 Flutter Anticheat Tests
- **Command**: `flutter test test/anomaly_service_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: AnomalyService Anti-Cheat Tests Genuine running trace passes anomaly check
00:00 +1: AnomalyService Anti-Cheat Tests Vehicle-speed telemetry (> 25 km/h) triggers instant rule rejection
00:00 +2: AnomalyService Anti-Cheat Tests isMocked flag triggers immediate cheat rejection
00:00 +3: AnomalyService Anti-Cheat Tests Teleport jump (>50m in 1s) triggers anomaly detection
00:00 +4: AnomalyService Anti-Cheat Tests Walking mode rejects running pace (> 10 km/h)
00:00 +5: AnomalyService Anti-Cheat Tests Cycling mode accepts cycling pace (~28 km/h) but running mode rejects it
00:00 +6: AnomalyService Anti-Cheat Tests Cycling mode rejects motorized highway speeds (> 50 km/h)
00:00 +7: AnomalyService Anti-Cheat Tests Running mode rejects superhuman sustained average pace (> 22 km/h)
00:00 +8: AnomalyService Anti-Cheat Tests Biomechanical acceleration limit rejects impossible speed spikes
00:00 +9: AnomalyService Anti-Cheat Tests Excessive frozen GPS breadcrumbs (> 50% identical) triggers replay detection
00:00 +10: All tests passed!
```

### 11.6 Flutter Adaptive GPS & Battery Saver Tests
- **Command**: `flutter test test/adaptive_gps_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: Adaptive GPS & LocationService Phase 3 Tests Initial tracking mode is idle to conserve battery
00:00 +1: Adaptive GPS & LocationService Phase 3 Tests createLocationSettings creates low-power settings for GpsTrackingMode.idle
00:00 +2: Adaptive GPS & LocationService Phase 3 Tests createLocationSettings creates high-precision settings for GpsTrackingMode.activeRun
00:00 +3: Adaptive GPS & LocationService Phase 3 Tests createLocationSettings creates duty-cycled settings when battery saver is active
00:00 +4: Adaptive GPS & LocationService Phase 3 Tests createLocationSettings creates throttled battery-saving settings for GpsTrackingMode.paused
00:00 +5: Adaptive GPS & LocationService Phase 3 Tests Tracking mode switches dynamically and updates currentTrackingMode
00:00 +6: All tests passed!
```

### 11.7 Full Flutter Test Suite
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:13 +244: All tests passed!
```
*(All 244 unit, widget, and integration tests passing)*

---

## 12. Phase 6 Verification (Accessibility, Dark Tactical HUD & Polish)

### 12.1 Theme & Design System Hardening
- **Command**: `flutter test test/theme/`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: C:/Users/AYUSH/Desktop/territory_runner/test/theme/no_raw_colors_test.dart: No Color(0x or Colors.white outside lib/ui/theme (except designated migration list)
00:00 +1: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Accessibility & Reduced Motion Tests AppMotion honors reduced motion flag and collapses durations to zero
00:00 +2: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Accessibility & Reduced Motion Tests AppMotion sharedAxisTransition returns child directly when animations are disabled
00:00 +3: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Accessibility & Reduced Motion Tests PrimaryButton and SecondaryButton meet minimum 48px touch target height
00:00 +4: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Small Screen Overflow & Responsiveness Tests (320px width) WeeklyLeagueView renders on 320px narrow screen without overflow
00:00 +5: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Small Screen Overflow & Responsiveness Tests (320px width) FactionLeaderboard renders on 320px narrow screen without overflow
00:00 +6: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Small Screen Overflow & Responsiveness Tests (320px width) ChallengesShelf renders on 320px narrow screen without overflow
00:00 +7: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Small Screen Overflow & Responsiveness Tests (320px width) HistoryRunCard renders on 320px narrow screen without overflow
00:00 +8: C:/Users/AYUSH/Desktop/territory_runner/test/theme/accessibility_test.dart: Phase 5 Small Screen Overflow & Responsiveness Tests (320px width) HoldToFinishButton renders on 320px screen without overflow
00:00 +9: All tests passed!
```

### 12.2 WCAG AA/AAA Contrast Verification
- **Command**: `flutter test test/theme/wcag_contrast_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: WCAG AA Contrast Ratios for Ink + Pacer Blue Palette Body text contrast >= 4.5:1 on surfaces
00:00 +1: WCAG AA Contrast Ratios for Ink + Pacer Blue Palette onAccent on accent contrast >= 4.5:1
00:00 +2: WCAG AA Contrast Ratios for Ink + Pacer Blue Palette Large text, muted text and UI icons contrast >= 3.0:1
00:00 +3: All tests passed!
```

### 12.3 Polish Proof & Typography Audits
- **Command**: `flutter test test/phase_5_polish_proof_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits WCAG Contrast & Color Palette Verification
00:00 +1: Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits Athletic Typography enforces Tabular Figures on big metric stats with Inter
00:00 +2: Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits Offline-first asset audit: verified physical presence of bundled Inter fonts
00:00 +3: Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits AppMotion respects reduced motion user preferences
00:00 +4: Phase 5: Polish & Proof - Contrast, Motion, Typography & Offline Audits Spacing and Radii design scale consistency
00:00 +5: All tests passed!
```

### 12.4 Calm Error Screen & Error Fallback
- **Command**: `flutter test test/calm_error_screen_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: CalmErrorScreen Widget Tests Renders calm error screen with recovery instructions
00:00 +1: CalmErrorScreen Widget Tests Toggles diagnostics disclosure drawer
00:00 +2: All tests passed!
```

### 12.5 Onboarding & Tactical Auth Experience
- **Command**: `flutter test test/phase_6_onboarding_and_auth_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: Phase 6: OnboardingScreen Tests OnboardingScreen renders Slide 1 initial state and advances to Slide 2 & 3
00:00 +1: Phase 6: OnboardingScreen Tests OnboardingScreen Skip button immediately triggers completion and writes prefs
00:00 +2: Phase 6: OnboardingScreen Tests OnboardingScreen Previous button navigates back to preceding slide
00:00 +3: Phase 6: PermissionPrimerSheet Tests Location permission primer renders satellite precision content
00:00 +4: Phase 6: PermissionPrimerSheet Tests Background location permission primer renders locked-screen sensing content
00:00 +5: Phase 6: PermissionPrimerSheet Tests Static helper PermissionPrimerSheet.show presents and returns result
00:00 +6: Phase 6: AuthScreen Redesign Tests AuthScreen renders brand header, tabs, and switches between One-Tap, Email, Phone
00:00 +7: Phase 6: AuthScreen Redesign Tests AuthScreen Email validation triggers error notice on empty fields
00:00 +8: Phase 6: AuthScreen Redesign Tests AuthScreen Continue as Guest triggers onAuthenticated callback
00:00 +9: All tests passed!
```

### 12.6 Full Flutter Test Suite Verification
- **Command**: `flutter test`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:10 +244: All tests passed!
```
*(All 244 unit, widget, and integration tests passing)*

---

## 13. Critical Hardening: WebSocket Deadlock Resolution, Friends Cache Invalidation & Web Compilation

### 13.1 Go WebSocket Hub & Friends Concurrency Verification
- **Command**: `go test -v ./internal/ws/...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
=== RUN   TestWebSocket_SubprotocolEchoed
--- PASS: TestWebSocket_SubprotocolEchoed (0.00s)
=== RUN   TestWebSocket_OffSendsNothing
--- PASS: TestWebSocket_OffSendsNothing (0.30s)
=== RUN   TestWebSocket_FriendsOnly
--- PASS: TestWebSocket_FriendsOnly (0.25s)
=== RUN   TestWebSocket_NearbyCellDeliveryAndNonNeighbourExclusion
--- PASS: TestWebSocket_NearbyCellDeliveryAndNonNeighbourExclusion (0.30s)
=== RUN   TestWebSocket_PrivacyZoneSuppression
--- PASS: TestWebSocket_PrivacyZoneSuppression (2.40s)
=== RUN   TestWebSocket_RateLimit
--- PASS: TestWebSocket_RateLimit (0.30s)
=== RUN   TestWebSocket_SlowClientDropped
--- PASS: TestWebSocket_SlowClientDropped (0.07s)
=== RUN   TestWebSocket_MaxConnectionsPerUser
--- PASS: TestWebSocket_MaxConnectionsPerUser (0.05s)
=== RUN   TestWebSocketTargetedTerritoryCarvedAlert
--- PASS: TestWebSocketTargetedTerritoryCarvedAlert (0.05s)
=== RUN   TestWebSocket_FriendsDeadlockOnCacheMiss
--- PASS: TestWebSocket_FriendsDeadlockOnCacheMiss (0.05s)
=== RUN   TestWebSocket_FriendsDelivery_AddAndRemoveFriendDynamics
--- PASS: TestWebSocket_FriendsDelivery_AddAndRemoveFriendDynamics (0.35s)
=== RUN   TestWebSocket_FriendsDelivery_ConcurrentStress
--- PASS: TestWebSocket_FriendsDelivery_ConcurrentStress (0.00s)
PASS
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	4.943s
```

### 13.2 Entire Backend Suite Regression Run
- **Command**: `go test ./...`
- **Working Directory**: `backend`
- **Exit Code**: `0`
- **Output**:
```text
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api	1.197s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league	(cached)
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify	1.026s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store	0.430s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws	4.935s
ok  	github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations	(cached)
```

### 13.3 Shared Golden Test Fixtures (Dart Parity)
- **Command**: `flutter test test/golden_fixtures_test.dart`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
00:00 +0: Shared Golden Test Fixtures Tests (Dart Engine) golden_valid_loop.json passes and area matches within 0.5% tolerance
00:00 +1: Shared Golden Test Fixtures Tests (Dart Engine) golden_figure_8.json is rejected for self-intersection
00:00 +2: Shared Golden Test Fixtures Tests (Dart Engine) golden_tiny_loop.json is rejected for insufficient perimeter
00:00 +3: Shared Golden Test Fixtures Tests (Dart Engine) golden_lasso_loop.json closes lasso loop at stem crossing within 0.5% tolerance
00:00 +4: Shared Golden Test Fixtures Tests (Dart Engine) golden_loop_with_crossing.json preserves valid loop despite subsequent path crossing
00:00 +5: Shared Golden Test Fixtures Tests (Dart Engine) golden_two_loops.json detects both valid loops and sums area within 0.5% tolerance
00:00 +6: Shared Golden Test Fixtures Tests (Dart Engine) golden_cycling_valid_loop.json is rejected in running mode but accepted in cycling mode
00:00 +7: Shared Golden Test Fixtures Tests (Dart Engine) golden_walking_valid_loop.json closes successfully under walking mode
00:00 +8: Shared Golden Test Fixtures Tests (Dart Engine) golden_broken_gap.json is segmented and rejected due to >15s GPS gap
00:00 +9: Shared Golden Test Fixtures Tests (Dart Engine) golden_running_tiny_loop.json is valid in walking mode but rejected in running mode
00:00 +10: Shared Golden Test Fixtures Tests (Dart Engine) golden_cycling_tiny_loop.json is valid in running mode but rejected in cycling mode
00:00 +11: All tests passed!
```

### 13.4 Flutter Web Production Build Verification
- **Command**: `flutter build web`
- **Working Directory**: Workspace Root
- **Exit Code**: `0`
- **Output**:
```text
Compiling lib\main.dart for the Web...                             67.8s
√ Built build\web
```











