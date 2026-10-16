# Production Deployment Guide: Managed PostGIS (Supabase / Neon)

This guide documents deploying the Territory Runner Go backend and PostGIS spatial database to free-tier cloud platforms.

---

## 1. Managed Database Provider Selection

Territory Runner requires **PostgreSQL 15+** with the **PostGIS 3.4+** spatial extension (`geometry(MultiPolygon, 4326)` and spherical geodesic computations via `::geography`).

| Feature | Supabase (Recommended) | Neon Postgres |
| :--- | :--- | :--- |
| **Free Tier Resources** | 500 MB storage, 2 projects, IPv4/IPv6 pooler | 0.5 GB storage, serverless compute scaling |
| **PostGIS Support** | Enabled out-of-the-box (`extensions` schema) | Available via `CREATE EXTENSION postgis;` |
| **Connection Pooling** | Built-in Supavisor (Port 5432 direct, 6543 pooled) | Built-in PgBouncer pooler (`-pooler` endpoint) |
| **Max Connections** | ~60 active connections (Free Tier) | 100 active connections |
| **Advisory Locks** | Fully supported in Session Mode / Direct Port 5432 | Supported on direct compute endpoint |

---

## 2. Critical Connection Pooling Considerations

Territory Runner executes atomic spatial mutations with transaction-scoped serialization:
```sql
SELECT pg_advisory_xact_lock(hashtext('territory_mutation_lock'));
```

### The Pitfall: Transaction Mode vs Session Mode
- **Transaction Mode Poolers (PgBouncer default / Supavisor Transaction mode on port 6543)** assign a different backend database connection to each transaction or statement. This breaks:
  1. `pgx` prepared statement caches (`conn.Prepare` / binary query plans).
  2. Transaction-scoped advisory locks if connections bounce prematurely.
  3. Client-side state resets across rapid multi-step queries.
- **The Solution:**
  - Connect via **Session Mode** or the **Direct Connection** (Port `5432`), **NOT** Transaction Pooler Mode.
  - In Supabase: Use the URI labeled **"Direct Connection"** (e.g., `postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres?sslmode=require`) or disable statement caching with `default_query_exec_mode=simple_protocol` if forced to use a transaction pooler.
  - In Neon: Connect to the primary compute endpoint (e.g., `ep-xyz.us-east-2.aws.neon.tech`), avoiding the `-pooler` suffix for the spatial engine.

### Connection Pool Configuration in Go (`pgxpool`)
To stay well within free-tier connection limits while maintaining concurrency:
```go
// Add pool tuning parameters to DATABASE_URL:
// "postgres://user:pass@host:5432/db?sslmode=require&pool_max_conns=20&pool_min_conns=2&pool_max_conn_idle_time=5m"
```

---

## 3. Applying Database Migrations

Migrations are stored under `backend/migrations/`:
- `000001_init_schema.up.sql`: Initial PostGIS extension, `users`, `territories`, `runs`, and GiST spatial indices.
- `000002_add_territory_strength.up.sql`: Territory decay fortifications (`strength`, `last_defended_at`).

### Option A: Via `golang-migrate` CLI (Automated CI/CD)
```bash
# Install migrate tool
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Run migrations against production database
migrate -path backend/migrations -database "$DATABASE_URL" up
```

### Option B: Via Direct SQL Console (Supabase SQL Editor / Neon Dashboard)
Execute the files sequentially in the dashboard SQL editor:
1. Run `backend/migrations/000001_init_schema.up.sql`
2. Run `backend/migrations/000002_add_territory_strength.up.sql`

Both migration scripts use `IF NOT EXISTS` guards and idempotent constraints, ensuring zero downtime and safe re-application.

---

## 4. Required Environment Variables

When deploying the backend container (e.g. to **Render**, **Fly.io**, **Railway**, or **Google Cloud Run**), configure the following environment variables:

| Variable | Recommended Value | Purpose |
| :--- | :--- | :--- |
| `ENV` | `production` | Enables production security defaults. |
| `PORT` | `8085` (or host assigned `$PORT`) | Listening HTTP / WebSocket port. |
| `DATABASE_URL` | `postgres://user:pass@host:5432/db?sslmode=require` | Connection string to managed PostGIS. |
| `AUTH_MODE` | `firebase` | Enforces RS256 JWT signature verification. |
| `FIREBASE_PROJECT_ID` | `territory-runner-app` | Matches `aud` and `iss` in Firebase JWTs. |
| `ALLOWED_ORIGINS` | `https://your-domain.com` (or empty for mobile-only) | CORS and WebSocket Origin validation. |
| `GEMINI_API_KEY` | `AIzaSy...` | Google AI Studio key for coach insights. |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Gemini model for low-latency commentary. |
| `MAX_POINTS_PER_RUN` | `20000` | Anti-DoS cap on submitted GPS track points. |
| `MAX_RUN_DURATION_SECONDS` | `86400` | Maximum 24-hour run window. |
| `RUNS_RATE_LIMIT` | `10` | 10 run uploads per minute per runner. |
| `COACH_RATE_LIMIT` | `20` | 20 coach invocations per minute. |

---

## 5. Docker Deployment Example (Fly.io / Render)

### Building and Deploying Docker Image
```bash
# Build production container
docker build -t territory-runner-backend:latest ./backend

# Fly.io launch
fly launch --dockerfile backend/Dockerfile

# Set production secrets
fly secrets set \
  DATABASE_URL="postgres://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres?sslmode=require" \
  AUTH_MODE="firebase" \
  FIREBASE_PROJECT_ID="territory-runner-app" \
  GEMINI_API_KEY="AIzaSy..."
```

---

## 6. Verification Checklist

After deployment, verify system health:
1. **Liveness & Readiness**:
   ```bash
   curl -I https://api.yourdomain.com/v1/territories?bbox=-0.13,51.49,-0.11,51.51
   # Returns 200 OK with GeoJSON FeatureCollection
   ```
2. **PostGIS Extensions**:
   ```sql
   SELECT PostGIS_Full_Version();
   -- Confirms GEOS, PROJ, and GDAL spatial libraries are loaded
   ```
3. **Advisory Lock Concurrency**:
   Confirmed via Phase 3 integration test suite:
   ```bash
   cd backend && make test-integration
   ```
