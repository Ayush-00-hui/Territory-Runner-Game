-- Revert Migration 000013: Drop decay_notifications and user columns
DROP TABLE IF EXISTS decay_notifications;
ALTER TABLE users DROP COLUMN IF EXISTS land_reminders;
ALTER TABLE users DROP COLUMN IF EXISTS timezone;

