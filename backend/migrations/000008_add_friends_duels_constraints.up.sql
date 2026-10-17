-- Migration 000008: Add anti-abuse constraints and indices for friendships and duels

-- 1. Prevent self-friending
ALTER TABLE friendships
    ADD CONSTRAINT chk_friendships_no_self CHECK (requester_id != addressee_id);

-- 2. Prevent self-dueling
ALTER TABLE duels
    ADD CONSTRAINT chk_duels_no_self CHECK (challenger_id != opponent_id);

-- 3. Enforce valid XP stakes (0 to 2000 XP)
ALTER TABLE duels
    ADD CONSTRAINT chk_duels_xp_stake CHECK (xp_stake >= 0 AND xp_stake <= 2000);

-- 4. Enforce positive duel targets
ALTER TABLE duels
    ADD CONSTRAINT chk_duels_target_value CHECK (target_value > 0);

-- 5. Prevent duplicate pending/accepted friendships between the same two runners regardless of direction
CREATE UNIQUE INDEX IF NOT EXISTS uq_friendships_canonical
    ON friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id))
    WHERE status IN ('pending', 'accepted');

-- 6. Enforce at most ONE active or pending duel between any two runners
CREATE UNIQUE INDEX IF NOT EXISTS uq_duels_active_pair
    ON duels (LEAST(challenger_id, opponent_id), GREATEST(challenger_id, opponent_id))
    WHERE status IN ('pending', 'active');
