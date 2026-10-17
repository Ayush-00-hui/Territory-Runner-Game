-- Add activity_type column with check constraint for running, walking, cycling
ALTER TABLE runs ADD COLUMN IF NOT EXISTS activity_type VARCHAR(32) NOT NULL DEFAULT 'running';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_runs_activity_type'
    ) THEN
        ALTER TABLE runs ADD CONSTRAINT chk_runs_activity_type 
            CHECK (activity_type IN ('running', 'walking', 'cycling'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_runs_activity_type ON runs (activity_type);
