CREATE TABLE IF NOT EXISTS device_tokens (
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens (user_id);
