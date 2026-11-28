# Territory Runner — Go Backend Service

The Territory Runner backend is a high-performance, server-authoritative distributed geospatial service written in Go (using the Chi router) backed by PostgreSQL 16 + PostGIS 3.4.

---

## 🏛️ Architecture & Packages

```
backend/
├── cmd/
│   └── server/          # Application entrypoint (main.go), signal handling, graceful shutdown
├── internal/
│   ├── anticheat/       # Kinematic speed/acceleration checks & LightGBM ONNX runtime
│   ├── api/             # REST HTTP handlers, Chi router, token-bucket rate limiters, Prometheus metrics
│   ├── auth/            # RS256 Firebase JWT verification & guest runner authentication
│   ├── coach/           # AI athletic coach debrief generator powered by Google Gemini 2.5 Flash
│   ├── config/          # Environment configuration loading & validation
│   ├── geo/             # Geospatial algorithms, WGS84 geodesy, WKT/GeoJSON transformations
│   ├── league/          # Weekly competitive divisions, promotion/relegation tier calculations
│   ├── notify/          # FCM HTTP v1 push notifications & territory decay reminder engine
│   ├── store/           # Database layer: PostgreSQL+PostGIS with advisory locking, plus in-memory mock
│   └── ws/              # Real-time WebSocket hub, broadcast channels, client connection lifecycle
└── migrations/          # 18 PostGIS migration versions (000001–000018 up/down SQL files)
```

---

## ⚡ Quickstart

### 1. Run via Docker Compose (Recommended)
```bash
# Starts PostgreSQL 16 + PostGIS 3.4 and the Go API server on port 8080
docker-compose up --build
```

### 2. Run Locally with Go
```bash
# Ensure PostgreSQL is running locally
export DATABASE_URL="postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable"
export PORT="8080"

# Execute all tests with race detection
cd backend
go test -v -race ./...

# Start the server
go run cmd/server/main.go
```

---

## 🧪 Testing Verification

All 11 Go packages pass with race detection enabled:
```bash
cd backend
go test -count=1 ./...
```
