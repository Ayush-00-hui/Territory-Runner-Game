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
