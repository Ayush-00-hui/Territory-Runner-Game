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

func TestXP_ProportionalScalingAndAntiFarmingFloor(t *testing.T) {
	ctx := context.Background()

	testCases := []struct {
		name        string
		areaSqm     float64
		expectedXP  int
		expectClaim bool
	}{
		{
			name:        "Below 25 sqm floor awards zero XP",
			areaSqm:     24.5,
			expectedXP:  0,
			expectClaim: false,
		},
		{
			name:        "Minimum valid loop (25 sqm) awards 5 XP floor",
			areaSqm:     25.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "40 sqm loop awards 5 XP floor (40/20 = 2 -> floor 5)",
			areaSqm:     40.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "100 sqm loop awards 5 XP (100/20 = 5)",
			areaSqm:     100.0,
			expectedXP:  5,
			expectClaim: true,
		},
		{
			name:        "500 sqm park loop awards 25 XP (500/20 = 25)",
			areaSqm:     500.0,
			expectedXP:  25,
			expectClaim: true,
		},
		{
			name:        "2,000 sqm neighbourhood loop awards 100 XP (2000/20 = 100)",
			areaSqm:     2000.0,
			expectedXP:  100,
			expectClaim: true,
		},
		{
			name:        "10,000 sqm large loop awards 500 XP (10000/20 = 500)",
			areaSqm:     10000.0,
			expectedXP:  500,
			expectClaim: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			memStore := store.NewMemoryStore()
			userID := "athlete_xp_" + tc.name
			runID := "run_" + tc.name

			loop := geo.EnclosedLoop{
				Polygon: []geo.LatLng{
					{Latitude: 51.500, Longitude: -0.120},
					{Latitude: 51.501, Longitude: -0.120},
					{Latitude: 51.501, Longitude: -0.121},
					{Latitude: 51.500, Longitude: -0.121},
					{Latitude: 51.500, Longitude: -0.120},
				},
				AreaSqMeters:       tc.areaSqm,
				LoopDistanceMeters: 400.0,
				ClosedAt:           time.Now().UTC(),
			}

			run := &store.Run{
				ID:             runID,
				UserID:         userID,
				IdempotencyKey: "idem_" + runID,
				DistanceMeters: 500.0,
			}

			result, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop}, nil)
			require.NoError(t, err)
			assert.Equal(t, tc.expectedXP, result.XpAwarded)

			if tc.expectClaim {
				assert.Equal(t, tc.areaSqm, result.AreaClaimedSqm)
			} else {
				assert.Equal(t, 0.0, result.AreaClaimedSqm)
			}

			user, err := memStore.GetUser(ctx, userID)
			require.NoError(t, err)
			assert.Equal(t, int64(tc.expectedXP), user.XP)

			// Verify idempotency does not double-award or change XP
			replayResult, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop}, nil)
			require.NoError(t, err)
			assert.Equal(t, tc.expectedXP, replayResult.XpAwarded)

			userReplay, err := memStore.GetUser(ctx, userID)
			require.NoError(t, err)
			assert.Equal(t, int64(tc.expectedXP), userReplay.XP, "Replay must not increment XP")
		})
	}
}

func TestLevelCalculationFromXP(t *testing.T) {
	testCases := []struct {
		xp    int64
		level int
	}{
		{xp: -10, level: 1},
		{xp: 0, level: 1},
		{xp: 100, level: 1},
		{xp: 249, level: 1},
		{xp: 250, level: 2},
		{xp: 500, level: 2},
		{xp: 749, level: 2},
		{xp: 750, level: 3},
		{xp: 1499, level: 3},
		{xp: 1500, level: 4},
		{xp: 2499, level: 4},
		{xp: 2500, level: 5},
		{xp: 3750, level: 6},
		{xp: 5250, level: 7},
		{xp: 7000, level: 8},
		{xp: 9000, level: 9},
		{xp: 11250, level: 10},
	}

	for _, tc := range testCases {
		assert.Equal(t, tc.level, store.CalculateLevelFromXP(tc.xp), "XP %d should map to Level %d", tc.xp, tc.level)
	}
}

func TestDailyXpCapEnforcement(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	userID := "marathon_runner_daily_cap"
	baseTime := time.Date(2026, 11, 24, 8, 0, 0, 0, time.UTC)

	// Run 1: Claims 180,000 sqm -> 9,000 XP
	loop1 := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.500, Longitude: -0.120},
			{Latitude: 51.510, Longitude: -0.120},
			{Latitude: 51.510, Longitude: -0.130},
			{Latitude: 51.500, Longitude: -0.130},
			{Latitude: 51.500, Longitude: -0.120},
		},
		AreaSqMeters:       180000.0,
		LoopDistanceMeters: 5000.0,
		ClosedAt:           baseTime,
	}
	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_day_1",
		UserID:         userID,
		IdempotencyKey: "idem_day_1",
		DistanceMeters: 5000.0,
		CreatedAt:      baseTime,
	}, []geo.EnclosedLoop{loop1}, nil)
	require.NoError(t, err)
	assert.Equal(t, 9000, res1.XpAwarded)
	assert.Equal(t, 180000.0, res1.AreaClaimedSqm)

	user1, err := memStore.GetUser(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, int64(9000), user1.XP)
	assert.Equal(t, 9, user1.Level) // 9,000 XP -> Level 9 (needs 11,250 for Level 10)

	// Run 2: Same day, claims 40,000 sqm -> would normally be 2,000 XP, but capped to remaining 1,000 XP
	loop2 := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.510, Longitude: -0.120},
			{Latitude: 51.520, Longitude: -0.120},
			{Latitude: 51.520, Longitude: -0.130},
			{Latitude: 51.510, Longitude: -0.130},
			{Latitude: 51.510, Longitude: -0.120},
		},
		AreaSqMeters:       40000.0,
		LoopDistanceMeters: 2000.0,
		ClosedAt:           baseTime.Add(2 * time.Hour),
	}
	res2, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_day_2",
		UserID:         userID,
		IdempotencyKey: "idem_day_2",
		DistanceMeters: 2000.0,
		CreatedAt:      baseTime.Add(2 * time.Hour),
	}, []geo.EnclosedLoop{loop2}, nil)
	require.NoError(t, err)
	assert.Equal(t, 1000, res2.XpAwarded, "XP must be clamped to the 10,000 daily cap")
	assert.Equal(t, 40000.0, res2.AreaClaimedSqm, "Area claim must NOT be blocked by XP cap")

	user2, err := memStore.GetUser(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, int64(10000), user2.XP)

	// Run 3: Same day, claims 20,000 sqm -> 0 XP awarded, but full 20,000 sqm claimed
	loop3 := geo.EnclosedLoop{
		Polygon:            loop2.Polygon,
		AreaSqMeters:       20000.0,
		LoopDistanceMeters: 1000.0,
		ClosedAt:           baseTime.Add(4 * time.Hour),
	}
	res3, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_day_3",
		UserID:         userID,
		IdempotencyKey: "idem_day_3",
		DistanceMeters: 1000.0,
		CreatedAt:      baseTime.Add(4 * time.Hour),
	}, []geo.EnclosedLoop{loop3}, nil)
	require.NoError(t, err)
	assert.Equal(t, 0, res3.XpAwarded, "XP award must be 0 once 10,000 daily cap is reached")
	assert.Equal(t, 20000.0, res3.AreaClaimedSqm, "Area claim continues unhindered")

	// Run 4: Next UTC day (00:00:00+ next day), claims 10,000 sqm -> cap resets, awards 500 XP
	nextDayTime := baseTime.Add(24 * time.Hour)
	loop4 := geo.EnclosedLoop{
		Polygon:            loop1.Polygon,
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 1000.0,
		ClosedAt:           nextDayTime,
	}
	res4, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_next_day",
		UserID:         userID,
		IdempotencyKey: "idem_next_day",
		DistanceMeters: 1000.0,
		CreatedAt:      nextDayTime,
	}, []geo.EnclosedLoop{loop4}, nil)
	require.NoError(t, err)
	assert.Equal(t, 500, res4.XpAwarded, "Daily XP cap resets on next UTC day")

	user4, err := memStore.GetUser(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, int64(10500), user4.XP)
}

func TestTerritoryDespawnGracePeriod(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	now := time.Now().UTC()

	// Initial territory captured at now - 160 hours (0% strength, beginning of 72h grace period)
	t160h := &store.Territory{
		ID:             "poly_decay_160h",
		OwnerID:        "runner_decay_1",
		AreaSqm:        5000.0,
		Strength:       100.0,
		LastDefendedAt: now.Add(-160 * time.Hour),
		LastDecayedAt:  now.Add(-160 * time.Hour),
	}
	memStore.AddTerritoryForTest(t160h)

	assert.Equal(t, 0.0, t160h.EffectiveStrength(now))
	assert.False(t, t160h.IsDespawned(now), "Territory at 160h is in 72h grace period and must NOT be despawned")

	// Check territory in bbox at 160h
	bbox1, err := memStore.GetTerritoriesInBBox(ctx, -1, -1, 1, 1)
	require.NoError(t, err)
	assert.Len(t, bbox1, 1, "Territory in grace period remains queryable in bbox")

	// Territory at now - 200 hours (still within 232h total threshold: 160h + 40h into grace period)
	t200h := &store.Territory{
		ID:             "poly_decay_200h",
		OwnerID:        "runner_decay_2",
		AreaSqm:        3000.0,
		Strength:       100.0,
		LastDefendedAt: now.Add(-200 * time.Hour),
		LastDecayedAt:  now.Add(-200 * time.Hour),
	}
	memStore.AddTerritoryForTest(t200h)
	assert.False(t, t200h.IsDespawned(now), "Territory at 200h (40h into grace period) must NOT be despawned")

	// Territory at now - 233 hours (exceeded 232h: 160h + 72h grace period)
	tDespawned := &store.Territory{
		ID:             "poly_despawned",
		OwnerID:        "runner_abandoned",
		AreaSqm:        8000.0,
		Strength:       100.0,
		LastDefendedAt: now.Add(-233 * time.Hour),
		LastDecayedAt:  now.Add(-233 * time.Hour),
	}
	memStore.AddTerritoryForTest(tDespawned)
	assert.True(t, tDespawned.IsDespawned(now), "Territory beyond 232h must be despawned")

	// Query bbox: should only return the 2 non-despawned territories (160h and 200h)
	bboxFiltered, err := memStore.GetTerritoriesInBBox(ctx, -1, -1, 1, 1)
	require.NoError(t, err)
	assert.Len(t, bboxFiltered, 2, "Despawned territory must be excluded from bbox results")

	// Query by ID for despawned territory returns nil
	fetchedDespawned, err := memStore.GetTerritoryByID(ctx, "poly_despawned")
	require.NoError(t, err)
	assert.Nil(t, fetchedDespawned, "Despawned territory must return nil when queried by ID")
}
