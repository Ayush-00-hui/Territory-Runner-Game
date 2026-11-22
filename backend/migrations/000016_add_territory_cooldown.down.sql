-- Phase C5: Drop territory defense cooldown / shield timestamp
ALTER TABLE territories
DROP COLUMN IF EXISTS cooldown_until;
