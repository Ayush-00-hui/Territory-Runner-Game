DROP TABLE IF EXISTS moderation_reports;
DROP TABLE IF EXISTS hidden_posts;
DROP TABLE IF EXISTS user_blocks;
DROP TABLE IF EXISTS feed_kudos;
ALTER TABLE users DROP COLUMN IF EXISTS share_runs_with_friends;
