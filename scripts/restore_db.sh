#!/usr/bin/env bash
# ==============================================================================
# Territory Runner: Database Restore Script
# Restores a PostgreSQL/PostGIS dump created with backup_db.sh.
#
# Usage:
#   DATABASE_URL="postgres://runner:pass@host:5432/db" ./scripts/restore_db.sh <backup_file> [--force]
# ==============================================================================

set -euo pipefail

BACKUP_FILE="${1:-}"
FORCE_FLAG="${2:-}"
DB_URL="${DATABASE_URL:-}"

if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file argument is required." >&2
    echo "Usage: DATABASE_URL=\"...\" $0 <backup_file.dump> [--force]" >&2
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file '$BACKUP_FILE' does not exist." >&2
    exit 1
fi

if [ -z "$DB_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable must be set." >&2
    exit 1
fi

if [ "$FORCE_FLAG" != "--force" ] && [ "$FORCE_FLAG" != "-f" ]; then
    echo "WARNING: This operation will restore and overwrite data in the target database."
    echo "Target: $DB_URL"
    echo "Source: $BACKUP_FILE"
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
fi

echo "==> Restoring Territory Runner database from: $BACKUP_FILE..."

# Check if file is custom pg_dump format or plain SQL
if file "$BACKUP_FILE" 2>/dev/null | grep -q "PostgreSQL custom database dump"; then
    pg_restore \
        --dbname="$DB_URL" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        --verbose \
        "$BACKUP_FILE"
else
    # Fallback to plain SQL execution or custom restore
    pg_restore \
        --dbname="$DB_URL" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        "$BACKUP_FILE" || psql "$DB_URL" -f "$BACKUP_FILE"
fi

echo "==> Database restore completed successfully."
