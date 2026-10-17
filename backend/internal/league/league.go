package league

import (
	"math"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
)

const (
	TierDiamond = "Diamond"
	TierGold    = "Gold"
	TierSilver  = "Silver"
	TierBronze  = "Bronze"
)

// CurrentWeekStart returns Monday 00:00:00 UTC for the week enclosing the given timestamp.
func CurrentWeekStart(now time.Time) time.Time {
	now = now.UTC()
	weekday := int(now.Weekday()) // Sunday = 0, Monday = 1, ..., Saturday = 6
	daysSinceMonday := (weekday + 6) % 7
	year, month, day := now.Date()
	midnight := time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	return midnight.AddDate(0, 0, -daysSinceMonday)
}

// NextMondayReset returns the next Monday 00:00:00 UTC reset deadline.
func NextMondayReset(now time.Time) time.Time {
	return CurrentWeekStart(now).AddDate(0, 0, 7)
}

// CalculateStandings computes weekly league tiers, ranks, promotion/relegation thresholds,
// and formats the standing model for the authenticated runner.
func CalculateStandings(currentUserID string, participants []store.WeeklyParticipant, now time.Time, currentUser *store.User) *store.LeagueStanding {
	now = now.UTC()
	resetAt := NextMondayReset(now)
	secondsUntilReset := int64(resetAt.Sub(now).Seconds())
	if secondsUntilReset < 0 {
		secondsUntilReset = 0
	}

	n := len(participants)

	// Handle empty league
	if n == 0 {
		username := "Runner"
		faction := "Cyber Vanguard"
		if currentUser != nil {
			username = currentUser.Username
			faction = currentUser.Faction
		}
		return &store.LeagueStanding{
			UserID:               currentUserID,
			Username:             username,
			Faction:              faction,
			Tier:                 TierBronze,
			Rank:                 1,
			TotalParticipants:    0,
			WeeklyAreaSqm:        0,
			WeeklyRuns:           0,
			PromotionRankCutoff:  0,
			RelegationRankCutoff: 0,
			ResetAt:              resetAt,
			SecondsUntilReset:    secondsUntilReset,
			Standings:            []store.LeagueParticipant{},
		}
	}

	// Compute tier cutoff ranks based on percentiles
	// Diamond: Top 5%
	// Gold: Next 20% (up to 25%)
	// Silver: Next 35% (up to 60%)
	// Bronze: Bottom 40% (remaining)
	diamondCutoff := int(math.Ceil(0.05 * float64(n)))
	if diamondCutoff < 1 {
		diamondCutoff = 1
	}

	goldCutoff := int(math.Ceil(0.25 * float64(n)))
	if goldCutoff <= diamondCutoff && n > diamondCutoff {
		goldCutoff = diamondCutoff + 1
	}

	silverCutoff := int(math.Ceil(0.60 * float64(n)))
	if silverCutoff <= goldCutoff && n > goldCutoff {
		silverCutoff = goldCutoff + 1
	}

	assignTier := func(rank int) string {
		switch {
		case rank <= diamondCutoff:
			return TierDiamond
		case rank <= goldCutoff:
			return TierGold
		case rank <= silverCutoff:
			return TierSilver
		default:
			return TierBronze
		}
	}

	var standings []store.LeagueParticipant
	userFound := false
	var userRank int
	var userTier string
	var userWeeklyArea float64
	var userWeeklyRuns int
	userUsername := ""
	userFaction := ""

	for idx, p := range participants {
		rank := idx + 1
		tier := assignTier(rank)
		isCurrent := p.UserID == currentUserID

		if isCurrent {
			userFound = true
			userRank = rank
			userTier = tier
			userWeeklyArea = p.WeeklyAreaSqm
			userWeeklyRuns = p.WeeklyRuns
			userUsername = p.Username
			userFaction = p.Faction
		}

		standings = append(standings, store.LeagueParticipant{
			Rank:          rank,
			UserID:        p.UserID,
			Username:      p.Username,
			Faction:       p.Faction,
			Tier:          tier,
			WeeklyAreaSqm: p.WeeklyAreaSqm,
			WeeklyRuns:    p.WeeklyRuns,
			IsCurrentUser: isCurrent,
		})
	}

	// If current user has no runs yet in the active week
	if !userFound {
		userRank = n + 1
		userTier = TierBronze
		userWeeklyArea = 0
		userWeeklyRuns = 0
		if currentUser != nil {
			userUsername = currentUser.Username
			userFaction = currentUser.Faction
		} else {
			userUsername = "Runner_" + currentUserID[:min(6, len(currentUserID))]
			factionList := []string{"Cyber Vanguard", "Neon Syndicate", "Solaris Nomads"}
			userFaction = factionList[0]
		}

		standings = append(standings, store.LeagueParticipant{
			Rank:          userRank,
			UserID:        currentUserID,
			Username:      userUsername,
			Faction:       userFaction,
			Tier:          userTier,
			WeeklyAreaSqm: 0,
			WeeklyRuns:    0,
			IsCurrentUser: true,
		})
	}

	// Promotion & relegation cutoffs tailored to current user tier
	var promotionRankCutoff int
	var relegationRankCutoff int

	switch userTier {
	case TierBronze:
		promotionRankCutoff = silverCutoff
		relegationRankCutoff = 0
	case TierSilver:
		promotionRankCutoff = goldCutoff
		relegationRankCutoff = silverCutoff
	case TierGold:
		promotionRankCutoff = diamondCutoff
		relegationRankCutoff = goldCutoff
	case TierDiamond:
		promotionRankCutoff = 0
		relegationRankCutoff = diamondCutoff
	}

	return &store.LeagueStanding{
		UserID:               currentUserID,
		Username:             userUsername,
		Faction:              userFaction,
		Tier:                 userTier,
		Rank:                 userRank,
		TotalParticipants:    len(standings),
		WeeklyAreaSqm:        userWeeklyArea,
		WeeklyRuns:           userWeeklyRuns,
		PromotionRankCutoff:  promotionRankCutoff,
		RelegationRankCutoff: relegationRankCutoff,
		ResetAt:              resetAt,
		SecondsUntilReset:    secondsUntilReset,
		Standings:            standings,
	}
}
