DROP INDEX IF EXISTS idx_runs_activity_type;
ALTER TABLE runs DROP CONSTRAINT IF EXISTS chk_runs_activity_type;
ALTER TABLE runs DROP COLUMN IF EXISTS activity_type;
