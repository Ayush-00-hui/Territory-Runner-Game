-- Migration 000018: Add area_stolen and net accounting support, indexes for capture and ranking performance

ALTER TABLE runs ADD COLUMN IF NOT EXISTS area_stolen DOUBLE PRECISION NOT NULL DEFAULT 0.0;
ALTER TABLE runs ADD COLUMN IF NOT EXISTS legacy BOOLEAN NOT NULL DEFAULT false;

-- Composite index for fast user run lookups and daily XP / activity filtering
CREATE INDEX IF NOT EXISTS idx_runs_user_created ON runs(user_id, created_at DESC);

-- Partial index for fast query of shielded rival territories
CREATE INDEX IF NOT EXISTS idx_territories_cooldown ON territories(cooldown_until) WHERE cooldown_until IS NOT NULL;
