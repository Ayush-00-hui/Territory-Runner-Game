-- Revert Phase 3: Drop strength and last_defended_at columns
ALTER TABLE territories
DROP COLUMN IF EXISTS strength,
DROP COLUMN IF EXISTS last_defended_at;
