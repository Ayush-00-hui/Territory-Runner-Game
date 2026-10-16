package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestServer() (http.Handler, store.Store) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	wsHub := ws.NewHub(nil)
	go wsHub.Run()
	apiHandler := api.NewAPI(memStore, nil,
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(authenticator),
	)
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

func TestSubmitRunLassoCrossingKeepsValidLoop(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	// Run containing 1 valid lasso loop plus a path crossing: must keep the valid loop!
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_lasso_cross_001",
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
	req.Header.Set("X-Dev-User", "ayush_runner_lasso")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusCreated, rec.Code, "Run with valid loop plus path crossing must keep valid loop")
	var res store.CaptureResult
	_ = json.Unmarshal(rec.Body.Bytes(), &res)
	assert.True(t, res.LoopDetected)
	assert.Greater(t, res.AreaClaimedSqm, 0.0)
	assert.Greater(t, res.XpAwarded, 0)
}

func TestSubmitRunPureFigure8Rejected(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	// Pure figure-8 that self-intersects and forms NO valid loop (perimeters < 40m)
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_fig8_pure_001",
		DurationSeconds: 120,
		DistanceMeters:  64.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.50000, Longitude: -0.12000, Timestamp: now},
			{Latitude: 51.50016, Longitude: -0.12016, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.50016, Longitude: -0.12000, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.50000, Longitude: -0.12016, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.50000, Longitude: -0.12000, Timestamp: now.Add(4 * time.Minute)},
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

func TestSubmitRunTwoLoopsAwardXPForBoth(t *testing.T) {
	router, _ := setupTestServer()

	now := time.Now().UTC()
	// Single run sequence with 2 valid enclosed loops: awards XP for BOTH and unions BOTH
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_twoloops_001",
		DurationSeconds: 600,
		DistanceMeters:  700.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.50000, Longitude: -0.12000, Timestamp: now},
			{Latitude: 51.50080, Longitude: -0.12000, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.50080, Longitude: -0.12120, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.50000, Longitude: -0.12120, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.50001, Longitude: -0.12001, Timestamp: now.Add(4 * time.Minute)},
			{Latitude: 51.50000, Longitude: -0.11900, Timestamp: now.Add(5 * time.Minute)},
			{Latitude: 51.50080, Longitude: -0.11900, Timestamp: now.Add(6 * time.Minute)},
			{Latitude: 51.50080, Longitude: -0.11780, Timestamp: now.Add(7 * time.Minute)},
			{Latitude: 51.50000, Longitude: -0.11780, Timestamp: now.Add(8 * time.Minute)},
			{Latitude: 51.50001, Longitude: -0.11899, Timestamp: now.Add(9 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "ayush_runner_two_loops")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusCreated, rec.Code)
	var res store.CaptureResult
	_ = json.Unmarshal(rec.Body.Bytes(), &res)
	assert.True(t, res.LoopDetected)
	assert.InDelta(t, 14718.6, res.AreaClaimedSqm, 100.0)
	// XP for both loops: max(100, round(14718.6/20.0)) = 736
	assert.Equal(t, 736, res.XpAwarded)
	assert.Equal(t, res.AreaClaimedSqm, res.PlayerTotalAreaSqm)
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

func TestWebSocketEndpoint(t *testing.T) {
	router, _ := setupTestServer()
	ts := httptest.NewServer(router)
	defer ts.Close()

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/v1/ws?dev_user=ws_tester"

	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	defer conn.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)

	// Send presence update
	msg := ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.502,
		Longitude: -0.122,
		Speed:     3.0,
		Heading:   45.0,
	}
	err = conn.WriteJSON(msg)
	require.NoError(t, err)

	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, p, err := conn.ReadMessage()
	require.NoError(t, err)

	var presence ws.PresenceMessage
	err = json.Unmarshal(p, &presence)
	require.NoError(t, err)
	assert.Equal(t, ws.TypeRunnerPresence, presence.Type)
	assert.Equal(t, "ws_tester", presence.UserID)
	assert.Equal(t, 51.502, presence.Latitude)
}

func TestSubmitRun_NonMonotonicTimestampsRejected(t *testing.T) {
	router, _ := setupTestServer()
	now := time.Now().UTC()

	// Point 3 timestamp is before point 2 timestamp
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_non_monotonic_001",
		DurationSeconds: 300,
		DistanceMeters:  400.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(1 * time.Minute)}, // non-monotonic!
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(4 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "runner_chrono")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "NON_MONOTONIC_TIMESTAMPS", errResp["error"])
	assert.Contains(t, errResp["detail"], "monotonically")
}

func TestSubmitRun_ExceedsMaxPointsCap(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	// Cap max points to 4
	apiHandler := api.NewAPI(memStore, nil,
		api.WithAuthenticator(authenticator),
		api.WithLimits(4, 86400),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_too_many_points",
		DurationSeconds: 300,
		DistanceMeters:  400.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(4 * time.Minute)}, // 5th point exceeds limit of 4
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "runner_overflow")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "TOO_MANY_POINTS", errResp["error"])
	assert.Contains(t, errResp["detail"], "exceeds maximum allowed track points")
}

func TestSubmitRun_ExceedsMaxDuration(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	// Max duration 1800 seconds (30 minutes)
	apiHandler := api.NewAPI(memStore, nil,
		api.WithAuthenticator(authenticator),
		api.WithLimits(20000, 1800),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_duration_exceeded",
		DurationSeconds: 3600, // 60 minutes exceeds 30 min limit
		DistanceMeters:  400.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(2 * time.Minute)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute)},
		},
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "runner_duration")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "INVALID_DURATION", errResp["error"])
}

func TestSubmitRun_InsufficientPoints(t *testing.T) {
	router, _ := setupTestServer()
	now := time.Now().UTC()

	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_insufficient_pts",
		DurationSeconds: 100,
		DistanceMeters:  100.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now},
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute)},
		}, // Only 2 points
	}

	body, _ := json.Marshal(runPayload)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "runner_two_pts")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "INSUFFICIENT_POINTS", errResp["error"])
}

func TestSubmitRun_PayloadTooLarge(t *testing.T) {
	router, _ := setupTestServer()

	// Construct payload larger than 2 MB
	hugePadding := strings.Repeat("A", 2*1024*1024+100)
	rawJSON := fmt.Sprintf(`{"idempotency_key":"idem_huge","padding":"%s"}`, hugePadding)

	req := httptest.NewRequest(http.MethodPost, "/v1/runs", strings.NewReader(rawJSON))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "runner_huge")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusRequestEntityTooLarge, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "PAYLOAD_TOO_LARGE", errResp["error"])
}

func TestRunsEndpoint_RateLimiting(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)

	// Rate limiter with capacity 1 and very slow refill (0.01 tokens/sec)
	strictLimiter := api.NewRateLimiter(0.01, 1)
	defer strictLimiter.Close()

	apiHandler := api.NewAPI(memStore, nil,
		api.WithAuthenticator(authenticator),
		api.WithRateLimiters(strictLimiter, nil),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_ratelimit_1",
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

	// Request 1: within capacity -> 201 Created
	req1 := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("X-Dev-User", "ratelimited_runner")
	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, req1)
	assert.Equal(t, http.StatusCreated, rec1.Code)

	// Request 2: exceeded capacity -> 429 Too Many Requests
	runPayload.IdempotencyKey = "idem_ratelimit_2"
	body2, _ := json.Marshal(runPayload)
	req2 := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body2))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("X-Dev-User", "ratelimited_runner")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)

	assert.Equal(t, http.StatusTooManyRequests, rec2.Code)
	assert.NotEmpty(t, rec2.Header().Get("Retry-After"))
	var errResp map[string]interface{}
	_ = json.Unmarshal(rec2.Body.Bytes(), &errResp)
	assert.Equal(t, "RATE_LIMIT_EXCEEDED", errResp["error"])
	assert.NotNil(t, errResp["retry_after"])
}

func TestCoachEndpoint_RateLimiting(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)

	strictCoachLimiter := api.NewRateLimiter(0.01, 1)
	defer strictCoachLimiter.Close()

	apiHandler := api.NewAPI(memStore, nil,
		api.WithAuthenticator(authenticator),
		api.WithRateLimiters(nil, strictCoachLimiter),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	req1 := httptest.NewRequest(http.MethodPost, "/v1/runs/run_coach_limit/coach", strings.NewReader(`{}`))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("X-Dev-User", "coach_limit_user")
	rec1 := httptest.NewRecorder()
	router.ServeHTTP(rec1, req1)
	assert.Equal(t, http.StatusOK, rec1.Code)

	// Second request immediately exceeds capacity of 1
	req2 := httptest.NewRequest(http.MethodPost, "/v1/runs/run_coach_limit/coach", strings.NewReader(`{}`))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("X-Dev-User", "coach_limit_user")
	rec2 := httptest.NewRecorder()
	router.ServeHTTP(rec2, req2)

	assert.Equal(t, http.StatusTooManyRequests, rec2.Code)
	assert.NotEmpty(t, rec2.Header().Get("Retry-After"))
}

func TestWebSocketOriginValidation(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)

	// Hub restricted to https://app.territoryrunner.com
	wsHub := ws.NewHub(nil, ws.WithAllowedOrigins([]string{"https://app.territoryrunner.com"}))
	go wsHub.Run()
	defer wsHub.Stop()

	apiHandler := api.NewAPI(memStore, nil,
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(authenticator),
	)
	router := api.SetupRouter(apiHandler, authenticator, "https://app.territoryrunner.com")
	ts := httptest.NewServer(router)
	defer ts.Close()

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/v1/ws?dev_user=origin_tester"

	// 1. Mobile client without Origin header must connect successfully
	conn1, resp1, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	conn1.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, resp1.StatusCode)

	// 2. Whitelisted origin connects successfully
	headersAllowed := http.Header{"Origin": []string{"https://app.territoryrunner.com"}}
	conn2, resp2, err := websocket.DefaultDialer.Dial(wsURL, headersAllowed)
	require.NoError(t, err)
	conn2.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, resp2.StatusCode)

	// 3. Rogue origin is rejected
	headersBlocked := http.Header{"Origin": []string{"https://evil-unauthorized-site.com"}}
	_, resp3, err := websocket.DefaultDialer.Dial(wsURL, headersBlocked)
	assert.Error(t, err)
	if resp3 != nil {
		assert.Equal(t, http.StatusForbidden, resp3.StatusCode)
	}
}

