-- Add step_count column to runs (nullable, backward compatible)
ALTER TABLE runs ADD COLUMN IF NOT EXISTS step_count INT;

