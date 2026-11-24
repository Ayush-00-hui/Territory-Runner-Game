-- Phase G4: Add social activity feed, reactions (kudos), and moderation tables

-- 1. Add share_runs_with_friends to users table (default FALSE for privacy-by-default)
ALTER TABLE users ADD COLUMN IF NOT EXISTS share_runs_with_friends BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Create feed_kudos table for fixed reactions (kudos, clap, fire, strong)
CREATE TABLE IF NOT EXISTS feed_kudos (
    id VARCHAR(128) PRIMARY KEY,
    run_id VARCHAR(128) NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_run_user_kudos UNIQUE (run_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_kudos_run_id ON feed_kudos (run_id);
CREATE INDEX IF NOT EXISTS idx_feed_kudos_user_id ON feed_kudos (user_id);

-- 3. Create user_blocks table for user blocking
CREATE TABLE IF NOT EXISTS user_blocks (
    id VARCHAR(128) PRIMARY KEY,
    blocker_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_block_pair UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks (blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks (blocked_id);

-- 4. Create hidden_posts table for hiding specific runs from feed
CREATE TABLE IF NOT EXISTS hidden_posts (
    id VARCHAR(128) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    run_id VARCHAR(128) NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_hidden_run UNIQUE (user_id, run_id)
);

CREATE INDEX IF NOT EXISTS idx_hidden_posts_user ON hidden_posts (user_id);

-- 5. Create moderation_reports table for reporting inappropriate content or behavior
CREATE TABLE IF NOT EXISTS moderation_reports (
    id VARCHAR(128) PRIMARY KEY,
    reporter_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    run_id VARCHAR(128) REFERENCES runs(id) ON DELETE SET NULL,
    reason VARCHAR(64) NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_moderation_reports_reporter ON moderation_reports (reporter_id);
CREATE INDEX IF NOT EXISTS idx_moderation_reports_reported ON moderation_reports (reported_user_id);
