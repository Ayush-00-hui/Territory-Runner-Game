package store

import "time"

// User represents a player profile in the database.
type User struct {
	ID           string    `json:"id"`
	Username     string    `json:"username"`
	Faction      string    `json:"faction"`
	TotalAreaSqm float64   `json:"total_area_sqm"`
	XP           int64     `json:"xp"`
	Level        int       `json:"level"`
	TotalRuns    int       `json:"total_runs"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Territory represents sovereign claimed territory stored as a PostGIS MultiPolygon.
type Territory struct {
	ID             string    `json:"id"`
	OwnerID        string    `json:"owner_id"`
	Username       string    `json:"username,omitempty"`
	GeoJSON        string    `json:"geojson"`
	AreaSqm        float64   `json:"area_sqm"`
	Strength       float64   `json:"strength"`
	LastDefendedAt time.Time `json:"last_defended_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// Run records a runner's GPS session and capture result.
type Run struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	IdempotencyKey  string    `json:"idempotency_key"`
	DurationSeconds int       `json:"duration_seconds"`
	DistanceMeters  float64   `json:"distance_meters"`
	AreaClaimed     float64   `json:"area_claimed"`
	AnomalyScore    float64   `json:"anomaly_score"`
	AnomalyReasons  []string  `json:"anomaly_reasons"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
}

// CaptureResult encapsulates the output of a single transaction territory capture.
type CaptureResult struct {
	RunID               string  `json:"run_id"`
	IdempotencyKey      string  `json:"idempotency_key"`
	Status              string  `json:"status"`
	AnomalyScore        float64 `json:"anomaly_score"`
	AnomalyReasons      []string`json:"anomaly_reasons"`
	LoopDetected        bool    `json:"loop_detected"`
	AreaClaimedSqm      float64 `json:"area_claimed_sqm"`
	XpAwarded           int     `json:"xp_awarded"`
	PlayerTotalAreaSqm  float64  `json:"player_total_area_sqm"`
	TerritoryGeoJSON    string   `json:"territory_geojson,omitempty"`
	RivalsAffected      []string `json:"rivals_affected,omitempty"`
}

// LeaderboardEntry represents a ranked runner.
type LeaderboardEntry struct {
	Rank         int     `json:"rank"`
	UserID       string  `json:"user_id"`
	Username     string  `json:"username"`
	Faction      string  `json:"faction"`
	TotalAreaSqm float64 `json:"total_area_sqm"`
	Level        int     `json:"level"`
	TotalRuns    int     `json:"total_runs"`
}
