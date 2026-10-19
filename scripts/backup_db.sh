#!/usr/bin/env bash
# ==============================================================================
# Territory Runner: Database Backup Script
# Creates a compressed, custom-format PostgreSQL/PostGIS dump.
#
# Usage:
#   DATABASE_URL="postgres://runner:pass@host:5432/db" ./scripts/backup_db.sh [output_path]
# ==============================================================================

set -euo pipefail

DB_URL="${DATABASE_URL:-${1:-}}"

if [ -z "$DB_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable or first argument must be provided." >&2
    echo "Usage: DATABASE_URL=\"postgres://user:pass@host:5432/db\" $0 [output_path]" >&2
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"

OUTPUT_FILE="${2:-${1:-$BACKUP_DIR/territory_runner_$TIMESTAMP.dump}}"

echo "==> Backing up Territory Runner database..."
echo "==> Destination: $OUTPUT_FILE"

# pg_dump with custom compressed archive format (-Fc), preserving PostGIS geometries and schemas
pg_dump \
    --dbname="$DB_URL" \
    --format=custom \
    --compress=9 \
    --verbose \
    --file="$OUTPUT_FILE"

FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo "==> Backup completed successfully: $OUTPUT_FILE ($FILE_SIZE)"
