package store

import (
	"context"

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
	CaptureRunAndMutateTerritories(ctx context.Context, run *Run, loop *geo.EnclosedLoop, rawTrack []geo.TrackPoint) (*CaptureResult, error)

	// GetLeaderboard returns runners ordered descending by total claimed sovereign area.
	GetLeaderboard(ctx context.Context, limit int) ([]LeaderboardEntry, error)

	// Ping checks database connectivity.
	Ping(ctx context.Context) error

	// Close terminates any underlying connection pools.
	Close()
}
