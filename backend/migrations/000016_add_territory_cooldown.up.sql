-- Phase C5: Add territory defense cooldown / shield timestamp
ALTER TABLE territories
ADD COLUMN IF NOT EXISTS cooldown_until TIMESTAMPTZ;
