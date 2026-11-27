-- Rollback Migration 000018

DROP INDEX IF EXISTS idx_territories_cooldown;
DROP INDEX IF EXISTS idx_runs_user_created;

ALTER TABLE runs DROP COLUMN IF EXISTS legacy;
ALTER TABLE runs DROP COLUMN IF EXISTS area_stolen;
