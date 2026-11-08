-- Migration 000014: Add seasons, season_standings, crews, crew_memberships, and crew_goals

CREATE TABLE IF NOT EXISTS seasons (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_seasons_dates ON seasons(starts_at, ends_at);

CREATE TABLE IF NOT EXISTS season_standings (
    id BIGSERIAL PRIMARY KEY,
    season_id VARCHAR(64) NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    faction VARCHAR(64) NOT NULL DEFAULT '',
    total_area_sqm DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    total_distance_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    xp INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_season_user UNIQUE(season_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_season_standings_area ON season_standings(season_id, total_area_sqm DESC);
CREATE INDEX IF NOT EXISTS idx_season_standings_faction ON season_standings(season_id, faction);

CREATE TABLE IF NOT EXISTS crews (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    join_code VARCHAR(16) NOT NULL UNIQUE,
    creator_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crews_join_code ON crews(join_code);

CREATE TABLE IF NOT EXISTS crew_memberships (
    id BIGSERIAL PRIMARY KEY,
    crew_id VARCHAR(64) NOT NULL REFERENCES crews(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_crew_member_user UNIQUE(user_id),
    CONSTRAINT uq_crew_membership UNIQUE(crew_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_crew_memberships_crew ON crew_memberships(crew_id);

CREATE TABLE IF NOT EXISTS crew_goals (
    id VARCHAR(64) PRIMARY KEY,
    crew_id VARCHAR(64) NOT NULL REFERENCES crews(id) ON DELETE CASCADE,
    goal_type VARCHAR(32) NOT NULL,
    target_value DOUBLE PRECISION NOT NULL,
    week_start TIMESTAMPTZ NOT NULL,
    created_by VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_crew_week_goal UNIQUE(crew_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_crew_goals_week ON crew_goals(crew_id, week_start);
