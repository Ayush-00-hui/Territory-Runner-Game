DROP INDEX IF EXISTS idx_users_username_lower;
DROP INDEX IF EXISTS idx_users_runner_code;
ALTER TABLE users DROP COLUMN IF EXISTS runner_code;

