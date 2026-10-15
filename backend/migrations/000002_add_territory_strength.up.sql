-- Phase 3: Add dynamic territory strength and last defense tracking
ALTER TABLE territories
ADD COLUMN IF NOT EXISTS strength DOUBLE PRECISION NOT NULL DEFAULT 100.0,
ADD COLUMN IF NOT EXISTS last_defended_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
