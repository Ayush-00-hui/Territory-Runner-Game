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
	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{*loop}, nil)
	require.NoError(t, err)
	assert.Equal(t, 9180.0, res1.AreaClaimedSqm)
	assert.Equal(t, 9180.0, res1.PlayerTotalAreaSqm)

	userAfterFirst, err := memStore.GetUser(ctx, "usr_ayush")
	require.NoError(t, err)
	require.NotNil(t, userAfterFirst)
	assert.Equal(t, 9180.0, userAfterFirst.TotalAreaSqm)
	assert.Equal(t, 1, userAfterFirst.TotalRuns)

	// Duplicate submission with identical idempotency key
	res2, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{*loop}, nil)
	require.NoError(t, err)
	assert.Equal(t, res1.RunID, res2.RunID)
	assert.Equal(t, res1.AreaClaimedSqm, res2.AreaClaimedSqm)

	// User total area and runs MUST NOT have doubled
	userAfterDuplicate, err := memStore.GetUser(ctx, "usr_ayush")
	require.NoError(t, err)
	assert.Equal(t, 9180.0, userAfterDuplicate.TotalAreaSqm, "Duplicate idempotency key must not double count area")
	assert.Equal(t, 1, userAfterDuplicate.TotalRuns, "Duplicate idempotency key must not increment run count")
}

func TestCaptureMultiLoopSummedAreaAndXP(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	run := &store.Run{
		ID:              "run_multi_loop",
		UserID:          "usr_multi",
		IdempotencyKey:  "idem_multi_001",
		DurationSeconds: 600,
		DistanceMeters:  1200.0,
		Status:          "accepted",
	}

	loops := []geo.EnclosedLoop{
		{
			Polygon: []geo.LatLng{
				{Latitude: 51.5000, Longitude: -0.1200},
				{Latitude: 51.5008, Longitude: -0.1200},
				{Latitude: 51.5008, Longitude: -0.1212},
				{Latitude: 51.5000, Longitude: -0.1212},
				{Latitude: 51.5000, Longitude: -0.1200},
			},
			AreaSqMeters:       7350.0,
			LoopDistanceMeters: 340.0,
			ClosedAt:           time.Now().UTC(),
		},
		{
			Polygon: []geo.LatLng{
				{Latitude: 51.5000, Longitude: -0.1190},
				{Latitude: 51.5008, Longitude: -0.1190},
				{Latitude: 51.5008, Longitude: -0.1178},
				{Latitude: 51.5000, Longitude: -0.1178},
				{Latitude: 51.5000, Longitude: -0.1190},
			},
			AreaSqMeters:       7350.0,
			LoopDistanceMeters: 340.0,
			ClosedAt:           time.Now().UTC(),
		},
	}

	res, err := memStore.CaptureRunAndMutateTerritories(ctx, run, loops, nil)
	require.NoError(t, err)
	assert.True(t, res.LoopDetected)
	assert.Equal(t, 14700.0, res.AreaClaimedSqm, "Total area claimed must sum all loops")
	// XP: max(100, round(14700 / 20.0)) = 735
	assert.Equal(t, 735, res.XpAwarded)

	user, err := memStore.GetUser(ctx, "usr_multi")
	require.NoError(t, err)
	assert.Equal(t, 14700.0, user.TotalAreaSqm)
	assert.Equal(t, int64(735), user.XP)
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

func TestCaptureSetsTerritoryStrengthAndLastDefendedAt(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	run := &store.Run{
		ID:              "run_strength_1",
		UserID:          "usr_fortified",
		IdempotencyKey:  "idem_strength_1",
		DurationSeconds: 120,
		DistanceMeters:  200.0,
		Status:          "accepted",
	}

	loop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5, Longitude: -0.12},
			{Latitude: 51.501, Longitude: -0.12},
			{Latitude: 51.501, Longitude: -0.121},
			{Latitude: 51.5, Longitude: -0.121},
			{Latitude: 51.5, Longitude: -0.12},
		},
		AreaSqMeters: 5000.0,
	}

	before := time.Now().UTC().Add(-1 * time.Second)
	_, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop}, nil)
	require.NoError(t, err)

	territories, err := memStore.GetTerritoriesInBBox(ctx, -1.0, 50.0, 1.0, 52.0)
	require.NoError(t, err)
	require.Len(t, territories, 1)

	assert.Equal(t, "poly_usr_fortified_territory", territories[0].ID)
	assert.Equal(t, 100.0, territories[0].Strength)
	assert.True(t, territories[0].LastDefendedAt.After(before) || territories[0].LastDefendedAt.Equal(before))
}

