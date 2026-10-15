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
	mu          sync.Mutex
	users       map[string]*User
	runs        map[string]*Run
	runsByOrder []string
	territories map[string]*Territory
}

// NewMemoryStore initializes an in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:       make(map[string]*User),
		runs:        make(map[string]*Run),
		runsByOrder: make([]string, 0),
		territories: make(map[string]*Territory),
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
			ID:        tID,
			OwnerID:   run.UserID,
			Username:  user.Username,
			GeoJSON:   geojson,
			AreaSqm:   playerTotalArea,
			UpdatedAt: time.Now().UTC(),
		}
	} else {
		user.TotalRuns++
		user.UpdatedAt = time.Now().UTC()
		playerTotalArea = user.TotalAreaSqm
	}

	runCopy := *run
	runCopy.AreaClaimed = areaClaimed
	runCopy.CreatedAt = time.Now().UTC()
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
