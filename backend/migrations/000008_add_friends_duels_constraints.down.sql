-- Revert Migration 000008

DROP INDEX IF EXISTS uq_duels_active_pair;
DROP INDEX IF EXISTS uq_friendships_canonical;

ALTER TABLE duels DROP CONSTRAINT IF EXISTS chk_duels_target_value;
ALTER TABLE duels DROP CONSTRAINT IF EXISTS chk_duels_xp_stake;
ALTER TABLE duels DROP CONSTRAINT IF EXISTS chk_duels_no_self;

ALTER TABLE friendships DROP CONSTRAINT IF EXISTS chk_friendships_no_self;
