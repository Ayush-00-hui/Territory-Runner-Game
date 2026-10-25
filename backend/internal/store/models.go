package store

import (
	"math"
	"time"
)

const (
	// TerritoryDefaultStrength is the base strength of freshly captured or defended land.
	TerritoryDefaultStrength = 100.0
	// TerritoryDecayPerDay is the lazy decay rate: 15.0 strength lost per 24 hours.
	TerritoryDecayPerDay = 15.0
	// TerritoryWeakThreshold is the strength floor below which territory is vulnerable and yields 1.5x XP.
	TerritoryWeakThreshold = 30.0
	// MinCaptureFloorSqm is the minimum new area floor (25 m²) required before awarding XP, league, or duel credit.
	MinCaptureFloorSqm = 25.0
)

// User represents a player profile in the database.
type User struct {
	ID             string    `json:"id"`
	Username       string    `json:"username"`
	Faction        string    `json:"faction"`
	TotalAreaSqm   float64   `json:"total_area_sqm"`
	XP             int64     `json:"xp"`
	Level          int       `json:"level"`
	TotalRuns      int       `json:"total_runs"`
	LiveVisibility string    `json:"live_visibility,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
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
	LastDecayedAt  time.Time `json:"last_decayed_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// CalculateEffectiveStrength computes real-time dynamic strength factoring in elapsed days since last defense or decay.
// Formula: max(0.0, stored_strength - 15.0 * days_since_last_reference).
func CalculateEffectiveStrength(storedStrength float64, referenceTime time.Time, now time.Time) float64 {
	if referenceTime.IsZero() {
		return math.Max(0.0, math.Min(100.0, storedStrength))
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}
	diff := now.Sub(referenceTime)
	if diff < 0 {
		return math.Max(0.0, math.Min(100.0, storedStrength))
	}
	days := diff.Hours() / 24.0
	decayed := storedStrength - (days * TerritoryDecayPerDay)
	if decayed < 0.0 {
		return 0.0
	}
	if decayed > 100.0 {
		return 100.0
	}
	return decayed
}

// EffectiveStrength returns the real-time decayed strength of the territory at the specified timestamp.
// Computes decay elapsed since last_decayed_at (falling back to last_defended_at).
func (t *Territory) EffectiveStrength(now time.Time) float64 {
	refTime := t.LastDecayedAt
	if refTime.IsZero() {
		refTime = t.LastDefendedAt
	}
	return CalculateEffectiveStrength(t.Strength, refTime, now)
}


// IsWeak returns true if dynamic strength has fallen below the weak fortification threshold (30.0).
func (t *Territory) IsWeak(now time.Time) bool {
	return t.EffectiveStrength(now) < TerritoryWeakThreshold
}

// Run records a runner's GPS session and capture result.
type Run struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	IdempotencyKey  string    `json:"idempotency_key"`
	ActivityType    string    `json:"activity_type,omitempty"`
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
	RunID              string   `json:"run_id"`
	IdempotencyKey     string   `json:"idempotency_key"`
	ActivityType       string   `json:"activity_type,omitempty"`
	Status             string   `json:"status"`
	AnomalyScore       float64  `json:"anomaly_score"`
	AnomalyReasons     []string `json:"anomaly_reasons"`
	LoopDetected       bool     `json:"loop_detected"`
	AreaClaimedSqm     float64  `json:"area_claimed_sqm"`
	XpAwarded          int      `json:"xp_awarded"`
	PlayerTotalAreaSqm float64  `json:"player_total_area_sqm"`
	TerritoryGeoJSON   string   `json:"territory_geojson,omitempty"`
	RivalsAffected     []string `json:"rivals_affected,omitempty"`
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

// WeeklyParticipant represents aggregated runner performance for the active week.
type WeeklyParticipant struct {
	UserID        string  `json:"user_id"`
	Username      string  `json:"username"`
	Faction       string  `json:"faction"`
	WeeklyAreaSqm float64 `json:"weekly_area_sqm"`
	WeeklyRuns    int     `json:"weekly_runs"`
}

// LeagueStanding encapsulates full weekly league standings, tier bracket, and promotion/relegation thresholds.
type LeagueStanding struct {
	UserID               string              `json:"user_id"`
	Username             string              `json:"username"`
	Faction              string              `json:"faction"`
	Tier                 string              `json:"tier"` // "Diamond", "Gold", "Silver", "Bronze"
	Rank                 int                 `json:"rank"`
	TotalParticipants    int                 `json:"total_participants"`
	WeeklyAreaSqm        float64             `json:"weekly_area_sqm"`
	WeeklyRuns           int                 `json:"weekly_runs"`
	PromotionRankCutoff  int                 `json:"promotion_rank_cutoff"`
	RelegationRankCutoff int                 `json:"relegation_rank_cutoff"`
	ResetAt              time.Time           `json:"reset_at"`
	SecondsUntilReset    int64               `json:"seconds_until_reset"`
	Standings            []LeagueParticipant `json:"standings"`
}

// LeagueParticipant represents an individual participant in the current weekly league table.
type LeagueParticipant struct {
	Rank          int     `json:"rank"`
	UserID        string  `json:"user_id"`
	Username      string  `json:"username"`
	Faction       string  `json:"faction"`
	Tier          string  `json:"tier"`
	WeeklyAreaSqm float64 `json:"weekly_area_sqm"`
	WeeklyRuns    int     `json:"weekly_runs"`
	IsCurrentUser bool    `json:"is_current_user"`
}

// FactionStanding represents aggregate territory dominance for an athletic faction.
type FactionStanding struct {
	Faction      string  `json:"faction"`
	TotalAreaSqm float64 `json:"total_area_sqm"`
	MemberCount  int     `json:"member_count"`
	Percentage   float64 `json:"percentage"`
}

// FactionStandingsResponse encapsulates global turf war statistics.
type FactionStandingsResponse struct {
	TotalAreaSqm float64           `json:"total_area_sqm"`
	Standings    []FactionStanding `json:"standings"`
}

// Friendship represents a friend connection between two runners.
type Friendship struct {
	ID          string    `json:"id"`
	RequesterID string    `json:"requester_id"`
	AddresseeID string    `json:"addressee_id"`
	Status      string    `json:"status"` // "pending", "accepted", "declined"
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// FriendUser represents a friend with their current athlete telemetry.
type FriendUser struct {
	ID           string  `json:"id"`
	Username     string  `json:"username"`
	Faction      string  `json:"faction"`
	TotalAreaSqm float64 `json:"total_area_sqm"`
	Level        int     `json:"level"`
	XP           int64   `json:"xp"`
	TotalRuns    int     `json:"total_runs"`
}

// FriendRequestDetail encapsulates a pending incoming/outgoing friend request.
type FriendRequestDetail struct {
	ID               string    `json:"id"`
	RequesterID      string    `json:"requester_id"`
	RequesterName    string    `json:"requester_name"`
	RequesterFaction string    `json:"requester_faction"`
	AddresseeID      string    `json:"addressee_id"`
	AddresseeName    string    `json:"addressee_name"`
	Status           string    `json:"status"`
	CreatedAt        time.Time `json:"created_at"`
	IsIncoming       bool      `json:"is_incoming"`
}

// Duel represents a head-to-head athletic territorial battle between two runners.
type Duel struct {
	ID                 string     `json:"id"`
	ChallengerID       string     `json:"challenger_id"`
	ChallengerUsername string     `json:"challenger_username"`
	OpponentID         string     `json:"opponent_id"`
	OpponentUsername   string     `json:"opponent_username"`
	ActivityType       string     `json:"activity_type,omitempty"`
	TargetType         string     `json:"target_type"` // "area", "distance"
	TargetValue        float64    `json:"target_value"`
	Status             string     `json:"status"` // "pending", "active", "completed", "declined", "expired"
	ChallengerProgress float64    `json:"challenger_progress"`
	OpponentProgress   float64    `json:"opponent_progress"`
	WinnerID           string     `json:"winner_id,omitempty"`
	XpStake            int        `json:"xp_stake"`
	ExpiresAt          time.Time  `json:"expires_at"`
	CreatedAt          time.Time  `json:"created_at"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
}

// PrivacyZone represents a user-defined geographic exclusion zone.
type PrivacyZone struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id,omitempty"`
	Name         string    `json:"name"`
	Latitude     float64   `json:"latitude"`
	Longitude    float64   `json:"longitude"`
	RadiusMeters float64   `json:"radius_meters"`
	IsEnabled    bool      `json:"is_enabled"`
	CreatedAt    time.Time `json:"created_at"`
}

// UserSettings represents a user's privacy and operational preferences.
type UserSettings struct {
	LiveVisibility string `json:"live_visibility"`
}
