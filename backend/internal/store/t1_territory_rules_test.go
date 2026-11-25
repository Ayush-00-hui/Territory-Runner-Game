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

// Phase T1: Failing tests asserting new territory claiming and ranking invariants.

// (a) Claiming same loop twice gives zero new area the second time
func TestT1_ClaimingSameLoopTwiceGivesZeroNewArea(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	loop := geo.EnclosedLoop{
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

	run1 := &store.Run{
		ID:              "run_t1_1",
		UserID:          "usr_t1_a",
		IdempotencyKey:  "idem_t1_1",
		DurationSeconds: 300,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}

	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, run1, []geo.EnclosedLoop{loop}, nil)
	require.NoError(t, err)
	assert.Greater(t, res1.AreaClaimedSqm, 9000.0)

	// Second run with NEW idempotency key but identical geometry
	run2 := &store.Run{
		ID:              "run_t1_2",
		UserID:          "usr_t1_a",
		IdempotencyKey:  "idem_t1_2",
		DurationSeconds: 310,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}

	res2, err := memStore.CaptureRunAndMutateTerritories(ctx, run2, []geo.EnclosedLoop{loop}, nil)
	require.NoError(t, err)

	// Invariant (a): Claiming identical loop twice must yield 0 net new area and 0 XP
	assert.Equal(t, 0.0, res2.AreaClaimedSqm, "Second identical loop must yield 0 net new area")
	assert.Equal(t, 0, res2.XpAwarded, "Zero net new area must award 0 XP")
}

// (b) Loop fully inside own land earns nothing
func TestT1_LoopFullyInsideOwnLandEarnsNothing(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	outerLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1216},
			{Latitude: 51.5000, Longitude: -0.1216},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       12000.0,
		LoopDistanceMeters: 450.0,
		ClosedAt:           time.Now().UTC(),
	}

	run1 := &store.Run{
		ID:              "run_t1_outer",
		UserID:          "usr_t1_b",
		IdempotencyKey:  "idem_t1_outer",
		DurationSeconds: 400,
		DistanceMeters:  600.0,
		Status:          "accepted",
	}
	_, err := memStore.CaptureRunAndMutateTerritories(ctx, run1, []geo.EnclosedLoop{outerLoop}, nil)
	require.NoError(t, err)

	innerLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5003, Longitude: -0.1204},
			{Latitude: 51.5007, Longitude: -0.1204},
			{Latitude: 51.5007, Longitude: -0.1210},
			{Latitude: 51.5003, Longitude: -0.1210},
			{Latitude: 51.5003, Longitude: -0.1204},
		},
		AreaSqMeters:       1800.0,
		LoopDistanceMeters: 180.0,
		ClosedAt:           time.Now().UTC(),
	}

	run2 := &store.Run{
		ID:              "run_t1_inner",
		UserID:          "usr_t1_b",
		IdempotencyKey:  "idem_t1_inner",
		DurationSeconds: 150,
		DistanceMeters:  200.0,
		Status:          "accepted",
	}
	resInner, err := memStore.CaptureRunAndMutateTerritories(ctx, run2, []geo.EnclosedLoop{innerLoop}, nil)
	require.NoError(t, err)

	// Invariant (b): loop fully inside own land earns 0 new area and 0 XP
	assert.Equal(t, 0.0, resInner.AreaClaimedSqm, "Loop fully inside own land must give 0 new area")
	assert.Equal(t, 0, resInner.XpAwarded, "Loop fully inside own land must give 0 XP")
}

// (c) Two overlapping loops in one run are not double counted
func TestT1_OverlappingLoopsInOneRunNotDoubleCounted(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// Loop 1 (~10,000 m²)
	loop1 := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           time.Now().UTC(),
	}

	// Loop 2 (~10,000 m²), overlaps Loop 1 by ~50%
	loop2 := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5005, Longitude: -0.1200},
			{Latitude: 51.5015, Longitude: -0.1200},
			{Latitude: 51.5015, Longitude: -0.1214},
			{Latitude: 51.5005, Longitude: -0.1214},
			{Latitude: 51.5005, Longitude: -0.1200},
		},
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           time.Now().UTC(),
	}

	run := &store.Run{
		ID:              "run_t1_multi",
		UserID:          "usr_t1_c",
		IdempotencyKey:  "idem_t1_multi",
		DurationSeconds: 600,
		DistanceMeters:  800.0,
		Status:          "accepted",
	}

	res, err := memStore.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{loop1, loop2}, nil)
	require.NoError(t, err)

	// Invariant (c): Total union is ~16,200 m², NOT 21,600 m² (double counted)
	assert.Less(t, res.AreaClaimedSqm, 18000.0, "Two overlapping loops in one run must not double-count overlapping area")
}

// (d) Loop overlapping a shielded rival never creates overlapping ownership
func TestT1_LoopOverlappingShieldedRivalNeverCreatesOverlappingOwnership(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	now := time.Now().UTC()

	// Rival captures a territory and is shielded
	rivalLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           now,
	}

	_, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_rival_shield",
		UserID:         "usr_rival_shield",
		IdempotencyKey: "idem_rival_shield",
		Status:         "accepted",
	}, []geo.EnclosedLoop{rivalLoop}, nil)
	require.NoError(t, err)

	// Ensure rival is shielded
	rivalTerritory, err := memStore.GetTerritoryByID(ctx, "poly_usr_rival_shield_territory")
	require.NoError(t, err)
	require.NotNil(t, rivalTerritory)
	shieldEnd := now.Add(2 * time.Hour)
	rivalTerritory.CooldownUntil = &shieldEnd

	// Player runs a loop directly over rival's shielded territory
	playerLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           now,
	}

	playerRes, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_player_invader",
		UserID:         "usr_player_invader",
		IdempotencyKey: "idem_player_invader",
		Status:         "accepted",
	}, []geo.EnclosedLoop{playerLoop}, nil)
	require.NoError(t, err)

	// Invariant (d): Rival territory was shielded, so player must claim 0 new area
	assert.Equal(t, 0.0, playerRes.AreaClaimedSqm, "Player cannot claim shielded rival territory")

	// Player territory must not own the shielded land
	playerTerritory, _ := memStore.GetTerritoryByID(ctx, "poly_usr_player_invader_territory")
	if playerTerritory != nil {
		assert.Equal(t, 0.0, playerTerritory.AreaSqm, "Player cannot hold shielded rival land")
	}
}

// (e) Weak-rival bonus is proportional to overlapped area only and deduplicated
func TestT1_WeakRivalBonusIsProportionalToOverlappedAreaOnly(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	now := time.Now().UTC()

	// Seed weak rival territory (100 m² at 20% strength, unshielded)
	unshielded := now.Add(-1 * time.Hour)
	rivalT := &store.Territory{
		ID:             "poly_usr_weak_t",
		OwnerID:        "usr_weak",
		Username:       "WeakRival",
		AreaSqm:        100.0,
		Strength:       20.0,
		LastDefendedAt: now.Add(-48 * time.Hour),
		LastDecayedAt:  now.Add(-48 * time.Hour),
		CooldownUntil:  &unshielded,
		UpdatedAt:      now.Add(-48 * time.Hour),
	}
	memStore.AddTerritoryForTest(rivalT)

	// Player captures huge loop (10,000 m²) that overlaps rival's 100 m²
	hugeLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5000, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.5010, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1214},
			{Latitude: 51.5000, Longitude: -0.1200},
		},
		AreaSqMeters:       10000.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           now,
	}

	res, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_weak_bonus",
		UserID:         "usr_bonus_hunter",
		IdempotencyKey: "idem_weak_bonus",
		Status:         "accepted",
	}, []geo.EnclosedLoop{hugeLoop}, nil)
	require.NoError(t, err)

	// Weak bonus should be 50% of 100 m² (50 m²), NOT 50% of 10,000 m² (5000 m²!)
	// With 10,000 m² base + 50 m² bonus = 10,050 m² -> XP = round(10050 / 20) = 503 XP
	// If bug exists: 10,000 + 5000 = 15,000 m² -> XP = round(15000 / 20) = 750 XP
	assert.Less(t, res.XpAwarded, 550, "Weak bonus must be proportional to overlapped rival area (100 m²), not full loop area (10,000 m²)")
}

// (f) Area-weighted strength does not fully heal distant land
func TestT1_AreaWeightedStrengthDoesNotFullyHealDistantLand(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	now := time.Now().UTC()

	tID := "poly_usr_t1_str_territory"
	cooldown := now.Add(-1 * time.Hour) // unshielded
	memStore.UpsertUser(ctx, &store.User{
		ID:           "usr_t1_str",
		Username:     "StrRunner",
		TotalAreaSqm: 10000.0,
	})

	memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_t1_large",
		UserID:         "usr_t1_str",
		IdempotencyKey: "idem_t1_large",
		Status:         "accepted",
	}, []geo.EnclosedLoop{
		{
			Polygon: []geo.LatLng{
				{Latitude: 51.5000, Longitude: -0.1200},
				{Latitude: 51.5010, Longitude: -0.1200},
				{Latitude: 51.5010, Longitude: -0.1214},
				{Latitude: 51.5000, Longitude: -0.1214},
				{Latitude: 51.5000, Longitude: -0.1200},
			},
			AreaSqMeters:       10000.0,
			LoopDistanceMeters: 400.0,
			ClosedAt:           now.Add(-48 * time.Hour),
		},
	}, nil)

	tObj, _ := memStore.GetTerritoryByID(ctx, tID)
	require.NotNil(t, tObj)
	tObj.Strength = 40.0
	tObj.LastDefendedAt = now.Add(-48 * time.Hour)
	tObj.LastDecayedAt = now.Add(-48 * time.Hour)
	tObj.CooldownUntil = &cooldown
	memStore.AddTerritoryForTest(tObj)

	smallLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5020, Longitude: -0.1200},
			{Latitude: 51.5022, Longitude: -0.1200},
			{Latitude: 51.5022, Longitude: -0.1202},
			{Latitude: 51.5020, Longitude: -0.1202},
			{Latitude: 51.5020, Longitude: -0.1200},
		},
		AreaSqMeters:       200.0,
		LoopDistanceMeters: 80.0,
		ClosedAt:           now,
	}

	_, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_t1_small",
		UserID:         "usr_t1_str",
		IdempotencyKey: "idem_t1_small",
		Status:         "accepted",
	}, []geo.EnclosedLoop{smallLoop}, nil)
	require.NoError(t, err)

	updatedT, err := memStore.GetTerritoryByID(ctx, tID)
	require.NoError(t, err)
	require.NotNil(t, updatedT)

	// Invariant (f): Strength must NOT jump to 100%. Should be area-weighted:
	// (40.0 * 10000 + 100.0 * 200) / 10200 ~= 41.17%
	assert.Less(t, updatedT.Strength, 50.0, "Small loop must not reset strength of large existing territory to 100%")
}

// (g) Sub-floor claim does not mutate territories
func TestT1_SubFloorClaimDoesNotMutateTerritories(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	initLoop := geo.EnclosedLoop{
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
	run1 := &store.Run{
		ID:              "run_t1_init",
		UserID:          "usr_t1_floor",
		IdempotencyKey:  "idem_t1_init",
		DurationSeconds: 300,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}
	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, run1, []geo.EnclosedLoop{initLoop}, nil)
	require.NoError(t, err)
	initialArea := res1.PlayerTotalAreaSqm

	// Sub-floor loop: only 15 m² (< 25 m² floor)
	subFloorLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.5010, Longitude: -0.1200},
			{Latitude: 51.50104, Longitude: -0.1200},
			{Latitude: 51.50104, Longitude: -0.12005},
			{Latitude: 51.5010, Longitude: -0.12005},
			{Latitude: 51.5010, Longitude: -0.1200},
		},
		AreaSqMeters:       15.0,
		LoopDistanceMeters: 20.0,
		ClosedAt:           time.Now().UTC(),
	}

	runSubFloor := &store.Run{
		ID:              "run_t1_sub",
		UserID:          "usr_t1_floor",
		IdempotencyKey:  "idem_t1_sub",
		DurationSeconds: 30,
		DistanceMeters:  25.0,
		Status:          "accepted",
	}

	resSub, err := memStore.CaptureRunAndMutateTerritories(ctx, runSubFloor, []geo.EnclosedLoop{subFloorLoop}, nil)
	require.NoError(t, err)
	assert.Equal(t, 0.0, resSub.AreaClaimedSqm)
	assert.Equal(t, 0, resSub.XpAwarded)

	// Invariant (g): sub-floor claim must not alter player total area
	user, err := memStore.GetUser(ctx, "usr_t1_floor")
	require.NoError(t, err)
	assert.Equal(t, initialArea, user.TotalAreaSqm, "Sub-floor claim must not alter player total area")
}

// (h) Thin loops are rejected by thinness quotient
func TestT1_ThinLoopsAreRejected(t *testing.T) {
	engine := geo.NewEngine()
	// Thin loop: 200m long, 1.25m wide (Perimeter ~402.5m, Area ~250m² > 200m² min area)
	// Isoperimetric quotient = 4 * pi * 250 / (402.5^2) = 3141.6 / 162006 = 0.01939 < 0.02
	thinPolygon := []geo.LatLng{
		{Latitude: 51.500000, Longitude: -0.120000},
		{Latitude: 51.501800, Longitude: -0.120000},
		{Latitude: 51.501800, Longitude: -0.120018},
		{Latitude: 51.500000, Longitude: -0.120018},
		{Latitude: 51.500000, Longitude: -0.120000},
	}

	_, err := engine.ValidateLoop(thinPolygon, time.Now())
	require.Error(t, err, "Thin loop must be rejected")
	assert.Contains(t, err.Error(), "Loop too thin")
}

// (j) Rankings use current owned area, not summed runs
func TestT1_RankingsUseCurrentOwnedAreaNotSummedRuns(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// Runner A had a huge historical run of 10,000 m²
	_, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:              "run_rank_a",
		UserID:          "usr_rank_a",
		IdempotencyKey:  "idem_rank_a",
		DurationSeconds: 600,
		DistanceMeters:  1000.0,
		Status:          "accepted",
	}, []geo.EnclosedLoop{
		{
			Polygon: []geo.LatLng{
				{Latitude: 51.5000, Longitude: -0.1200},
				{Latitude: 51.5010, Longitude: -0.1200},
				{Latitude: 51.5010, Longitude: -0.1214},
				{Latitude: 51.5000, Longitude: -0.1214},
				{Latitude: 51.5000, Longitude: -0.1200},
			},
			AreaSqMeters:       10000.0,
			LoopDistanceMeters: 400.0,
			ClosedAt:           time.Now().UTC(),
		},
	}, nil)
	require.NoError(t, err)

	// Rival stole 9,000 m² from Runner A, leaving Runner A with only 1,000 m² currently owned
	tA, err := memStore.GetTerritoryByID(ctx, "poly_usr_rank_a_territory")
	require.NoError(t, err)
	require.NotNil(t, tA)
	tA.AreaSqm = 1000.0
	memStore.AddTerritoryForTest(tA)

	// Runner B had smaller historical runs (3,000 m²), but still holds all 3,000 m²
	_, err = memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:              "run_rank_b",
		UserID:          "usr_rank_b",
		IdempotencyKey:  "idem_rank_b",
		DurationSeconds: 300,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}, []geo.EnclosedLoop{
		{
			Polygon: []geo.LatLng{
				{Latitude: 51.5020, Longitude: -0.1200},
				{Latitude: 51.5025, Longitude: -0.1200},
				{Latitude: 51.5025, Longitude: -0.1208},
				{Latitude: 51.5020, Longitude: -0.1208},
				{Latitude: 51.5020, Longitude: -0.1200},
			},
			AreaSqMeters:       3000.0,
			LoopDistanceMeters: 260.0,
			ClosedAt:           time.Now().UTC(),
		},
	}, nil)
	require.NoError(t, err)

	leaderboard, err := memStore.GetLeaderboard(ctx, 10, "")
	require.NoError(t, err)
	require.Len(t, leaderboard, 2)

	// Invariant (j): Runner B (currently owns ~3085 sqm) must rank #1 over Runner A (currently owns 1000 sqm)
	assert.Equal(t, "usr_rank_b", leaderboard[0].UserID, "Runner with larger currently owned area must rank higher")
	assert.Greater(t, leaderboard[0].TotalAreaSqm, 3000.0)
}
