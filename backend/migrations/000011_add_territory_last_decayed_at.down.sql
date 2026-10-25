-- Revert Migration 000011: Drop last_decayed_at column
ALTER TABLE territories
DROP COLUMN IF EXISTS last_decayed_at;
