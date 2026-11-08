-- Migration 000013: Add timezone and land_reminders to users, and decay_notifications table for deduplication
ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone VARCHAR(64) NOT NULL DEFAULT 'UTC';
ALTER TABLE users ADD COLUMN IF NOT EXISTS land_reminders BOOLEAN NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS decay_notifications (
    id BIGSERIAL PRIMARY KEY,
    owner_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    territory_id VARCHAR(128) NOT NULL REFERENCES territories(id) ON DELETE CASCADE,
    threshold INT NOT NULL, -- 50 or 30
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_decay_notifications_owner_sent ON decay_notifications(owner_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_decay_notifications_dedup ON decay_notifications(owner_id, territory_id, threshold, sent_at DESC);

