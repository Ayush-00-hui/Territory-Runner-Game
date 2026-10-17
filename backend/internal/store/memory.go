package store

import (
	"context"
	"fmt"
	"math"
	"sort"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

// MemoryStore provides a thread-safe, in-memory implementation of Store for hermetic unit testing.
type MemoryStore struct {
	mu           sync.Mutex
	users        map[string]*User
	runs         map[string]*Run
	runsByOrder  []string
	territories  map[string]*Territory
	deviceTokens map[string][]string
}

// NewMemoryStore initializes an in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:        make(map[string]*User),
		runs:         make(map[string]*Run),
		runsByOrder:  make([]string, 0),
		territories:  make(map[string]*Territory),
		deviceTokens: make(map[string][]string),
	}
}

func (m *MemoryStore) Ping(ctx context.Context) error {
	return nil
}

func (m *MemoryStore) Close() {}

func (m *MemoryStore) GetUser(ctx context.Context, id string) (*User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	u, ok := m.users[id]
	if !ok {
		return nil, nil
	}
	cpy := *u
	return &cpy, nil
}

func (m *MemoryStore) UpsertUser(ctx context.Context, u *User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	cpy := *u
	if cpy.CreatedAt.IsZero() {
		cpy.CreatedAt = time.Now().UTC()
	}
	cpy.UpdatedAt = time.Now().UTC()
	m.users[u.ID] = &cpy
	return nil
}

func (m *MemoryStore) GetRunsByUser(ctx context.Context, userID string, limit int) ([]Run, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if limit <= 0 {
		limit = 20
	}
	var res []Run
	for i := len(m.runsByOrder) - 1; i >= 0; i-- {
		key := m.runsByOrder[i]
		r := m.runs[key]
		if r.UserID == userID {
			res = append(res, *r)
			if len(res) >= limit {
				break
			}
		}
	}
	return res, nil
}

func (m *MemoryStore) GetRunByIdempotencyKey(ctx context.Context, key string) (*Run, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	r, ok := m.runs[key]
	if !ok {
		return nil, nil
	}
	cpy := *r
	return &cpy, nil
}

func (m *MemoryStore) GetTerritoriesInBBox(ctx context.Context, minLng, minLat, maxLng, maxLat float64) ([]Territory, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []Territory
	for _, t := range m.territories {
		res = append(res, *t)
	}
	return res, nil
}

func (m *MemoryStore) CaptureRunAndMutateTerritories(
	ctx context.Context,
	run *Run,
	loops []geo.EnclosedLoop,
	rawTrack []geo.TrackPoint,
) (*CaptureResult, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 1. Idempotency Check
	if existing, ok := m.runs[run.IdempotencyKey]; ok {
		u := m.users[existing.UserID]
		totalArea := 0.0
		if u != nil {
			totalArea = u.TotalAreaSqm
		}
		xpAwarded := int(math.Max(100, math.Round(existing.AreaClaimed/20.0)))
		return &CaptureResult{
			RunID:              existing.ID,
			IdempotencyKey:     existing.IdempotencyKey,
			Status:             existing.Status,
			AnomalyScore:       existing.AnomalyScore,
			AnomalyReasons:     existing.AnomalyReasons,
			LoopDetected:       existing.AreaClaimed > 0,
			AreaClaimedSqm:     existing.AreaClaimed,
			XpAwarded:          xpAwarded,
			PlayerTotalAreaSqm: totalArea,
		}, nil
	}

	var areaClaimed float64
	var xpAwarded int
	var playerTotalArea float64
	var geojson string

	user, ok := m.users[run.UserID]
	if !ok {
		user = &User{
			ID:           run.UserID,
			Username:     "Runner_" + run.UserID,
			Faction:      "Cyber Vanguard",
			TotalAreaSqm: 0.0,
			XP:           0,
			Level:        1,
			TotalRuns:    0,
			CreatedAt:    time.Now().UTC(),
		}
		m.users[run.UserID] = user
	}

	if len(loops) > 0 {
		for _, loop := range loops {
			areaClaimed += loop.AreaSqMeters
		}
		xpAwarded = int(math.Max(100, math.Round(areaClaimed/20.0)))
		user.TotalAreaSqm += areaClaimed
		user.XP += int64(xpAwarded)
		user.TotalRuns++
		user.UpdatedAt = time.Now().UTC()
		playerTotalArea = user.TotalAreaSqm

		tID := fmt.Sprintf("poly_%s_territory", run.UserID)
		if len(loops[0].Polygon) > 0 {
			geojson = fmt.Sprintf(`{"type":"MultiPolygon","coordinates":[[[[%f,%f]]]]}`, loops[0].Polygon[0].Longitude, loops[0].Polygon[0].Latitude)
		}
		m.territories[tID] = &Territory{
			ID:             tID,
			OwnerID:        run.UserID,
			Username:       user.Username,
			GeoJSON:        geojson,
			AreaSqm:        playerTotalArea,
			Strength:       100.0,
			LastDefendedAt: time.Now().UTC(),
			UpdatedAt:      time.Now().UTC(),
		}
	} else {
		user.TotalRuns++
		user.UpdatedAt = time.Now().UTC()
		playerTotalArea = user.TotalAreaSqm
	}

	runCopy := *run
	runCopy.AreaClaimed = areaClaimed
	if runCopy.Status == "" {
		runCopy.Status = "accepted"
	}
	if runCopy.CreatedAt.IsZero() {
		runCopy.CreatedAt = time.Now().UTC()
	}
	m.runs[run.IdempotencyKey] = &runCopy
	m.runsByOrder = append(m.runsByOrder, run.IdempotencyKey)

	var rivalsAffected []string
	if len(loops) > 0 {
		for _, t := range m.territories {
			if t.OwnerID != run.UserID {
				rivalsAffected = append(rivalsAffected, t.OwnerID)
			}
		}
	}

	return &CaptureResult{
		RunID:              run.ID,
		IdempotencyKey:     run.IdempotencyKey,
		Status:             run.Status,
		AnomalyScore:       run.AnomalyScore,
		AnomalyReasons:     run.AnomalyReasons,
		LoopDetected:       len(loops) > 0,
		AreaClaimedSqm:     areaClaimed,
		XpAwarded:          xpAwarded,
		PlayerTotalAreaSqm: playerTotalArea,
		TerritoryGeoJSON:   geojson,
		RivalsAffected:     rivalsAffected,
	}, nil
}

func (m *MemoryStore) GetLeaderboard(ctx context.Context, limit int) ([]LeaderboardEntry, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if limit <= 0 {
		limit = 50
	}
	var usersList []*User
	for _, u := range m.users {
		usersList = append(usersList, u)
	}

	sort.Slice(usersList, func(i, j int) bool {
		return usersList[i].TotalAreaSqm > usersList[j].TotalAreaSqm
	})

	var res []LeaderboardEntry
	for i, u := range usersList {
		if i >= limit {
			break
		}
		res = append(res, LeaderboardEntry{
			Rank:         i + 1,
			UserID:       u.ID,
			Username:     u.Username,
			Faction:      u.Faction,
			TotalAreaSqm: u.TotalAreaSqm,
			Level:        u.Level,
			TotalRuns:    u.TotalRuns,
		})
	}
	return res, nil
}

// ApplyTerritoryDecay updates in-memory territories by decaying strength based on elapsed days since last defense.
func (m *MemoryStore) ApplyTerritoryDecay(ctx context.Context, decayPerDay float64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if decayPerDay <= 0 {
		decayPerDay = 15.0
	}
	now := time.Now().UTC()
	for _, t := range m.territories {
		days := now.Sub(t.LastDefendedAt).Seconds() / 86400.0
		decayed := t.Strength - (days * decayPerDay)
		if decayed < 0.0 {
			decayed = 0.0
		} else if decayed > 100.0 {
			decayed = 100.0
		}
		t.Strength = decayed
		t.UpdatedAt = now
	}
	return nil
}

// UpdateTerritoryDefense updates a territory's strength and marks it defended as of now.
func (m *MemoryStore) UpdateTerritoryDefense(ctx context.Context, territoryID string, newStrength float64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if newStrength < 0 {
		newStrength = 0
	} else if newStrength > 100 {
		newStrength = 100
	}
	t, exists := m.territories[territoryID]
	if !exists {
		return fmt.Errorf("territory %s not found", territoryID)
	}
	t.Strength = newStrength
	t.LastDefendedAt = time.Now().UTC()
	t.UpdatedAt = time.Now().UTC()
	return nil
}

// GetTerritoryByID retrieves a territory by its unique ID.
func (m *MemoryStore) GetTerritoryByID(ctx context.Context, id string) (*Territory, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t, ok := m.territories[id]
	if !ok {
		return nil, nil
	}
	copy := *t
	return &copy, nil
}

// SaveDeviceToken persists or updates an FCM registration token for a user.
func (m *MemoryStore) SaveDeviceToken(ctx context.Context, userID, token string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	tokens := m.deviceTokens[userID]
	for _, tok := range tokens {
		if tok == token {
			return nil
		}
	}
	m.deviceTokens[userID] = append(tokens, token)
	return nil
}

// GetDeviceTokens returns all active FCM device tokens registered for a user.
func (m *MemoryStore) GetDeviceTokens(ctx context.Context, userID string) ([]string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	tokens, ok := m.deviceTokens[userID]
	if !ok {
		return nil, nil
	}
	copied := make([]string, len(tokens))
	copy(copied, tokens)
	return copied, nil
}

// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart.
func (m *MemoryStore) GetWeeklyStandings(ctx context.Context, weekStart time.Time) ([]WeeklyParticipant, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	type stats struct {
		area float64
		runs int
	}
	userStats := make(map[string]*stats)

	for _, r := range m.runs {
		if r.Status == "accepted" && (r.CreatedAt.Equal(weekStart) || r.CreatedAt.After(weekStart)) {
			s, exists := userStats[r.UserID]
			if !exists {
				s = &stats{}
				userStats[r.UserID] = s
			}
			s.area += r.AreaClaimed
			s.runs++
		}
	}

	var participants []WeeklyParticipant
	for uid, s := range userStats {
		username := "Runner_" + uid[:min(6, len(uid))]
		faction := "Cyber Vanguard"
		if u, exists := m.users[uid]; exists {
			username = u.Username
			faction = u.Faction
		}
		participants = append(participants, WeeklyParticipant{
			UserID:        uid,
			Username:      username,
			Faction:       faction,
			WeeklyAreaSqm: s.area,
			WeeklyRuns:    s.runs,
		})
	}

	sort.Slice(participants, func(i, j int) bool {
		if participants[i].WeeklyAreaSqm != participants[j].WeeklyAreaSqm {
			return participants[i].WeeklyAreaSqm > participants[j].WeeklyAreaSqm
		}
		return participants[i].WeeklyRuns > participants[j].WeeklyRuns
	})

	return participants, nil
}

// GetFactionStandings returns territory dominance aggregated by athletic faction in MemoryStore.
func (m *MemoryStore) GetFactionStandings(ctx context.Context) (*FactionStandingsResponse, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	canonical := map[string]*FactionStanding{
		"Cyber Vanguard": {Faction: "Cyber Vanguard", TotalAreaSqm: 0, MemberCount: 0},
		"Neon Syndicate": {Faction: "Neon Syndicate", TotalAreaSqm: 0, MemberCount: 0},
		"Solaris Nomads": {Faction: "Solaris Nomads", TotalAreaSqm: 0, MemberCount: 0},
	}

	for _, u := range m.users {
		if u.Faction == "" {
			continue
		}
		st, ok := canonical[u.Faction]
		if !ok {
			st = &FactionStanding{Faction: u.Faction, TotalAreaSqm: 0, MemberCount: 0}
			canonical[u.Faction] = st
		}
		st.MemberCount++
	}

	for _, t := range m.territories {
		u, ok := m.users[t.OwnerID]
		if ok && u.Faction != "" {
			st, exists := canonical[u.Faction]
			if exists {
				st.TotalAreaSqm += t.AreaSqm
			}
		}
	}

	var totalArea float64
	for _, st := range canonical {
		totalArea += st.TotalAreaSqm
	}

	var standings []FactionStanding
	for _, st := range canonical {
		if totalArea > 0 {
			st.Percentage = math.Round((st.TotalAreaSqm/totalArea)*1000.0) / 10.0
		} else {
			st.Percentage = 33.3
		}
		standings = append(standings, *st)
	}

	sort.Slice(standings, func(i, j int) bool {
		if standings[i].TotalAreaSqm == standings[j].TotalAreaSqm {
			return standings[i].MemberCount > standings[j].MemberCount
		}
		return standings[i].TotalAreaSqm > standings[j].TotalAreaSqm
	})

	return &FactionStandingsResponse{
		TotalAreaSqm: totalArea,
		Standings:    standings,
	}, nil
}

// UpdateUserFaction updates a user's chosen athletic faction in MemoryStore.
func (m *MemoryStore) UpdateUserFaction(ctx context.Context, userID, faction string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	u, ok := m.users[userID]
	if !ok {
		return fmt.Errorf("user not found: %s", userID)
	}
	u.Faction = faction
	u.UpdatedAt = time.Now().UTC()
	return nil
}


