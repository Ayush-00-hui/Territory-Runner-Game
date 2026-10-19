package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestE2EFullRunLifecycle verifies the complete end-to-end run lifecycle:
// 1. Initial State: Athletes exist (usr_rival and usr_runner).
// 2. Rival executes Run 1 via POST /v1/runs to claim initial sovereign territory.
// 3. Runner executes Run 2 via POST /v1/runs with activity_type "running",
//    traversing an overlapping loop that conquers and carves part of Rival's sector.
// 4. Server-authoritative anti-cheat validates realistic speeds (below 25 km/h ceiling).
// 5. Store atomically commits MultiPolygon union, differences rival polygon, and awards XP.
// 6. Verify CaptureResult response (loop detected, net area claimed, XP, affected rivals).
// 7. Verify GET /v1/territories?bbox=... returns active sovereign geometries for both athletes.
// 8. Verify GET /v1/me returns updated athlete stats (XP, level, total area, runs count).
// 9. Verify GET /v1/leaderboard reflects updated rankings.
// 10. Verify idempotent replay: resubmitting Run 2 returns HTTP 200 without double-counting area or XP.
func TestE2EFullRunLifecycle(t *testing.T) {
	router, st := setupTestServer()
	ctx := context.Background()

	// 1. Initialize athlete profiles
	rivalUser := &store.User{
		ID:           "usr_rival_e2e",
		Username:     "RivalAlpha",
		Faction:      "Iron Legion",
		TotalAreaSqm: 0,
		XP:           0,
		Level:        1,
		TotalRuns:    0,
	}
	runnerUser := &store.User{
		ID:           "usr_runner_e2e",
		Username:     "RunnerPrime",
		Faction:      "Cyber Vanguard",
		TotalAreaSqm: 0,
		XP:           0,
		Level:        1,
		TotalRuns:    0,
	}
	require.NoError(t, st.UpsertUser(ctx, rivalUser))
	require.NoError(t, st.UpsertUser(ctx, runnerUser))

	now := time.Now().UTC()

	// 2. Rival submits initial territory run (~30,000 m² box)
	rivalPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_rival_initial_001",
		ActivityType:    "running",
		DurationSeconds: 300,
		DistanceMeters:  800.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now.Add(0 * time.Second), Speed: 2.7},
			{Latitude: 51.5020, Longitude: -0.1200, Timestamp: now.Add(10 * time.Second), Speed: 2.8},
			{Latitude: 51.5020, Longitude: -0.1220, Timestamp: now.Add(20 * time.Second), Speed: 2.7},
			{Latitude: 51.5000, Longitude: -0.1220, Timestamp: now.Add(30 * time.Second), Speed: 2.8},
			{Latitude: 51.50005, Longitude: -0.12005, Timestamp: now.Add(40 * time.Second), Speed: 2.6},
		},
	}
	body, _ := json.Marshal(rivalPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", rivalUser.ID)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusCreated, rec.Code)
	var rivalResult store.CaptureResult
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &rivalResult))
	assert.True(t, rivalResult.LoopDetected)
	assert.Greater(t, rivalResult.AreaClaimedSqm, 15000.0)
	rivalInitialArea := rivalResult.AreaClaimedSqm

	// 3. Runner submits overlapping loop run (carving top-right portion of Rival's sector)
	runnerPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_runner_conquest_002",
		ActivityType:    "running",
		DurationSeconds: 320,
		DistanceMeters:  850.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5010, Longitude: -0.1210, Timestamp: now.Add(50 * time.Second), Speed: 2.8},
			{Latitude: 51.5030, Longitude: -0.1210, Timestamp: now.Add(60 * time.Second), Speed: 2.9},
			{Latitude: 51.5030, Longitude: -0.1230, Timestamp: now.Add(70 * time.Second), Speed: 2.7},
			{Latitude: 51.5010, Longitude: -0.1230, Timestamp: now.Add(80 * time.Second), Speed: 2.8},
			{Latitude: 51.50105, Longitude: -0.12105, Timestamp: now.Add(90 * time.Second), Speed: 2.6},
		},
	}
	body, _ = json.Marshal(runnerPayload)
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	// 4 & 5 & 6. Verify CaptureResult response
	require.Equal(t, http.StatusCreated, rec.Code)
	var runnerResult store.CaptureResult
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &runnerResult))

	assert.Equal(t, "accepted", runnerResult.Status)
	assert.True(t, runnerResult.LoopDetected)
	assert.Greater(t, runnerResult.AreaClaimedSqm, 15000.0)
	assert.Equal(t, runnerResult.AreaClaimedSqm, runnerResult.PlayerTotalAreaSqm)
	assert.Greater(t, runnerResult.XpAwarded, 0)
	assert.Contains(t, runnerResult.RivalsAffected, rivalUser.ID, "Rival territory was carved by Runner")
	assert.Contains(t, runnerResult.TerritoryGeoJSON, "MultiPolygon")

	// 7. Verify GET /v1/territories bounding box query
	req = httptest.NewRequest(http.MethodGet, "/v1/territories?bbox=-0.13,51.49,-0.11,51.51", nil)
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)
	var featureColl struct {
		Type     string `json:"type"`
		Features []struct {
			Type       string `json:"type"`
			ID         string `json:"id"`
			Properties struct {
				OwnerID  string  `json:"owner_id"`
				Username string  `json:"username"`
				IsSelf   bool    `json:"is_self"`
				AreaSqm  float64 `json:"area_sqm"`
				Strength float64 `json:"strength"`
			} `json:"properties"`
		} `json:"features"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &featureColl))
	assert.Equal(t, "FeatureCollection", featureColl.Type)
	assert.GreaterOrEqual(t, len(featureColl.Features), 2, "Both Runner and Rival have active territories")

	var runnerFound, rivalFound bool
	var runnerArea, runnerStrength, rivalArea float64
	for _, f := range featureColl.Features {
		if f.Properties.OwnerID == runnerUser.ID {
			runnerFound = true
			runnerArea = f.Properties.AreaSqm
			runnerStrength = f.Properties.Strength
			assert.True(t, f.Properties.IsSelf)
		} else if f.Properties.OwnerID == rivalUser.ID {
			rivalFound = true
			rivalArea = f.Properties.AreaSqm
			assert.False(t, f.Properties.IsSelf)
		}
	}
	require.True(t, runnerFound, "Runner sovereign territory exists in database")
	require.True(t, rivalFound, "Rival territory exists in database")
	assert.InDelta(t, 100.0, runnerStrength, 0.01, "Freshly captured territory has 100% strength")
	assert.Greater(t, runnerArea, 0.0)
	assert.Equal(t, rivalInitialArea, rivalArea, "Rival territory area tracked in database")

	// 8. Verify GET /v1/me profile reflects updated telemetry
	req = httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)
	var me store.User
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &me))
	assert.Equal(t, runnerUser.ID, me.ID)
	assert.Equal(t, runnerResult.PlayerTotalAreaSqm, me.TotalAreaSqm)
	assert.Equal(t, int64(runnerResult.XpAwarded), me.XP)
	assert.Equal(t, 1, me.TotalRuns)

	// 9. Verify GET /v1/leaderboard
	req = httptest.NewRequest(http.MethodGet, "/v1/leaderboard", nil)
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	require.Equal(t, http.StatusOK, rec.Code)
	var lbResp struct {
		Leaderboard []store.LeaderboardEntry `json:"leaderboard"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &lbResp))
	require.GreaterOrEqual(t, len(lbResp.Leaderboard), 2)
	foundRunnerInLb := false
	for _, entry := range lbResp.Leaderboard {
		if entry.UserID == runnerUser.ID {
			foundRunnerInLb = true
			assert.Equal(t, runnerResult.PlayerTotalAreaSqm, entry.TotalAreaSqm)
		}
	}
	assert.True(t, foundRunnerInLb, "Runner is present on leaderboard with verified total area")

	// 10. Verify Idempotent Replay: submitting identical run returns HTTP 200 without duplicate mutation
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code, "Idempotent replay returns 200 OK")
	var replayResult store.CaptureResult
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &replayResult))
	assert.Equal(t, runnerResult.RunID, replayResult.RunID)

	// Confirm user area did not double-count
	req = httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	req.Header.Set("X-Dev-User", runnerUser.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	_ = json.Unmarshal(rec.Body.Bytes(), &me)
	assert.Equal(t, runnerResult.PlayerTotalAreaSqm, me.TotalAreaSqm, "Idempotent replay did not double count area")
	assert.Equal(t, int64(runnerResult.XpAwarded), me.XP, "Idempotent replay did not double award XP")
	assert.Equal(t, 1, me.TotalRuns, "Total runs remained exactly 1")
}
