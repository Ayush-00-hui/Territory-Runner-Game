# Production Deployment & Infrastructure Guide

> [!IMPORTANT]
> **Status**: Documentation of production architectures and deployment procedures. No cloud resources are currently provisioned or deployed.

This guide details the production deployment architecture for the **Territory Runner** Go backend and managed PostgreSQL/PostGIS database.

---

## 1. Required Environment Variables

All configuration is loaded from environment variables (or `.env` in containerized environments). In production, missing or insecure combinations fail fast at startup (`config.Validate()`).

| Environment Variable | Production Value | Required? | Purpose |
| :--- | :--- | :---: | :--- |
| `ENV` | `production` | Default | Server environment. Defaults to `production`. Dev auth strictly requires explicit `ENV=development` AND `AUTH_MODE=dev`. |
| `PORT` | `8080` | Optional | Listening HTTP and WebSocket port (default: `8080`). |
| `AUTH_MODE` | `firebase` | Default | Authentication mode. Defaults to `firebase`. Enforces cryptographically verified RS256 Firebase ID tokens. |
| `FIREBASE_PROJECT_ID` | `<your-project-id>` | **Yes** | Matches `aud` and `iss` in Firebase JWT verification (mandatory when `AUTH_MODE=firebase`). |
| `DATABASE_URL` | `postgres://user:pass@host:5432/db?sslmode=require` | **Yes** | Connection string to PostgreSQL 15+ with PostGIS 3.4+. Must be a direct or session-mode endpoint. |
| `RUN_MIGRATIONS` | `true` | Optional | When `true`, automatically applies embedded migrations on startup guarded by PostgreSQL advisory locks. |
| `ALLOWED_ORIGINS` | `https://your-domain.com` | **Yes** | Comma-separated CORS and WebSocket origin whitelist (mandatory in production unless `ALLOW_ANY_ORIGIN=true`). |
| `METRICS_TOKEN` | `<secret-token>` | Optional | When set, `/metrics` requires `Authorization: Bearer <METRICS_TOKEN>`. Protects Prometheus metrics from unauthorized scraping. |
| `TRUSTED_PROXIES` | `127.0.0.1,10.0.0.0/8` | Optional | Comma-separated list of trusted upstream proxy CIDRs/IPs. `X-Forwarded-For` and `X-Real-IP` are only accepted when connecting peer is in this set. |
| `GEMINI_API_KEY` | `AIzaSy...` | Optional | Google AI Studio API key for AI tactical commentary. If empty, coach degrades gracefully. |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Optional | Low-latency Gemini model name. |
| `MAX_POINTS_PER_RUN` | `20000` | Optional | Maximum GPS breadcrumbs accepted per run upload (default: `20000`). |
| `MAX_RUN_DURATION_SECONDS` | `86400` | Optional | Maximum allowed duration for a single run session in seconds (default: 24 hours). |


---

## 2. Managed PostGIS Setup (Supabase / Render)

Territory Runner requires **PostgreSQL 15+** with the **PostGIS 3.4+** spatial extension (`geometry(MultiPolygon, 4326)` with spherical geodesic calculations via `::geography`).

### Provisioning on Supabase
1. Create a new Supabase project in your target region.
2. In the Supabase Dashboard, navigate to **Database > Extensions**.
3. Verify or enable the `postgis` extension (enabled by default in Supabase).
4. Retrieve the database connection credentials from **Project Settings > Database**.

### Direct vs. Pooled Connection Note (CRITICAL)

> [!WARNING]
> **Advisory Lock Requirement**: Always connect to Supabase via the **Direct Connection (Port 5432)** or **Session Mode Pooler**, NOT the Transaction Mode Pooler (Port 6543).

**Why Transaction Poolers Break Migrations and Territory Concurrency:**
- **Advisory Locks**: Automated schema migrations (`golang-migrate`) and territory territorial mutation serialization use PostgreSQL advisory locks (`pg_advisory_lock` and `pg_advisory_xact_lock`).
- **Connection Affinity**: Transaction-mode poolers (like PgBouncer or Supavisor on port 6543) assign a different backend connection to each transaction or statement. Advisory locks are bound to a physical database session; in transaction mode, the lock is acquired on one connection while subsequent statements execute on another, causing `ERROR: lock not held` or deadlocks.
- **Prepared Statements**: `pgx/v5` caches binary prepared statements on the session. Transaction poolers route queries to arbitrary physical connections that lack the prepared statement plan.

**Target URI Pattern:**
```text
# CORRECT: Direct Connection (Port 5432, Session-level affinity)
postgres://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres?sslmode=require

# INCORRECT: Transaction Pooler (Port 6543 - DO NOT USE FOR BACKEND SERVER)
postgres://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres?sslmode=require
```

---

## 3. Step-by-Step Render Deployment

1. **Connect Repository**:
   - In Render Dashboard, click **New > Web Service**.
   - Connect your GitHub repository (`Territory-Runner-Game`).
2. **Build Configuration**:
   - **Environment**: `Docker`
   - **Dockerfile Path**: `backend/Dockerfile`
   - **Docker Context**: `backend`
   - **Branch**: `main` (or release branch)
3. **Environment Variables**:
   Configure all required variables listed in Section 1:
   - `ENV=production`
   - `PORT=8080`
   - `AUTH_MODE=firebase`
   - `FIREBASE_PROJECT_ID=your-firebase-project-id`
   - `DATABASE_URL=postgres://...:5432/postgres?sslmode=require`
   - `RUN_MIGRATIONS=true`
4. **Health Check Path**:
   - Set healthcheck endpoint to `/readyz`.
5. **Deploy**:
   - Click **Create Web Service**. Render builds the statically linked Go binary using multi-stage compilation and starts the container.

---

## 4. Production Docker Compose Stack (Self-Hosted / 8 GB Host)

For dedicated servers or virtual machines (target: 8 GB RAM), use `backend/docker-compose.prod.yml`:

```bash
cd backend

# Create .env from template with production secrets
cp .env.example .env

# Set strong database password and Firebase project ID in .env:
# POSTGRES_PASSWORD=your-secure-random-password-32-chars
# FIREBASE_PROJECT_ID=your-project-id

# Start production stack
docker compose -f docker-compose.prod.yml up -d
```

### Security Architecture of `docker-compose.prod.yml`:
1. **Isolated Database**: PostGIS does NOT publish ports to the host; communication occurs strictly over the private Docker bridge network (`internal_network`).
2. **Resource Caps**: PostGIS is budgeted for 2.0 CPUs and 2048 MB RAM; Go backend is budgeted for 1.5 CPUs and 1024 MB RAM, leaving 5 GB host memory for OS, I/O caching, and system daemons.
3. **Auto-Healing**: Containers use `restart: always` with active Docker healthchecks (`/app/server healthcheck` and `pg_isready`).

---

## 5. Database Backups and Disaster Recovery

### Automated Backups (`scripts/backup_db.sh`)
The backup script creates a timestamped, compressed custom-format PostgreSQL dump:
```bash
DATABASE_URL="postgres://runner:pass@host:5432/territory_runner" ./scripts/backup_db.sh
# Output saved to: backups/territory_runner_YYYYMMDD_HHMMSS.dump
```

### Disaster Recovery / Restore (`scripts/restore_db.sh`)
Restores schema, PostGIS geometries, and table records with clean overwrite flags:
```bash
DATABASE_URL="postgres://runner:pass@host:5432/territory_runner" ./scripts/restore_db.sh backups/territory_runner_20261019_120000.dump
```

---

## 6. Pre-Flight Security Checklist

Before directing real traffic to the production cluster:

- [ ] `ENV=production` is set; verified that `AUTH_MODE=dev` triggers immediate startup exit.
- [ ] Direct database connection (Port 5432) used instead of transaction pooler.
- [ ] Database credentials not committed to version control; verified `.gitignore` excludes `.env`.
- [ ] Reverse proxy (e.g. Cloudflare / Render) enforces TLS 1.3 (`https://` and `wss://`).
- [ ] All 10 SQL migrations applied and verified via `RUN_MIGRATIONS=true`.
- [ ] Smoke test suite passes: `powershell -File scripts/smoke_test.ps1 -BaseUrl https://api.yourdomain.com`.
