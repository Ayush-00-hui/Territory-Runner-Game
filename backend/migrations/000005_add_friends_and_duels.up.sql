CREATE TABLE IF NOT EXISTS friendships (
    id VARCHAR(128) PRIMARY KEY,
    requester_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    addressee_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_friendship_pair UNIQUE (requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships (requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships (addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON friendships (status);

CREATE TABLE IF NOT EXISTS duels (
    id VARCHAR(128) PRIMARY KEY,
    challenger_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    opponent_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type VARCHAR(32) NOT NULL DEFAULT 'area',
    target_value DOUBLE PRECISION NOT NULL DEFAULT 10000.0,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    challenger_progress DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    opponent_progress DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    winner_id VARCHAR(128) REFERENCES users(id) ON DELETE SET NULL,
    xp_stake INT NOT NULL DEFAULT 100,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_duels_challenger ON duels (challenger_id);
CREATE INDEX IF NOT EXISTS idx_duels_opponent ON duels (opponent_id);
CREATE INDEX IF NOT EXISTS idx_duels_status ON duels (status);
