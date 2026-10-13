package api_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestServer() (http.Handler, store.Store) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(memStore, nil)
	router := api.SetupRouter(apiHandler, authenticator)
	return router, memStore
}

func TestHealthzEndpoint(t *testing.T) {
	router, _ := setupTestServer()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "ok", resp["status"])
	assert.Contains(t, resp["database"], "connected")
}

func TestSubmitRunValidLoop(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_run_valid_001",
		DurationSeconds: 400,
		DistanceMeters:  450.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(4 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "ayush_runner_99")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusCreated, rec.Code)
	var res store.CaptureResult
	err := json.Unmarshal(rec.Body.Bytes(), &res)
	require.NoError(t, err)

	assert.True(t, res.LoopDetected)
	assert.Greater(t, res.AreaClaimedSqm, 5000.0)
	assert.Equal(t, res.AreaClaimedSqm, res.PlayerTotalAreaSqm)
	assert.NotEmpty(t, res.RunID)
}

func TestDuplicateIdempotencyKeyDoesNotDoubleCount(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_run_duplicate_test",
		DurationSeconds: 300,
		DistanceMeters:  400.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(4 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)

	// First execution
	req1 := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("X-Dev-User", "ayush_runner_idem")
	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, req1)
	assert.Equal(t, http.StatusCreated, rec1.Code)

	var res1 store.CaptureResult
	_ = json.Unmarshal(rec1.Body.Bytes(), &res1)

	// Second execution with identical idempotency key
	req2 := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("X-Dev-User", "ayush_runner_idem")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)
	assert.Equal(t, http.StatusOK, rec2.Code)

	var res2 store.CaptureResult
	_ = json.Unmarshal(rec2.Body.Bytes(), &res2)

	assert.Equal(t, res1.RunID, res2.RunID)
	assert.Equal(t, res1.AreaClaimedSqm, res2.AreaClaimedSqm)
	assert.Equal(t, res1.PlayerTotalAreaSqm, res2.PlayerTotalAreaSqm, "Player area must not double count on replay")
}

func TestSubmitRunFigure8Rejected(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	// Figure 8 intersecting in the center
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_fig8_001",
		DurationSeconds: 300,
		DistanceMeters:  400.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5010, Longitude: -0.1210, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.5010, Longitude: -0.1200, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1210, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now.Add(4 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "ayush_runner_fig8")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "INVALID_LOOP", errResp["error"])
	assert.Contains(t, errResp["detail"], "Loop crossed itself — try again")
}

func TestGetTerritoriesGeoJSON(t *testing.T) {
	router, _ := setupTestServer()

	req := httptest.NewRequest(http.MethodGet, "/v1/territories?bbox=-0.13,51.49,-0.11,51.51", nil)
	req.Header.Set("X-Dev-User", "test_user")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var featColl map[string]interface{}
	err := json.Unmarshal(rec.Body.Bytes(), &featColl)
	require.NoError(t, err)
	assert.Equal(t, "FeatureCollection", featColl["type"])
	assert.NotNil(t, featColl["features"])
}

func TestGetMeProfile(t *testing.T) {
	router, _ := setupTestServer()

	req := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	req.Header.Set("X-Dev-User", "profile_tester")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var u store.User
	err := json.Unmarshal(rec.Body.Bytes(), &u)
	require.NoError(t, err)
	assert.Equal(t, "profile_tester", u.ID)
	assert.Equal(t, "Cyber Vanguard", u.Faction)
}

func TestRunCoachEndpoint(t *testing.T) {
	router, _ := setupTestServer()

	coachReq := map[string]interface{}{
		"distance_km":      3.8,
		"duration_seconds": 1320,
		"hexes_claimed":    5,
		"current_pace":     "5'47\"/km",
	}
	body, _ := json.Marshal(coachReq)

	req := httptest.NewRequest(http.MethodPost, "/v1/runs/run_test_coach_99/coach", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "coach_runner")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]interface{}
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	assert.NotEmpty(t, resp["summary"])
	assert.Contains(t, resp["summary"], "3.80 km")
	assert.NotEmpty(t, resp["tip"])
	assert.NotEmpty(t, resp["mood_tag"])
}
