# Contributing to Territory Runner

Thank you for contributing to Territory Runner! This guide outlines the development standards, architectural invariants, and verification workflows required for all contributions.

---

## 1. Architectural Invariants

### 1.1 Dual-Engine Parity (Strict Invariant)
Territory Runner employs a dual-engine architecture:
- **Client Optimistic Engine** (`lib/features/gameplay/polygon_enclosure_engine.dart`): Real-time loop detection and polygon rendering on device during active workouts.
- **Server Authoritative Engine** (`backend/internal/geo/engine.go`): Cryptographic and spatial verification of submitted GPS tracks prior to database mutation.

**Rule**: Any modification to enclosure algorithms, minimum closure distance (35m), minimum vertices (4), maximum loop area ($5{,}000{,}000\text{ m}^2$), or activity-aware speed outlier thresholds (Walking: 15 km/h, Running: 35 km/h, Cycling: 60 km/h) **MUST be implemented simultaneously in both Dart and Go** and verified against the golden fixtures in `test_fixtures/`.

### 1.2 Isolated Telemetry & 60 FPS UI
During an active workout, GPS updates arrive at 1 Hz. Root-level `setState()` calls are strictly prohibited on active workout screens. All rapid state updates must flow through `RunTelemetryNotifier` (`ValueNotifier<RunTelemetry>`) to isolate rebuilds exclusively to numeric stat counters.

### 1.3 Unified Logging & Observability
- **Client**: Always use `AppLogger` (`AppLogger.info()`, `AppLogger.warn()`, `AppLogger.error()`). Raw `print()` or `debugPrint()` are forbidden.
- **Backend**: Use structured loggers with correlation IDs (`[User/RequestID]`).

---

## 2. Prerequisites

- **Flutter SDK**: Stable channel (Dart 3.x)
- **Go SDK**: 1.22+
- **Docker & Docker Compose**: For local PostgreSQL 16 + PostGIS 3.4 container
- **Android Studio / Xcode**: For device builds and simulators

---

## 3. Branching & Git Workflow

### 3.1 Branch Naming Convention
- `feat/<feature-name>`: New athletic or game mechanics.
- `fix/<bug-name>`: Bug fixes or spatial anomaly corrections.
- `perf/<optimization>`: Performance or frame budget improvements.
- `refactor/<target>`: Code restructuring without functional changes.
- `docs/<topic>`: Documentation updates.

### 3.2 Commit Format (Conventional Commits)
```
<type>(<scope>): <short description>

[optional body describing engineering rationale]
```
Examples:
- `feat(fairness): add cycling kinematic parameters and golden fixtures`
- `fix(gps): prevent duplicate zero-displacement point submissions`
- `perf(render): isolate telemetry counters with ValueListenableBuilder`

---

## 4. Local Development & Verification

### 4.1 Running the Backend Locally
```bash
# Start PostGIS database
cd backend
docker-compose up -d

# Run migrations and start API server
go run cmd/server/main.go
```

### 4.2 Running the Mobile App
```bash
flutter pub get
flutter run
```

### 4.3 Mandatory Pre-Commit Checklist
Before submitting a pull request, all checks must pass locally:

```bash
# 1. Flutter Static Analysis (Zero issues required)
flutter analyze

# 2. Flutter Test Suite
flutter test

# 3. Go Static Code Analysis
cd backend
go vet ./...

# 4. Go Test Suite & Race Detector
go test -count=1 ./...
```

---

## 5. Golden Fixtures & Parity Testing

When adding or altering movement dynamics, update or add test fixtures in `test_fixtures/`:
- `test_fixtures/golden_walking_valid_loop.json`: Valid 5 km/h walking path.
- `test_fixtures/golden_cycling_valid_loop.json`: Valid 42 km/h cycling loop (rejected in running mode, accepted in cycling mode).

Verify parity across both test suites:
- Dart: `flutter test test/golden_fixtures_test.dart`
- Go: `cd backend && go test -v -run TestGoldenFixtures ./internal/geo`

---

## 6. Pull Request Review Process

1. Open a PR against `industry-level` (or `main` for release tags).
2. Fill out all sections of `.github/pull_request_template.md`.
3. Ensure all automated GitHub Actions CI jobs (`flutter_quality`, `go_backend`, `docker_build`) pass green.
4. Provide a 2-3 line viva defense rationale for non-trivial decisions.
