package store

import (
	"context"
	"fmt"
	"math"
	"sort"
	"strings"
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
	friendships  map[string]*Friendship
	duels        map[string]*Duel
	privacyZones map[string][]PrivacyZone
	userSettings map[string]*UserSettings
}

// NewMemoryStore initializes an in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:        make(map[string]*User),
		runs:         make(map[string]*Run),
		runsByOrder:  make([]string, 0),
		territories:  make(map[string]*Territory),
		deviceTokens: make(map[string][]string),
		friendships:  make(map[string]*Friendship),
		duels:        make(map[string]*Duel),
		privacyZones: make(map[string][]PrivacyZone),
		userSettings: make(map[string]*UserSettings),
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
			ActivityType:       existing.ActivityType,
			Status:             existing.Status,
			AnomalyScore:       existing.AnomalyScore,
			AnomalyReasons:     existing.AnomalyReasons,
			LoopDetected:       existing.AreaClaimed > 0,
			AreaClaimedSqm:     existing.AreaClaimed,
			XpAwarded:          xpAwarded,
			PlayerTotalAreaSqm: totalArea,
		}, nil
	}

	var areaClaimed float64 = run.AreaClaimed
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
		var loopArea float64
		for _, loop := range loops {
			loopArea += loop.AreaSqMeters
		}
		areaClaimed = loopArea
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
		if areaClaimed > 0 {
			user.TotalAreaSqm += areaClaimed
			xpAwarded = int(math.Max(100, math.Round(areaClaimed/20.0)))
			user.XP += int64(xpAwarded)
		}
		user.TotalRuns++
		user.UpdatedAt = time.Now().UTC()
		playerTotalArea = user.TotalAreaSqm
	}

	runCopy := *run
	if runCopy.ActivityType == "" {
		runCopy.ActivityType = "running"
	}
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

	m.updateDuelProgressLocked(run.UserID, runCopy.ActivityType, areaClaimed, run.DistanceMeters)

	return &CaptureResult{
		RunID:              run.ID,
		IdempotencyKey:     run.IdempotencyKey,
		ActivityType:       runCopy.ActivityType,
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

func (m *MemoryStore) GetLeaderboard(ctx context.Context, limit int, activityType string) ([]LeaderboardEntry, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if limit <= 0 {
		limit = 50
	}
	activityType = strings.ToLower(strings.TrimSpace(activityType))

	type userAgg struct {
		u    *User
		area float64
		runs int
	}

	var list []userAgg
	for _, u := range m.users {
		if activityType != "" && activityType != "all" {
			var actArea float64
			var actRuns int
			for _, r := range m.runs {
				if r.UserID == u.ID && r.Status == "accepted" {
					rAct := strings.ToLower(strings.TrimSpace(r.ActivityType))
					if rAct == "" {
						rAct = "running"
					}
					if rAct == activityType {
						actArea += r.AreaClaimed
						actRuns++
					}
				}
			}
			list = append(list, userAgg{u: u, area: actArea, runs: actRuns})
		} else {
			list = append(list, userAgg{u: u, area: u.TotalAreaSqm, runs: u.TotalRuns})
		}
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].area > list[j].area
	})

	var res []LeaderboardEntry
	for i, item := range list {
		if i >= limit {
			break
		}
		res = append(res, LeaderboardEntry{
			Rank:         i + 1,
			UserID:       item.u.ID,
			Username:     item.u.Username,
			Faction:      item.u.Faction,
			TotalAreaSqm: item.area,
			Level:        item.u.Level,
			TotalRuns:    item.runs,
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

// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart, optionally filtered by activity.
func (m *MemoryStore) GetWeeklyStandings(ctx context.Context, weekStart time.Time, activityType string) ([]WeeklyParticipant, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	activityType = strings.ToLower(strings.TrimSpace(activityType))

	type stats struct {
		area float64
		runs int
	}
	userStats := make(map[string]*stats)

	for _, r := range m.runs {
		if r.Status == "accepted" && (r.CreatedAt.Equal(weekStart) || r.CreatedAt.After(weekStart)) {
			if activityType != "" && activityType != "all" {
				rAct := strings.ToLower(strings.TrimSpace(r.ActivityType))
				if rAct == "" {
					rAct = "running"
				}
				if rAct != activityType {
					continue
				}
			}
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

// SendFriendRequest creates a new pending friendship request from requesterID to addresseeID.
func (m *MemoryStore) SendFriendRequest(ctx context.Context, requesterID, addresseeID string) (*Friendship, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if requesterID == addresseeID {
		return nil, fmt.Errorf("cannot send friend request to yourself")
	}

	_, reqExists := m.users[requesterID]
	if !reqExists {
		return nil, fmt.Errorf("requester not found: %s", requesterID)
	}
	_, addExists := m.users[addresseeID]
	if !addExists {
		return nil, fmt.Errorf("addressee not found: %s", addresseeID)
	}

	var pendingSent, pendingReceived int
	for _, f := range m.friendships {
		if (f.RequesterID == requesterID && f.AddresseeID == addresseeID) ||
			(f.RequesterID == addresseeID && f.AddresseeID == requesterID) {
			if f.Status == "accepted" {
				return nil, fmt.Errorf("already friends")
			}
			if f.Status == "pending" {
				return nil, fmt.Errorf("friend request already pending")
			}
		}
		if f.Status == "pending" {
			if f.RequesterID == requesterID {
				pendingSent++
			}
			if f.AddresseeID == addresseeID {
				pendingReceived++
			}
		}
	}

	if pendingSent >= 25 {
		return nil, fmt.Errorf("maximum pending friend request limit (25) reached")
	}
	if pendingReceived >= 50 {
		return nil, fmt.Errorf("target runner has reached maximum pending friend requests limit (50)")
	}

	id := fmt.Sprintf("friendship_%d", time.Now().UnixNano())
	now := time.Now().UTC()
	f := &Friendship{
		ID:          id,
		RequesterID: requesterID,
		AddresseeID: addresseeID,
		Status:      "pending",
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	m.friendships[id] = f
	cpy := *f
	return &cpy, nil
}

// RespondFriendRequest accepts or declines a pending friend request.
func (m *MemoryStore) RespondFriendRequest(ctx context.Context, friendshipID, userID, action string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	f, ok := m.friendships[friendshipID]
	if !ok {
		return fmt.Errorf("friend request not found: %s", friendshipID)
	}

	if f.AddresseeID != userID {
		return fmt.Errorf("unauthorized: only recipient can respond to friend request")
	}

	if f.Status != "pending" {
		return fmt.Errorf("request already %s", f.Status)
	}

	if action != "accept" && action != "decline" {
		return fmt.Errorf("invalid action: %s (must be 'accept' or 'decline')", action)
	}

	if action == "accept" {
		f.Status = "accepted"
	} else {
		f.Status = "declined"
	}
	f.UpdatedAt = time.Now().UTC()
	return nil
}

// GetFriends returns all accepted friends of the given user.
func (m *MemoryStore) GetFriends(ctx context.Context, userID string) ([]FriendUser, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var friends []FriendUser
	for _, f := range m.friendships {
		if f.Status != "accepted" {
			continue
		}
		var otherID string
		if f.RequesterID == userID {
			otherID = f.AddresseeID
		} else if f.AddresseeID == userID {
			otherID = f.RequesterID
		} else {
			continue
		}

		u, ok := m.users[otherID]
		if ok {
			friends = append(friends, FriendUser{
				ID:           u.ID,
				Username:     u.Username,
				Faction:      u.Faction,
				TotalAreaSqm: u.TotalAreaSqm,
				Level:        u.Level,
				XP:           u.XP,
				TotalRuns:    u.TotalRuns,
			})
		}
	}

	sort.Slice(friends, func(i, j int) bool {
		return friends[i].TotalAreaSqm > friends[j].TotalAreaSqm
	})

	return friends, nil
}

// GetFriendRequests returns all pending friend requests involving the user.
func (m *MemoryStore) GetFriendRequests(ctx context.Context, userID string) ([]FriendRequestDetail, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var details []FriendRequestDetail
	for _, f := range m.friendships {
		if f.Status != "pending" {
			continue
		}
		if f.RequesterID != userID && f.AddresseeID != userID {
			continue
		}

		reqUser := m.users[f.RequesterID]
		addUser := m.users[f.AddresseeID]

		reqName := f.RequesterID
		reqFaction := "Cyber Vanguard"
		if reqUser != nil {
			reqName = reqUser.Username
			reqFaction = reqUser.Faction
		}

		addName := f.AddresseeID
		if addUser != nil {
			addName = addUser.Username
		}

		details = append(details, FriendRequestDetail{
			ID:               f.ID,
			RequesterID:      f.RequesterID,
			RequesterName:    reqName,
			RequesterFaction: reqFaction,
			AddresseeID:      f.AddresseeID,
			AddresseeName:    addName,
			Status:           f.Status,
			CreatedAt:        f.CreatedAt,
			IsIncoming:       (f.AddresseeID == userID),
		})
	}

	sort.Slice(details, func(i, j int) bool {
		return details[i].CreatedAt.After(details[j].CreatedAt)
	})

	return details, nil
}

// CreateDuel initiates a new head-to-head duel challenge.
func (m *MemoryStore) CreateDuel(ctx context.Context, d *Duel) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if d.ChallengerID == d.OpponentID {
		return fmt.Errorf("cannot challenge yourself to a duel")
	}
	if strings.TrimSpace(d.OpponentID) == "" {
		return fmt.Errorf("opponent ID cannot be empty")
	}

	challenger, ok := m.users[d.ChallengerID]
	if !ok {
		return fmt.Errorf("challenger not found: %s", d.ChallengerID)
	}
	opponent, ok := m.users[d.OpponentID]
	if !ok {
		return fmt.Errorf("opponent not found: %s", d.OpponentID)
	}

	if d.ActivityType == "" {
		d.ActivityType = "running"
	}
	d.ActivityType = strings.ToLower(strings.TrimSpace(d.ActivityType))
	if d.ActivityType != "running" && d.ActivityType != "walking" && d.ActivityType != "cycling" {
		return fmt.Errorf("invalid activity type: %s", d.ActivityType)
	}

	// Validate XP Stake
	if d.XpStake < 0 || d.XpStake > 1000 {
		return fmt.Errorf("xp stake must be between 0 and 1000")
	}
	if d.XpStake == 0 {
		d.XpStake = 100
	}

	// Validate Target Type and Value
	if d.TargetType != "distance" {
		d.TargetType = "area"
	}
	if d.TargetType == "area" {
		if d.TargetValue <= 0 {
			d.TargetValue = 10000.0
		} else if d.TargetValue < 500.0 || d.TargetValue > 500000.0 {
			return fmt.Errorf("target value for area duel must be between 500 and 500,000 sqm")
		}
	} else {
		if d.TargetValue <= 0 {
			d.TargetValue = 5.0
		} else if d.TargetValue >= 100.0 {
			if d.TargetValue < 500.0 || d.TargetValue > 50000.0 {
				return fmt.Errorf("distance duel target must be between 500m (0.5km) and 50,000m (50km)")
			}
			d.TargetValue = d.TargetValue / 1000.0
		} else {
			if d.TargetValue < 0.5 || d.TargetValue > 50.0 {
				return fmt.Errorf("distance duel target must be between 0.5 and 50.0 km")
			}
		}
	}

	now := time.Now().UTC()
	var challengerActiveCount, challengerPendingCount, opponentPendingCount int
	for _, existing := range m.duels {
		isActive := existing.Status == "active" && !now.After(existing.ExpiresAt)
		isPending := existing.Status == "pending" && !now.After(existing.ExpiresAt)

		if (isActive || isPending) &&
			((existing.ChallengerID == d.ChallengerID && existing.OpponentID == d.OpponentID) ||
				(existing.ChallengerID == d.OpponentID && existing.OpponentID == d.ChallengerID)) {
			return fmt.Errorf("an active or pending duel already exists between these runners")
		}

		if isActive && (existing.ChallengerID == d.ChallengerID || existing.OpponentID == d.ChallengerID) {
			challengerActiveCount++
		}
		if isPending && existing.ChallengerID == d.ChallengerID {
			challengerPendingCount++
		}
		if isPending && existing.OpponentID == d.OpponentID {
			opponentPendingCount++
		}
	}

	if challengerActiveCount >= 5 {
		return fmt.Errorf("maximum active duel limit (5) reached")
	}
	if challengerPendingCount >= 10 {
		return fmt.Errorf("maximum pending duel challenge limit (10) reached")
	}
	if opponentPendingCount >= 10 {
		return fmt.Errorf("opponent has reached maximum pending duel challenges (10)")
	}

	d.ChallengerUsername = challenger.Username
	d.OpponentUsername = opponent.Username

	if d.ID == "" {
		d.ID = fmt.Sprintf("duel_%d", time.Now().UnixNano())
	}
	d.Status = "pending"
	d.CreatedAt = now
	if d.ExpiresAt.IsZero() {
		d.ExpiresAt = d.CreatedAt.Add(24 * time.Hour)
	}

	cpy := *d
	m.duels[d.ID] = &cpy
	return nil
}

// GetDuelsByUser retrieves active, pending, and recent duels involving the user.
func (m *MemoryStore) GetDuelsByUser(ctx context.Context, userID string) ([]Duel, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now().UTC()
	var duels []Duel

	for _, d := range m.duels {
		if d.ChallengerID != userID && d.OpponentID != userID {
			continue
		}

		// Check expiration for active or pending duels
		if (d.Status == "active" || d.Status == "pending") && now.After(d.ExpiresAt) {
			if d.Status == "active" {
				if d.ChallengerProgress > d.OpponentProgress {
					d.WinnerID = d.ChallengerID
					d.Status = "completed"
					if chUser, ok := m.users[d.ChallengerID]; ok {
						chUser.XP += int64(d.XpStake)
					}
				} else if d.OpponentProgress > d.ChallengerProgress {
					d.WinnerID = d.OpponentID
					d.Status = "completed"
					if opUser, ok := m.users[d.OpponentID]; ok {
						opUser.XP += int64(d.XpStake)
					}
				} else {
					d.Status = "expired"
				}
				completedTime := d.ExpiresAt
				d.CompletedAt = &completedTime
			} else {
				d.Status = "expired"
			}
		}

		duels = append(duels, *d)
	}

	sort.Slice(duels, func(i, j int) bool {
		return duels[i].CreatedAt.After(duels[j].CreatedAt)
	})

	return duels, nil
}

// AcceptDuel transitions a pending duel to active.
func (m *MemoryStore) AcceptDuel(ctx context.Context, duelID, userID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	d, ok := m.duels[duelID]
	if !ok {
		return fmt.Errorf("duel not found: %s", duelID)
	}

	if d.OpponentID != userID {
		return fmt.Errorf("unauthorized: only challenged opponent can accept duel")
	}

	if d.Status != "pending" {
		return fmt.Errorf("duel is %s (must be pending to accept)", d.Status)
	}

	if time.Now().UTC().After(d.ExpiresAt) {
		d.Status = "expired"
		return fmt.Errorf("duel invitation has expired")
	}

	d.Status = "active"
	d.ExpiresAt = time.Now().UTC().Add(24 * time.Hour) // 24 hours from acceptance
	return nil
}

// DeclineDuel marks a pending duel as declined.
func (m *MemoryStore) DeclineDuel(ctx context.Context, duelID, userID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	d, ok := m.duels[duelID]
	if !ok {
		return fmt.Errorf("duel not found: %s", duelID)
	}

	if d.OpponentID != userID {
		return fmt.Errorf("unauthorized: only challenged opponent can decline duel")
	}

	if d.Status != "pending" {
		return fmt.Errorf("duel is %s (must be pending to decline)", d.Status)
	}

	d.Status = "declined"
	return nil
}

// SetDuelExpiresAtForTest updates a duel's expiration time for testing.
func (m *MemoryStore) SetDuelExpiresAtForTest(duelID string, expiresAt time.Time) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if d, ok := m.duels[duelID]; ok {
		d.ExpiresAt = expiresAt
	}
}

// UpdateDuelProgress increments progress for any active duels involving userID matching the run's activity type.
func (m *MemoryStore) UpdateDuelProgress(ctx context.Context, userID, activityType string, areaDelta, distanceDelta float64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.updateDuelProgressLocked(userID, activityType, areaDelta, distanceDelta)
}

func (m *MemoryStore) updateDuelProgressLocked(userID, activityType string, areaDelta, distanceDelta float64) error {
	now := time.Now().UTC()
	activityType = strings.ToLower(strings.TrimSpace(activityType))
	if activityType == "" {
		activityType = "running"
	}

	for _, d := range m.duels {
		if d.Status != "active" {
			continue
		}
		if now.After(d.ExpiresAt) {
			continue
		}
		dAct := strings.ToLower(strings.TrimSpace(d.ActivityType))
		if dAct == "" {
			dAct = "running"
		}
		if dAct != activityType {
			continue
		}

		var progressIncrement float64
		if d.TargetType == "distance" {
			progressIncrement = distanceDelta / 1000.0 // in km
		} else {
			progressIncrement = areaDelta // in m²
		}

		if progressIncrement <= 0 {
			continue
		}

		if d.ChallengerID == userID {
			d.ChallengerProgress += progressIncrement
		} else if d.OpponentID == userID {
			d.OpponentProgress += progressIncrement
		} else {
			continue
		}

		// Check if target achieved
		if d.ChallengerProgress >= d.TargetValue {
			d.Status = "completed"
			d.WinnerID = d.ChallengerID
			completedAt := now
			d.CompletedAt = &completedAt
			if chUser, ok := m.users[d.ChallengerID]; ok {
				chUser.XP += int64(d.XpStake)
			}
		} else if d.OpponentProgress >= d.TargetValue {
			d.Status = "completed"
			d.WinnerID = d.OpponentID
			completedAt := now
			d.CompletedAt = &completedAt
			if opUser, ok := m.users[d.OpponentID]; ok {
				opUser.XP += int64(d.XpStake)
			}
		}
	}

	return nil
}

// GetPrivacyZones returns all privacy zones configured for a user.
func (m *MemoryStore) GetPrivacyZones(ctx context.Context, userID string) ([]PrivacyZone, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	zones, ok := m.privacyZones[userID]
	if !ok || len(zones) == 0 {
		return []PrivacyZone{}, nil
	}
	result := make([]PrivacyZone, len(zones))
	copy(result, zones)
	return result, nil
}

// SetPrivacyZones replaces all privacy zones for a user.
func (m *MemoryStore) SetPrivacyZones(ctx context.Context, userID string, zones []PrivacyZone) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if len(zones) == 0 {
		delete(m.privacyZones, userID)
		return nil
	}

	cloned := make([]PrivacyZone, len(zones))
	now := time.Now().UTC()
	for i, z := range zones {
		if z.CreatedAt.IsZero() {
			z.CreatedAt = now
		}
		z.UserID = userID
		cloned[i] = z
	}
	m.privacyZones[userID] = cloned
	return nil
}

// GetUserSettings returns user settings defaulting live_visibility to 'off'.
func (m *MemoryStore) GetUserSettings(ctx context.Context, userID string) (*UserSettings, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if s, ok := m.userSettings[userID]; ok && s != nil {
		return &UserSettings{LiveVisibility: s.LiveVisibility}, nil
	}
	if u, ok := m.users[userID]; ok && u != nil && u.LiveVisibility != "" {
		return &UserSettings{LiveVisibility: u.LiveVisibility}, nil
	}
	return &UserSettings{LiveVisibility: "off"}, nil
}

// UpdateUserSettings updates user settings.
func (m *MemoryStore) UpdateUserSettings(ctx context.Context, userID string, settings *UserSettings) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	vis := "off"
	if settings != nil && settings.LiveVisibility != "" {
		vis = settings.LiveVisibility
	}

	m.userSettings[userID] = &UserSettings{LiveVisibility: vis}
	if u, ok := m.users[userID]; ok && u != nil {
		u.LiveVisibility = vis
	}
	return nil
}
