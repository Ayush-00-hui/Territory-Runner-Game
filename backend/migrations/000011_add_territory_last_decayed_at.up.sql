-- Migration 000011: Add last_decayed_at to track periodic decay independently of user defenses
ALTER TABLE territories
ADD COLUMN IF NOT EXISTS last_decayed_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
