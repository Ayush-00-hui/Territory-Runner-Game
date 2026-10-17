-- Migration 000004: Index users.faction for optimized real-time turf war aggregation
CREATE INDEX IF NOT EXISTS idx_users_faction ON users (faction);
