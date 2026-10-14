CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(128) PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    faction VARCHAR(50) NOT NULL DEFAULT 'Cyber Vanguard',
    total_area_sqm DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    xp BIGINT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    total_runs INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS territories (
    id VARCHAR(128) PRIMARY KEY,
    owner_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    geom geometry(MultiPolygon, 4326) NOT NULL,
    area_sqm DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_territories_geom ON territories USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_territories_owner ON territories (owner_id);

CREATE TABLE IF NOT EXISTS runs (
    id VARCHAR(128) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(128) UNIQUE NOT NULL,
    duration_seconds INT NOT NULL DEFAULT 0,
    distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    area_claimed DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    anomaly_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    anomaly_reasons TEXT[] NOT NULL DEFAULT '{}',
    path geometry(LineString, 4326),
    status VARCHAR(32) NOT NULL DEFAULT 'accepted',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_runs_user_id ON runs (user_id);
CREATE INDEX IF NOT EXISTS idx_runs_created_at ON runs (created_at DESC);
