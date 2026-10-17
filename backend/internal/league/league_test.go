package league

import (
	"fmt"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
)

func TestMondayResetCalculation(t *testing.T) {
	// Monday 10:30 UTC
	tMon := time.Date(2026, time.October, 19, 10, 30, 0, 0, time.UTC)
	start := CurrentWeekStart(tMon)
	assert.Equal(t, time.Date(2026, time.October, 19, 0, 0, 0, 0, time.UTC), start)
	reset := NextMondayReset(tMon)
	assert.Equal(t, time.Date(2026, time.October, 26, 0, 0, 0, 0, time.UTC), reset)

	// Wednesday 14:00 UTC
	tWed := time.Date(2026, time.October, 21, 14, 0, 0, 0, time.UTC)
	assert.Equal(t, time.Date(2026, time.October, 19, 0, 0, 0, 0, time.UTC), CurrentWeekStart(tWed))
	assert.Equal(t, time.Date(2026, time.October, 26, 0, 0, 0, 0, time.UTC), NextMondayReset(tWed))

	// Sunday 23:59:59 UTC
	tSun := time.Date(2026, time.October, 25, 23, 59, 59, 0, time.UTC)
	assert.Equal(t, time.Date(2026, time.October, 19, 0, 0, 0, 0, time.UTC), CurrentWeekStart(tSun))
	assert.Equal(t, time.Date(2026, time.October, 26, 0, 0, 0, 0, time.UTC), NextMondayReset(tSun))
}

func TestEmptyLeagueHandling(t *testing.T) {
	now := time.Date(2026, time.October, 20, 12, 0, 0, 0, time.UTC)
	user := &store.User{
		ID:       "runner_empty_test",
		Username: "GhostRunner",
		Faction:  "Solaris Nomads",
	}

	standing := CalculateStandings("runner_empty_test", nil, now, user)

	assert.Equal(t, "runner_empty_test", standing.UserID)
	assert.Equal(t, "GhostRunner", standing.Username)
	assert.Equal(t, "Solaris Nomads", standing.Faction)
	assert.Equal(t, TierBronze, standing.Tier)
	assert.Equal(t, 0, standing.TotalParticipants)
	assert.Equal(t, 0.0, standing.WeeklyAreaSqm)
	assert.Equal(t, 0, standing.WeeklyRuns)
	assert.Equal(t, int64(475200), standing.SecondsUntilReset) // from Tue 12:00 to Mon 00:00 (5.5 days = 475200s)
	assert.Empty(t, standing.Standings)
}

func TestTierAssignmentsAndPercentiles(t *testing.T) {
	// Create 20 participants:
	// Rank 1 (Top 5% = 1): Diamond
	// Ranks 2-5 (Next 20% = 4): Gold (cutoff rank 5)
	// Ranks 6-12 (Next 35% = 7): Silver (cutoff rank 12)
	// Ranks 13-20 (Bottom 40% = 8): Bronze
	var participants []store.WeeklyParticipant
	for i := 1; i <= 20; i++ {
		participants = append(participants, store.WeeklyParticipant{
			UserID:        fmt.Sprintf("user_%02d", i),
			Username:      fmt.Sprintf("Runner_%02d", i),
			Faction:       "Cyber Vanguard",
			WeeklyAreaSqm: float64(21-i) * 1000.0,
			WeeklyRuns:    i,
		})
	}

	now := time.Date(2026, time.October, 20, 12, 0, 0, 0, time.UTC)

	// 1. Verify Diamond runner (rank 1)
	s1 := CalculateStandings("user_01", participants, now, nil)
	assert.Equal(t, 1, s1.Rank)
	assert.Equal(t, TierDiamond, s1.Tier)
	assert.Equal(t, 0, s1.PromotionRankCutoff, "Diamond cannot promote")
	assert.Equal(t, 1, s1.RelegationRankCutoff, "Falling below rank 1 relegates to Gold")

	// 2. Verify Gold runner (rank 3)
	s3 := CalculateStandings("user_03", participants, now, nil)
	assert.Equal(t, 3, s3.Rank)
	assert.Equal(t, TierGold, s3.Tier)
	assert.Equal(t, 1, s3.PromotionRankCutoff, "Promoting to Diamond requires rank <= 1")
	assert.Equal(t, 5, s3.RelegationRankCutoff, "Falling below rank 5 relegates to Silver")

	// 3. Verify Silver runner (rank 8)
	s8 := CalculateStandings("user_08", participants, now, nil)
	assert.Equal(t, 8, s8.Rank)
	assert.Equal(t, TierSilver, s8.Tier)
	assert.Equal(t, 5, s8.PromotionRankCutoff, "Promoting to Gold requires rank <= 5")
	assert.Equal(t, 12, s8.RelegationRankCutoff, "Falling below rank 12 relegates to Bronze")

	// 4. Verify Bronze runner (rank 18)
	s18 := CalculateStandings("user_18", participants, now, nil)
	assert.Equal(t, 18, s18.Rank)
	assert.Equal(t, TierBronze, s18.Tier)
	assert.Equal(t, 12, s18.PromotionRankCutoff, "Promoting to Silver requires rank <= 12")
	assert.Equal(t, 0, s18.RelegationRankCutoff, "Bronze cannot relegate")
}

func TestUnrankedUserAppendedToStandings(t *testing.T) {
	participants := []store.WeeklyParticipant{
		{UserID: "runner_a", Username: "Alice", Faction: "Cyber Vanguard", WeeklyAreaSqm: 5000.0, WeeklyRuns: 2},
		{UserID: "runner_b", Username: "Bob", Faction: "Neon Syndicate", WeeklyAreaSqm: 3000.0, WeeklyRuns: 1},
	}
	now := time.Date(2026, time.October, 20, 12, 0, 0, 0, time.UTC)
	currentUser := &store.User{
		ID:       "runner_new",
		Username: "Newbie",
		Faction:  "Solaris Nomads",
	}

	standing := CalculateStandings("runner_new", participants, now, currentUser)

	assert.Equal(t, 3, standing.Rank)
	assert.Equal(t, TierBronze, standing.Tier)
	assert.Equal(t, 0.0, standing.WeeklyAreaSqm)
	assert.Equal(t, 3, standing.TotalParticipants)

	// Standings list contains Alice, Bob, and Newbie
	assert.Len(t, standing.Standings, 3)
	assert.True(t, standing.Standings[2].IsCurrentUser)
	assert.Equal(t, "Newbie", standing.Standings[2].Username)
}
