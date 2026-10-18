DROP INDEX IF EXISTS idx_duels_activity_type;
ALTER TABLE duels DROP CONSTRAINT IF EXISTS chk_duels_activity_type;
ALTER TABLE duels DROP COLUMN IF EXISTS activity_type;
