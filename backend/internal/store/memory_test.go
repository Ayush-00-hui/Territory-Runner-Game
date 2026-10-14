package store_test

import (
	"context"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIdempotencyDoesNotDoubleCount(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	run := &store.Run{
		ID:              "run_1",
		UserID:          "usr_ayush",
		IdempotencyKey:  "idem_test_key_123",
		DurationSeconds: 300,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}

	loop := &geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5009, Longitude: -0.1200},
			{Latitude: 51.5009, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       9180.0,
		LoopDistanceMeters: 388.0,
		ClosedAt:           time.Now().UTC(),
	}

	// First submission
	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, run, loop, nil)
	require.NoError(t, err)
	assert.Equal(t, 9180.0, res1.AreaClaimedSqm)
	assert.Equal(t, 9180.0, res1.PlayerTotalAreaSqm)

	userAfterFirst, err := memStore.GetUser(ctx, "usr_ayush")
	require.NoError(t, err)
	require.NotNil(t, userAfterFirst)
	assert.Equal(t, 9180.0, userAfterFirst.TotalAreaSqm)
	assert.Equal(t, 1, userAfterFirst.TotalRuns)

	// Duplicate submission with identical idempotency key
	res2, err := memStore.CaptureRunAndMutateTerritories(ctx, run, loop, nil)
	require.NoError(t, err)
	assert.Equal(t, res1.RunID, res2.RunID)
	assert.Equal(t, res1.AreaClaimedSqm, res2.AreaClaimedSqm)

	// User total area and runs MUST NOT have doubled
	userAfterDuplicate, err := memStore.GetUser(ctx, "usr_ayush")
	require.NoError(t, err)
	assert.Equal(t, 9180.0, userAfterDuplicate.TotalAreaSqm, "Duplicate idempotency key must not double count area")
	assert.Equal(t, 1, userAfterDuplicate.TotalRuns, "Duplicate idempotency key must not increment run count")
}

func TestLeaderboardOrdering(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "u1", Username: "Runner1", TotalAreaSqm: 500.0})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "u2", Username: "Runner2", TotalAreaSqm: 15000.0})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "u3", Username: "Runner3", TotalAreaSqm: 8000.0})

	lb, err := memStore.GetLeaderboard(ctx, 10)
	require.NoError(t, err)
	require.Len(t, lb, 3)

	assert.Equal(t, "Runner2", lb[0].Username)
	assert.Equal(t, 1, lb[0].Rank)
	assert.Equal(t, 15000.0, lb[0].TotalAreaSqm)

	assert.Equal(t, "Runner3", lb[1].Username)
	assert.Equal(t, 2, lb[1].Rank)

	assert.Equal(t, "Runner1", lb[2].Username)
	assert.Equal(t, 3, lb[2].Rank)
}
