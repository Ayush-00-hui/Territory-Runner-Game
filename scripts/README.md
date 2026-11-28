# Production & Development Automation Scripts

This directory houses automated developer operations, database maintenance, smoke testing, and ML training scripts for Territory Runner.

---

## 🛠️ Script Manifest

| Script | Runtime | Purpose |
| :--- | :--- | :--- |
| **`backup_db.sh`** | Bash / `pg_dump` | Creates compressed, timestamped PostgreSQL backups from a remote or local PostGIS instance. |
| **`restore_db.sh`** | Bash / `pg_restore` | Restores custom-format or SQL dump archives into a target PostgreSQL database with verification. |
| **`smoke_test.sh`** | Bash / `curl` / `websocat` | End-to-end smoke test validating health, auth, run submission, and WebSocket connection on Linux/macOS. |
| **`smoke_test.ps1`** | PowerShell 5.1+ / .NET | Native Windows PowerShell smoke test validating backend endpoints, bearer auth, and live WebSocket upgrade. |
| **`balance_simulation.py`** | Python 3.10+ | Simulates faction territorial conquest over 1,000 synthetic athletic runs to balance XP and decay curves. |
| **`train_anomaly_model.py`** | Python 3.10+ | Trains and evaluates the LightGBM Tier 2 anti-cheat model on kinematics and cadence datasets. |
| **`build_study_notes_pdf.py`** | Python 3.10+ | Compiles the markdown documentation suite into printable HTML and PDF study handbooks. |

---

## 🚀 Usage Examples

### 1. Database Backup & Restore
```bash
# Backup local or remote database
./scripts/backup_db.sh "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable"

# Restore database from archive
./scripts/restore_db.sh backups/territory_runner_backup_20261128.dump "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable"
```

### 2. End-to-End Backend Smoke Testing
```bash
# On Linux / macOS:
./scripts/smoke_test.sh http://localhost:8080

# On Windows PowerShell:
.\scripts\smoke_test.ps1 -BaseUrl "http://localhost:8080"
```
