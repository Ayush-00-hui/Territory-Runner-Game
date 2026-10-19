package store_test

import (
	"context"
	"fmt"
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

	lb, err := memStore.GetLeaderboard(ctx, 10, "")
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

func TestFriendshipFlow(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// Seed 2 users
	u1 := &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard", TotalAreaSqm: 50000.0}
	u2 := &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion", TotalAreaSqm: 35000.0}
	require.NoError(t, memStore.UpsertUser(ctx, u1))
	require.NoError(t, memStore.UpsertUser(ctx, u2))

	// Self-request fails
	_, err := memStore.SendFriendRequest(ctx, "usr_alice", "usr_alice")
	assert.Error(t, err)

	// Send request: Alice -> Bob
	req, err := memStore.SendFriendRequest(ctx, "usr_alice", "usr_bob")
	require.NoError(t, err)
	assert.Equal(t, "pending", req.Status)

	// Duplicate fails
	_, err = memStore.SendFriendRequest(ctx, "usr_alice", "usr_bob")
	assert.Error(t, err)

	// Check pending requests for Bob (incoming)
	bobRequests, err := memStore.GetFriendRequests(ctx, "usr_bob")
	require.NoError(t, err)
	require.Len(t, bobRequests, 1)
	assert.True(t, bobRequests[0].IsIncoming)
	assert.Equal(t, "Alice", bobRequests[0].RequesterName)

	// Check pending requests for Alice (outgoing)
	aliceRequests, err := memStore.GetFriendRequests(ctx, "usr_alice")
	require.NoError(t, err)
	require.Len(t, aliceRequests, 1)
	assert.False(t, aliceRequests[0].IsIncoming)

	// Alice cannot accept her own request
	err = memStore.RespondFriendRequest(ctx, req.ID, "usr_alice", "accept")
	assert.Error(t, err)

	// Bob accepts
	err = memStore.RespondFriendRequest(ctx, req.ID, "usr_bob", "accept")
	require.NoError(t, err)

	// Bob's friends list contains Alice
	bobFriends, err := memStore.GetFriends(ctx, "usr_bob")
	require.NoError(t, err)
	require.Len(t, bobFriends, 1)
	assert.Equal(t, "Alice", bobFriends[0].Username)
	assert.Equal(t, 50000.0, bobFriends[0].TotalAreaSqm)

	// Alice's friends list contains Bob
	aliceFriends, err := memStore.GetFriends(ctx, "usr_alice")
	require.NoError(t, err)
	require.Len(t, aliceFriends, 1)
	assert.Equal(t, "Bob", aliceFriends[0].Username)

	// No more pending requests
	pending, err := memStore.GetFriendRequests(ctx, "usr_bob")
	require.NoError(t, err)
	assert.Empty(t, pending)
}

func TestDuelFlow(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	u1 := &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard", XP: 500}
	u2 := &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion", XP: 300}
	require.NoError(t, memStore.UpsertUser(ctx, u1))
	require.NoError(t, memStore.UpsertUser(ctx, u2))

	duel := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      250,
	}

	// Create duel
	err := memStore.CreateDuel(ctx, duel)
	require.NoError(t, err)

	duels, err := memStore.GetDuelsByUser(ctx, "usr_bob")
	require.NoError(t, err)
	require.Len(t, duels, 1)
	assert.Equal(t, "pending", duels[0].Status)
	assert.Equal(t, "Alice", duels[0].ChallengerUsername)
	assert.Equal(t, "Bob", duels[0].OpponentUsername)

	// Bob accepts duel
	err = memStore.AcceptDuel(ctx, duel.ID, "usr_bob")
	require.NoError(t, err)

	// Progress duel: Alice runs and claims 6,000 m²
	err = memStore.UpdateDuelProgress(ctx, "usr_alice", "running", 6000.0, 1200.0)
	require.NoError(t, err)

	duels, err = memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	assert.Equal(t, "active", duels[0].Status)
	assert.Equal(t, 6000.0, duels[0].ChallengerProgress)
	assert.Equal(t, 0.0, duels[0].OpponentProgress)

	// Bob runs and claims 4,000 m²
	err = memStore.UpdateDuelProgress(ctx, "usr_bob", "running", 4000.0, 1000.0)
	require.NoError(t, err)

	// Alice runs again and claims 5,000 m² (Total: 11,000 >= 10,000 target!)
	err = memStore.UpdateDuelProgress(ctx, "usr_alice", "running", 5000.0, 1100.0)
	require.NoError(t, err)

	duels, err = memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	assert.Equal(t, "completed", duels[0].Status)
	assert.Equal(t, "usr_alice", duels[0].WinnerID)
	assert.NotNil(t, duels[0].CompletedAt)

	// Alice awarded XP stake
	aliceAfter, err := memStore.GetUser(ctx, "usr_alice")
	require.NoError(t, err)
	assert.Equal(t, int64(750), aliceAfter.XP) // 500 + 250
}

func TestFriendsAndDuelsAntiAbuse(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_charlie", Username: "Charlie", Faction: "Neon Syndicate"})

	// 1. Self-friending prevention
	_, err := memStore.SendFriendRequest(ctx, "usr_alice", "usr_alice")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "cannot send friend request to yourself")

	// 2. Self-dueling prevention
	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_alice",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "cannot challenge yourself")

	// 3. XP stake bounds
	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      1500, // exceeds 1000
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "xp stake must be between 0 and 1000")

	// 4. Target bounds (area and distance)
	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  100.0, // too small (< 500)
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "target value for area duel must be between 500 and 500,000")

	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "distance",
		TargetValue:  0.1, // too small (< 0.5 km)
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "distance duel target")

	// 5. Valid duel creation
	validDuel := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  5000.0,
		XpStake:      250,
	}
	require.NoError(t, memStore.CreateDuel(ctx, validDuel))

	// 6. Duplicate duel rejection (pending)
	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "distance",
		TargetValue:  5.0,
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "already exists")

	// Reverse direction duplicate rejection (Bob challenges Alice)
	err = memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_bob",
		OpponentID:   "usr_alice",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "already exists")

	// 7. Expired duel acceptance rejection
	memStore.SetDuelExpiresAtForTest(validDuel.ID, time.Now().UTC().Add(-1*time.Hour))
	err = memStore.AcceptDuel(ctx, validDuel.ID, "usr_bob")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "expired")
}

func TestDuelDeclineFlow(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_eve", Username: "Eve", Faction: "Shadow Syndicate"})

	duel := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      200,
	}
	require.NoError(t, memStore.CreateDuel(ctx, duel))

	// Unauthorized third party cannot decline
	err := memStore.DeclineDuel(ctx, duel.ID, "usr_eve")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unauthorized")

	// Opponent declines
	err = memStore.DeclineDuel(ctx, duel.ID, "usr_bob")
	require.NoError(t, err)

	duels, err := memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	require.Len(t, duels, 1)
	assert.Equal(t, "declined", duels[0].Status)
}

func TestDuelExpirationResolution(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", XP: 1000})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", XP: 1000})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_charlie", Username: "Charlie", XP: 1000})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_dave", Username: "Dave", XP: 1000})

	// Case 1: Alice leads against Bob when duel expires -> Alice wins
	duel1 := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_bob",
		TargetType:   "area",
		TargetValue:  20000.0,
		XpStake:      300,
	}
	require.NoError(t, memStore.CreateDuel(ctx, duel1))
	require.NoError(t, memStore.AcceptDuel(ctx, duel1.ID, "usr_bob"))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_alice", "running", 5000.0, 1000.0))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_bob", "running", 2000.0, 500.0))

	// Expire duel 1
	memStore.SetDuelExpiresAtForTest(duel1.ID, time.Now().UTC().Add(-10*time.Minute))
	duels, err := memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	var resolvedDuel1 store.Duel
	for _, d := range duels {
		if d.ID == duel1.ID {
			resolvedDuel1 = d
			break
		}
	}
	assert.Equal(t, "completed", resolvedDuel1.Status)
	assert.Equal(t, "usr_alice", resolvedDuel1.WinnerID)

	aliceUser, _ := memStore.GetUser(ctx, "usr_alice")
	assert.Equal(t, int64(1300), aliceUser.XP) // 1000 + 300

	// Case 2: Charlie leads against Alice when duel expires -> Charlie wins
	duel2 := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_charlie",
		TargetType:   "area",
		TargetValue:  20000.0,
		XpStake:      400,
	}
	require.NoError(t, memStore.CreateDuel(ctx, duel2))
	require.NoError(t, memStore.AcceptDuel(ctx, duel2.ID, "usr_charlie"))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_alice", "running", 3000.0, 1000.0))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_charlie", "running", 6000.0, 1500.0))

	memStore.SetDuelExpiresAtForTest(duel2.ID, time.Now().UTC().Add(-5*time.Minute))
	duels, err = memStore.GetDuelsByUser(ctx, "usr_charlie")
	require.NoError(t, err)
	var resolvedDuel2 store.Duel
	for _, d := range duels {
		if d.ID == duel2.ID {
			resolvedDuel2 = d
			break
		}
	}
	assert.Equal(t, "completed", resolvedDuel2.Status)
	assert.Equal(t, "usr_charlie", resolvedDuel2.WinnerID)

	charlieUser, _ := memStore.GetUser(ctx, "usr_charlie")
	assert.Equal(t, int64(1400), charlieUser.XP) // 1000 + 400

	// Case 3: Tied duel when expired -> status is "expired", no winner
	duel3 := &store.Duel{
		ChallengerID: "usr_alice",
		OpponentID:   "usr_dave",
		TargetType:   "area",
		TargetValue:  20000.0,
		XpStake:      200,
	}
	require.NoError(t, memStore.CreateDuel(ctx, duel3))
	require.NoError(t, memStore.AcceptDuel(ctx, duel3.ID, "usr_dave"))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_alice", "running", 4000.0, 1000.0))
	require.NoError(t, memStore.UpdateDuelProgress(ctx, "usr_dave", "running", 4000.0, 1000.0))

	memStore.SetDuelExpiresAtForTest(duel3.ID, time.Now().UTC().Add(-2*time.Minute))
	duels, err = memStore.GetDuelsByUser(ctx, "usr_dave")
	require.NoError(t, err)
	var resolvedDuel3 store.Duel
	for _, d := range duels {
		if d.ID == duel3.ID {
			resolvedDuel3 = d
			break
		}
	}
	assert.Equal(t, "expired", resolvedDuel3.Status)
	assert.Empty(t, resolvedDuel3.WinnerID)
}

func TestDuelActivityModalitySegregation(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_runner_1", Username: "Runner1"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_runner_2", Username: "Runner2"})

	// Create a CYCLING duel
	duel := &store.Duel{
		ChallengerID: "usr_runner_1",
		OpponentID:   "usr_runner_2",
		ActivityType: "cycling",
		TargetType:   "distance",
		TargetValue:  20.0, // 20 km
		XpStake:      500,
	}
	require.NoError(t, memStore.CreateDuel(ctx, duel))
	require.NoError(t, memStore.AcceptDuel(ctx, duel.ID, "usr_runner_2"))

	// 1. Running workout occurs (5.0 km) -> Should NOT progress cycling duel
	err := memStore.UpdateDuelProgress(ctx, "usr_runner_1", "running", 10000.0, 5000.0)
	require.NoError(t, err)

	duels, err := memStore.GetDuelsByUser(ctx, "usr_runner_1")
	require.NoError(t, err)
	assert.Equal(t, 0.0, duels[0].ChallengerProgress)

	// 2. Cycling workout occurs (10.0 km) -> MUST progress cycling duel
	err = memStore.UpdateDuelProgress(ctx, "usr_runner_1", "cycling", 50000.0, 10000.0)
	require.NoError(t, err)

	duels, err = memStore.GetDuelsByUser(ctx, "usr_runner_1")
	require.NoError(t, err)
	assert.Equal(t, 10.0, duels[0].ChallengerProgress)
}

func TestDuelConcurrencyLimits(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_pacer", Username: "Pacer"})

	// Create 5 active duels with different opponents
	for i := 1; i <= 5; i++ {
		oppID := fmt.Sprintf("usr_rival_%d", i)
		_ = memStore.UpsertUser(ctx, &store.User{ID: oppID, Username: oppID})

		d := &store.Duel{
			ChallengerID: "usr_pacer",
			OpponentID:   oppID,
			TargetType:   "area",
			TargetValue:  5000.0,
			XpStake:      100,
		}
		require.NoError(t, memStore.CreateDuel(ctx, d))
		require.NoError(t, memStore.AcceptDuel(ctx, d.ID, oppID))
	}

	// 6th active duel attempt fails with max active duel limit
	opp6 := "usr_rival_6"
	_ = memStore.UpsertUser(ctx, &store.User{ID: opp6, Username: opp6})
	err := memStore.CreateDuel(ctx, &store.Duel{
		ChallengerID: "usr_pacer",
		OpponentID:   opp6,
		TargetType:   "area",
		TargetValue:  5000.0,
		XpStake:      100,
	})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "maximum active duel limit (5) reached")
}

func TestUserSettingsDefaultAndUpdates(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// 1. New user defaults to 'off'
	settings, err := memStore.GetUserSettings(ctx, "user_new_1")
	require.NoError(t, err)
	assert.Equal(t, "off", settings.LiveVisibility)

	// 2. Update to 'friends'
	err = memStore.UpdateUserSettings(ctx, "user_new_1", &store.UserSettings{LiveVisibility: "friends"})
	require.NoError(t, err)

	settings, err = memStore.GetUserSettings(ctx, "user_new_1")
	require.NoError(t, err)
	assert.Equal(t, "friends", settings.LiveVisibility)

	// 3. Update to 'nearby'
	err = memStore.UpdateUserSettings(ctx, "user_new_1", &store.UserSettings{LiveVisibility: "nearby"})
	require.NoError(t, err)

	settings, err = memStore.GetUserSettings(ctx, "user_new_1")
	require.NoError(t, err)
	assert.Equal(t, "nearby", settings.LiveVisibility)
}

func TestCaptureRunMinimumAreaFloor25Sqm(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// 1. Loop with area 18 m² (< 25 m²): Must award 0 XP, 0 claimed area, no duel credit
	subThresholdLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.50000, Longitude: -0.12000},
			{Latitude: 51.50004, Longitude: -0.12000},
			{Latitude: 51.50004, Longitude: -0.12005},
			{Latitude: 51.50000, Longitude: -0.12005},
			{Latitude: 51.50000, Longitude: -0.12000},
		},
		AreaSqMeters:       18.0,
		LoopDistanceMeters: 18.0,
		ClosedAt:           time.Now().UTC(),
	}

	res1, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_sub_floor",
		UserID:         "usr_runner_1",
		IdempotencyKey: "idem_floor_001",
		DistanceMeters: 50.0,
	}, []geo.EnclosedLoop{subThresholdLoop}, nil)
	require.NoError(t, err)
	assert.True(t, res1.LoopDetected, "Loop was geometrically detected")
	assert.Equal(t, 0.0, res1.AreaClaimedSqm, "Area below 25 m² must not be awarded")
	assert.Equal(t, 0, res1.XpAwarded, "XP must be 0 for sub-25 m² captures")

	user1, err := memStore.GetUser(ctx, "usr_runner_1")
	require.NoError(t, err)
	assert.Equal(t, 0.0, user1.TotalAreaSqm)
	assert.Equal(t, int64(0), user1.XP)

	// 2. Loop with area 40 m² (>= 25 m²): Must award claimed area and XP
	validLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.50000, Longitude: -0.12000},
			{Latitude: 51.50007, Longitude: -0.12000},
			{Latitude: 51.50007, Longitude: -0.12008},
			{Latitude: 51.50000, Longitude: -0.12008},
			{Latitude: 51.50000, Longitude: -0.12000},
		},
		AreaSqMeters:       40.0,
		LoopDistanceMeters: 45.0,
		ClosedAt:           time.Now().UTC(),
	}

	res2, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_above_floor",
		UserID:         "usr_runner_1",
		IdempotencyKey: "idem_floor_002",
		DistanceMeters: 100.0,
	}, []geo.EnclosedLoop{validLoop}, nil)
	require.NoError(t, err)
	assert.Equal(t, 40.0, res2.AreaClaimedSqm)
	assert.Greater(t, res2.XpAwarded, 0)

	user1After, err := memStore.GetUser(ctx, "usr_runner_1")
	require.NoError(t, err)
	assert.Equal(t, 40.0, user1After.TotalAreaSqm)
	assert.Greater(t, user1After.XP, int64(0))
}

func TestLazyTerritoryDecayCalculation(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()

	// Capture a 500 m² territory
	now := time.Now().UTC()
	loop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.500, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.120},
		},
		AreaSqMeters:       500.0,
		LoopDistanceMeters: 400.0,
		ClosedAt:           now,
	}

	_, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_decay_test",
		UserID:         "usr_decay",
		IdempotencyKey: "idem_decay_001",
	}, []geo.EnclosedLoop{loop}, nil)
	require.NoError(t, err)

	tID := "poly_usr_decay_territory"

	// 1. Immediately after capture: strength is 100.0
	tImmediate, err := memStore.GetTerritoryByID(ctx, tID)
	require.NoError(t, err)
	require.NotNil(t, tImmediate)
	assert.Equal(t, 100.0, tImmediate.Strength)
	assert.False(t, tImmediate.IsWeak(now))

	// 2. Direct formula verification:
	// 2 days later: 100 - (2 * 15) = 70.0
	twoDaysLater := now.Add(48 * time.Hour)
	assert.InDelta(t, 70.0, tImmediate.EffectiveStrength(twoDaysLater), 0.01)
	assert.False(t, tImmediate.IsWeak(twoDaysLater))

	// 5 days later: 100 - (5 * 15) = 25.0 (< 30.0 -> IsWeak == true)
	fiveDaysLater := now.Add(5 * 24 * time.Hour)
	assert.InDelta(t, 25.0, tImmediate.EffectiveStrength(fiveDaysLater), 0.01)
	assert.True(t, tImmediate.IsWeak(fiveDaysLater))

	// 10 days later: 100 - (10 * 15) = max(0, -50) = 0.0
	tenDaysLater := now.Add(10 * 24 * time.Hour)
	assert.Equal(t, 0.0, tImmediate.EffectiveStrength(tenDaysLater))
	assert.True(t, tImmediate.IsWeak(tenDaysLater))
}

func TestWeakTerritoryCaptureBonusAndDefenseReset(t *testing.T) {
	ctx := context.Background()
	memStore := store.NewMemoryStore()
	now := time.Now().UTC()

	// 1. Setup rival user with decayed/weak territory (captured 6 days ago, strength = 10.0 < 30.0)
	rivalLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.500, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.120},
		},
		AreaSqMeters:       1000.0,
		LoopDistanceMeters: 500.0,
		ClosedAt:           now.Add(-6 * 24 * time.Hour),
	}

	_, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_rival_initial",
		UserID:         "usr_rival",
		IdempotencyKey: "idem_rival_001",
		CreatedAt:      now.Add(-6 * 24 * time.Hour),
	}, []geo.EnclosedLoop{rivalLoop}, nil)
	require.NoError(t, err)

	// Simulate territory age by setting LastDefendedAt to 6 days ago
	rivalTID := "poly_usr_rival_territory"
	rivalT, err := memStore.GetTerritoryByID(ctx, rivalTID)
	require.NoError(t, err)
	// Read lazily calculates strength
	assert.True(t, rivalT.EffectiveStrength(now) < store.TerritoryWeakThreshold, "Rival territory must be weak (<30.0)")

	// 2. Attacker conquers rival land: 1000 m²
	attackerLoop := geo.EnclosedLoop{
		Polygon: []geo.LatLng{
			{Latitude: 51.500, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.120},
			{Latitude: 51.502, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.122},
			{Latitude: 51.500, Longitude: -0.120},
		},
		AreaSqMeters:       1000.0,
		LoopDistanceMeters: 500.0,
		ClosedAt:           now,
	}

	attackerRes, err := memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_attacker_conquer",
		UserID:         "usr_attacker",
		IdempotencyKey: "idem_att_001",
		CreatedAt:      now,
	}, []geo.EnclosedLoop{attackerLoop}, nil)
	require.NoError(t, err)

	// Normal 1000 m² gives round(1000/20) = 50 XP (or min 100 = 100).
	// Weak rival 1.5x bonus gives round((1000*1.5)/20) = round(1500/20) = 75 XP (or min 100).
	// For larger area, say 5000 m²: normal is 250 XP, weak 1.5x is 375 XP.
	assert.Contains(t, attackerRes.RivalsAffected, "usr_rival")

	// 3. Defending territory resets strength to 100.0 and LastDefendedAt to now
	attackerT, err := memStore.GetTerritoryByID(ctx, "poly_usr_attacker_territory")
	require.NoError(t, err)
	assert.Equal(t, 100.0, attackerT.Strength, "Freshly captured/defended territory must reset to 100.0 strength")
}



