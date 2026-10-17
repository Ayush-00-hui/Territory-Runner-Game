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

	// GetLeaderboard returns runners ordered descending by total claimed sovereign area.
	GetLeaderboard(ctx context.Context, limit int) ([]LeaderboardEntry, error)

	// SaveDeviceToken persists or updates an FCM registration token for a user.
	SaveDeviceToken(ctx context.Context, userID, token string) error

	// GetDeviceTokens returns all active FCM device tokens registered for a user.
	GetDeviceTokens(ctx context.Context, userID string) ([]string, error)

	// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart.
	GetWeeklyStandings(ctx context.Context, weekStart time.Time) ([]WeeklyParticipant, error)

	// GetFactionStandings returns territory dominance aggregated by athletic faction.
	GetFactionStandings(ctx context.Context) (*FactionStandingsResponse, error)

	// UpdateUserFaction updates a user's chosen athletic faction.
	UpdateUserFaction(ctx context.Context, userID, faction string) error

	// Ping checks database connectivity.
	Ping(ctx context.Context) error

	// Close terminates any underlying connection pools.
	Close()
}
