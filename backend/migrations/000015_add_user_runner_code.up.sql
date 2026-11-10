ALTER TABLE users ADD COLUMN IF NOT EXISTS runner_code VARCHAR(24);

UPDATE users
SET runner_code = 'RUN-' || UPPER(SUBSTRING(MD5(id || COALESCE(created_at::text, '')), 1, 6))
WHERE runner_code IS NULL OR runner_code = '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_runner_code ON users (runner_code);
CREATE INDEX IF NOT EXISTS idx_users_username_lower ON users (LOWER(username));

