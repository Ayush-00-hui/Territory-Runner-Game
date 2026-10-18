-- Add activity_type column to duels table to enforce activity-segregated athletic challenges
ALTER TABLE duels ADD COLUMN IF NOT EXISTS activity_type VARCHAR(32) NOT NULL DEFAULT 'running';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_duels_activity_type'
    ) THEN
        ALTER TABLE duels ADD CONSTRAINT chk_duels_activity_type 
            CHECK (activity_type IN ('running', 'walking', 'cycling'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_duels_activity_type ON duels (activity_type);
