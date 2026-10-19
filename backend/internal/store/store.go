package store

import (
	"context"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

// Store defines persistence operations for user profiles, runs, and territory geometries.
type Store interface {
	// GetUser retrieves a user profile by ID.
	GetUser(ctx context.Context, id string) (*User, error)

	// UpsertUser creates or updates a user profile.
	UpsertUser(ctx context.Context, u *User) error

	// GetRunsByUser retrieves recent runs recorded by a runner.
	GetRunsByUser(ctx context.Context, userID string, limit int) ([]Run, error)

	// GetRunByIdempotencyKey fetches an existing run by its unique idempotency key.
	GetRunByIdempotencyKey(ctx context.Context, key string) (*Run, error)

	// GetTerritoriesInBBox fetches all territories intersecting a geographic bounding box as GeoJSON.
	GetTerritoriesInBBox(ctx context.Context, minLng, minLat, maxLng, maxLat float64) ([]Territory, error)

	// CaptureRunAndMutateTerritories atomically:
	// 1. Obtains a transaction-scoped advisory lock to prevent concurrent spatial race conditions.
	// 2. Unions the new loop polygon into the owner's MultiPolygon.
	// 3. Performs ST_Difference against intersecting rival territories (deleting overtaken shapes).
	// 4. Calculates exact geodesic area with ::geography and updates runner total area + XP.
	// 5. Inserts the run record with unique idempotency key.
	CaptureRunAndMutateTerritories(ctx context.Context, run *Run, loops []geo.EnclosedLoop, rawTrack []geo.TrackPoint) (*CaptureResult, error)

	// ApplyTerritoryDecay decays all territory strength based on time elapsed since last defense.
	ApplyTerritoryDecay(ctx context.Context, decayPerDay float64) error

	// UpdateTerritoryDefense updates a territory's strength and marks it defended as of now.
	UpdateTerritoryDefense(ctx context.Context, territoryID string, newStrength float64) error

	// GetTerritoryByID retrieves a territory by its unique ID.
	GetTerritoryByID(ctx context.Context, id string) (*Territory, error)

	// GetLeaderboard returns runners ordered descending by total claimed sovereign area, optionally filtered by activity type.
	GetLeaderboard(ctx context.Context, limit int, activityType string) ([]LeaderboardEntry, error)

	// SaveDeviceToken persists or updates an FCM registration token for a user.
	SaveDeviceToken(ctx context.Context, userID, token string) error

	// GetDeviceTokens returns all active FCM device tokens registered for a user.
	GetDeviceTokens(ctx context.Context, userID string) ([]string, error)

	// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart, optionally filtered by activity type.
	GetWeeklyStandings(ctx context.Context, weekStart time.Time, activityType string) ([]WeeklyParticipant, error)

	// GetFactionStandings returns territory dominance aggregated by athletic faction.
	GetFactionStandings(ctx context.Context) (*FactionStandingsResponse, error)

	// UpdateUserFaction updates a user's chosen athletic faction.
	UpdateUserFaction(ctx context.Context, userID, faction string) error

	// SendFriendRequest creates a new pending friendship request from requesterID to addresseeID.
	SendFriendRequest(ctx context.Context, requesterID, addresseeID string) (*Friendship, error)

	// RespondFriendRequest accepts or declines a pending friend request.
	RespondFriendRequest(ctx context.Context, friendshipID, userID, action string) error

	// GetFriends returns all accepted friends of the given user.
	GetFriends(ctx context.Context, userID string) ([]FriendUser, error)

	// GetFriendRequests returns all pending friend requests involving the user.
	GetFriendRequests(ctx context.Context, userID string) ([]FriendRequestDetail, error)

	// CreateDuel initiates a new head-to-head duel challenge.
	CreateDuel(ctx context.Context, d *Duel) error

	// GetDuelsByUser retrieves active, pending, and recent duels involving the user.
	GetDuelsByUser(ctx context.Context, userID string) ([]Duel, error)

	// AcceptDuel transitions a pending duel to active.
	AcceptDuel(ctx context.Context, duelID, userID string) error

	// DeclineDuel marks a pending duel as declined.
	DeclineDuel(ctx context.Context, duelID, userID string) error

	// UpdateDuelProgress increments progress for any active duels involving userID matching the run's activity type.
	UpdateDuelProgress(ctx context.Context, userID, activityType string, areaDelta, distanceDelta float64) error

	// GetPrivacyZones returns all privacy zones configured for a user.
	GetPrivacyZones(ctx context.Context, userID string) ([]PrivacyZone, error)

	// SetPrivacyZones replaces all privacy zones for a user.
	SetPrivacyZones(ctx context.Context, userID string, zones []PrivacyZone) error

	// GetUserSettings returns user settings including live_visibility.
	GetUserSettings(ctx context.Context, userID string) (*UserSettings, error)

	// UpdateUserSettings updates user settings including live_visibility.
	UpdateUserSettings(ctx context.Context, userID string, settings *UserSettings) error

	// Ping checks database connectivity.
	Ping(ctx context.Context) error

	// Close terminates any underlying connection pools.
	Close()
}
