package api_test

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
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
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify"
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
	wsHub := ws.NewHub(nil, ws.WithPresenceDelay(0))
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
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(10 * time.Second)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(20 * time.Second)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(30 * time.Second)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(40 * time.Second)},
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
			{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(10 * time.Second)},
			{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(20 * time.Second)},
			{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(30 * time.Second)},
			{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(40 * time.Second)},
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
			{Latitude: 51.5010, Longitude: -0.1210, Timestamp: now.Add(10 * time.Second)},
			{Latitude: 51.5010, Longitude: -0.1200, Timestamp: now.Add(20 * time.Second)},
			{Latitude: 51.5000, Longitude: -0.1210, Timestamp: now.Add(30 * time.Second)},
			{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now.Add(40 * time.Second)},
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
			{Latitude: 51.50016, Longitude: -0.12016, Timestamp: now.Add(10 * time.Second)},
			{Latitude: 51.50016, Longitude: -0.12000, Timestamp: now.Add(20 * time.Second)},
			{Latitude: 51.50000, Longitude: -0.12016, Timestamp: now.Add(30 * time.Second)},
			{Latitude: 51.50000, Longitude: -0.12000, Timestamp: now.Add(40 * time.Second)},
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
			{Latitude: 51.50080, Longitude: -0.12000, Timestamp: now.Add(10 * time.Second)},
			{Latitude: 51.50080, Longitude: -0.12120, Timestamp: now.Add(20 * time.Second)},
			{Latitude: 51.50000, Longitude: -0.12120, Timestamp: now.Add(30 * time.Second)},
			{Latitude: 51.50001, Longitude: -0.12001, Timestamp: now.Add(40 * time.Second)},
			{Latitude: 51.50000, Longitude: -0.11900, Timestamp: now.Add(50 * time.Second)},
			{Latitude: 51.50080, Longitude: -0.11900, Timestamp: now.Add(60 * time.Second)},
			{Latitude: 51.50080, Longitude: -0.11780, Timestamp: now.Add(70 * time.Second)},
			{Latitude: 51.50000, Longitude: -0.11780, Timestamp: now.Add(80 * time.Second)},
			{Latitude: 51.50001, Longitude: -0.11899, Timestamp: now.Add(90 * time.Second)},
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
	router, st := setupTestServer()
	ts := httptest.NewServer(router)
	defer ts.Close()

	ctx := context.Background()
	_ = st.UpdateUserSettings(ctx, "ws_sender", &store.UserSettings{LiveVisibility: "nearby"})

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/v1/ws"

	// Sender connects
	connSender, resp, err := websocket.DefaultDialer.Dial(wsURL+"?dev_user=ws_sender", nil)
	require.NoError(t, err)
	defer connSender.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)

	// Receiver connects
	connReceiver, resp, err := websocket.DefaultDialer.Dial(wsURL+"?dev_user=ws_receiver", nil)
	require.NoError(t, err)
	defer connReceiver.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)

	// Receiver subscribes to cell
	cell := geo.GeohashPrecision6(51.502, -0.122)
	err = connReceiver.WriteJSON(ws.InboundMessage{
		Type:  ws.TypeViewportSubscribe,
		Cells: []string{cell},
	})
	require.NoError(t, err)
	time.Sleep(50 * time.Millisecond)

	// Sender sends presence update
	msg := ws.InboundMessage{
		Type:      ws.TypePresenceUpdate,
		Latitude:  51.502,
		Longitude: -0.122,
		Speed:     3.0,
		Heading:   45.0,
	}
	err = connSender.WriteJSON(msg)
	require.NoError(t, err)

	_ = connReceiver.SetReadDeadline(time.Now().Add(1 * time.Second))
	_, p, err := connReceiver.ReadMessage()
	require.NoError(t, err)

	var presence ws.PresenceMessage
	err = json.Unmarshal(p, &presence)
	require.NoError(t, err)
	assert.Equal(t, ws.TypeRunnerPresence, presence.Type)
	assert.Equal(t, "ws_sender", presence.UserID)
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

func TestRegisterDeviceToken(t *testing.T) {
	router, memStore := setupTestServer()

	// 1. Success registration
	body := bytes.NewBufferString(`{"token": "fcm_device_token_abc_123"}`)
	req := httptest.NewRequest(http.MethodPost, "/v1/device-token", body)
	req.Header.Set("X-Dev-User", "runner_device_tester")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var resp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "registered", resp["status"])
	assert.Equal(t, "fcm_device_token_abc_123", resp["token"])

	tokens, err := memStore.GetDeviceTokens(req.Context(), "runner_device_tester")
	require.NoError(t, err)
	assert.Contains(t, tokens, "fcm_device_token_abc_123")

	// 2. Empty token rejected
	emptyBody := bytes.NewBufferString(`{"token": "   "}`)
	req2 := httptest.NewRequest(http.MethodPost, "/v1/device-token", emptyBody)
	req2.Header.Set("X-Dev-User", "runner_device_tester")
	req2.Header.Set("Content-Type", "application/json")
	rec2 := httptest.NewRecorder()

	router.ServeHTTP(rec2, req2)
	assert.Equal(t, http.StatusBadRequest, rec2.Code)
}

func TestGetCurrentLeague(t *testing.T) {
	router, memStore := setupTestServer()
	ctx := context.Background()

	// Seed multiple runner profiles and accepted runs in the active week
	_ = memStore.UpsertUser(ctx, &store.User{ID: "athlete_gold", Username: "SpeedyGold", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "athlete_silver", Username: "SwiftSilver", Faction: "Neon Syndicate"})

	runTime := time.Now().UTC().Add(-1 * time.Hour)
	_, _ = memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_seed_01",
		UserID:         "athlete_gold",
		IdempotencyKey: "idem_seed_01",
		CreatedAt:      runTime,
	}, []geo.EnclosedLoop{{AreaSqMeters: 15000.0}}, nil)

	_, _ = memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_seed_02",
		UserID:         "athlete_silver",
		IdempotencyKey: "idem_seed_02",
		CreatedAt:      runTime,
	}, []geo.EnclosedLoop{{AreaSqMeters: 5000.0}}, nil)

	req := httptest.NewRequest(http.MethodGet, "/v1/league/current", nil)
	req.Header.Set("X-Dev-User", "athlete_gold")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var standing store.LeagueStanding
	err := json.Unmarshal(rec.Body.Bytes(), &standing)
	require.NoError(t, err)

	assert.Equal(t, "athlete_gold", standing.UserID)
	assert.Equal(t, 1, standing.Rank)
	assert.Equal(t, 15000.0, standing.WeeklyAreaSqm)
	assert.True(t, standing.SecondsUntilReset > 0)
	assert.NotEmpty(t, standing.Standings)
}

func TestConquestTriggersFCMAlert(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	mockNotifier := notify.NewMockNotifier()

	apiHandler := api.NewAPI(memStore, nil,
		api.WithNotifier(mockNotifier),
		api.WithAuthenticator(authenticator),
	)
	router := api.SetupRouter(apiHandler, authenticator)
	ctx := context.Background()

	// Seed victim user and existing territory
	victimUID := "victim_runner_99"
	_ = memStore.UpsertUser(ctx, &store.User{ID: victimUID, Username: "VictimBob", Faction: "Neon Syndicate"})
	_, _ = memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_victim_init",
		UserID:         victimUID,
		IdempotencyKey: "idem_victim_init",
		CreatedAt:      time.Now().UTC(),
	}, []geo.EnclosedLoop{{
		AreaSqMeters: 4000.0,
		Polygon: []geo.LatLng{
			{Latitude: 51.500, Longitude: -0.120},
			{Latitude: 51.505, Longitude: -0.120},
			{Latitude: 51.505, Longitude: -0.115},
			{Latitude: 51.500, Longitude: -0.115},
			{Latitude: 51.500, Longitude: -0.120},
		},
	}}, nil)

	// Submitting a conquest run overlapping victim's territory
	now := time.Now().UTC()
	runPayload := api.SubmitRunRequest{
		IdempotencyKey:  "idem_attacker_conquest",
		DurationSeconds: 400,
		DistanceMeters:  2000.0,
		Points: []geo.TrackPoint{
			{Latitude: 51.498, Longitude: -0.122, Timestamp: now.Add(-40 * time.Second)},
			{Latitude: 51.507, Longitude: -0.122, Timestamp: now.Add(-30 * time.Second)},
			{Latitude: 51.507, Longitude: -0.113, Timestamp: now.Add(-20 * time.Second)},
			{Latitude: 51.498, Longitude: -0.113, Timestamp: now.Add(-10 * time.Second)},
			{Latitude: 51.498, Longitude: -0.122, Timestamp: now},
		},
	}
	body, _ := json.Marshal(runPayload)

	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "attacker_alice")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	// Wait briefly for asynchronous notification goroutine
	time.Sleep(50 * time.Millisecond)

	// Assert that victim received push notification alert
	assert.GreaterOrEqual(t, mockNotifier.TotalAlerts(), 1)
	assert.Equal(t, victimUID, mockNotifier.SentAlerts[0].UserID)
}

func TestGetFactionStandings(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(memStore, nil, api.WithAuthenticator(authenticator))
	router := api.SetupRouter(apiHandler, authenticator)

	// Set up users in two factions
	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_vanguard", Username: "VanguardLead", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_syndicate", Username: "SyndicateLead", Faction: "Neon Syndicate"})

	// Award territory to vanguard
	_, _ = memStore.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_van_01",
		UserID:         "usr_vanguard",
		IdempotencyKey: "idem_van_01",
	}, []geo.EnclosedLoop{{AreaSqMeters: 50000.0}}, nil)

	req := httptest.NewRequest(http.MethodGet, "/v1/factions/standings", nil)
	req.Header.Set("X-Dev-User", "usr_vanguard")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var resp store.FactionStandingsResponse
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	assert.NoError(t, err)
	assert.Equal(t, 50000.0, resp.TotalAreaSqm)
	assert.Len(t, resp.Standings, 3) // All 3 canonical factions
	assert.Equal(t, "Cyber Vanguard", resp.Standings[0].Faction)
	assert.Equal(t, 100.0, resp.Standings[0].Percentage)
}

func TestUpdateUserFaction(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(memStore, nil, api.WithAuthenticator(authenticator))
	router := api.SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_nomad", Username: "NomadRunner", Faction: "Cyber Vanguard"})

	body, _ := json.Marshal(map[string]string{"faction": "Solaris Nomads"})
	req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_nomad")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	// Verify updated in store
	user, err := memStore.GetUser(ctx, "usr_nomad")
	assert.NoError(t, err)
	assert.Equal(t, "Solaris Nomads", user.Faction)
}

func TestFriendsEndpoints(t *testing.T) {
	router, memStore := setupTestServer()
	ctx := context.Background()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard", TotalAreaSqm: 40000.0})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion", TotalAreaSqm: 25000.0})

	// 1. Send friend request: Alice -> Bob
	body, _ := json.Marshal(map[string]string{"target_user_id": "usr_bob"})
	req := httptest.NewRequest(http.MethodPost, "/v1/friends/request", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	var f store.Friendship
	err := json.Unmarshal(rec.Body.Bytes(), &f)
	require.NoError(t, err)
	assert.Equal(t, "pending", f.Status)

	// 2. Bob gets requests
	req = httptest.NewRequest(http.MethodGet, "/v1/friends/requests", nil)
	req.Header.Set("X-Dev-User", "usr_bob")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var reqs []store.FriendRequestDetail
	err = json.Unmarshal(rec.Body.Bytes(), &reqs)
	require.NoError(t, err)
	require.Len(t, reqs, 1)
	assert.True(t, reqs[0].IsIncoming)
	assert.Equal(t, "Alice", reqs[0].RequesterName)

	// 3. Bob accepts request
	actionBody, _ := json.Marshal(map[string]string{"action": "accept"})
	req = httptest.NewRequest(http.MethodPut, "/v1/friends/request/"+f.ID, bytes.NewReader(actionBody))
	req.Header.Set("X-Dev-User", "usr_bob")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	// 4. Alice gets friends
	req = httptest.NewRequest(http.MethodGet, "/v1/friends", nil)
	req.Header.Set("X-Dev-User", "usr_alice")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var friends []store.FriendUser
	err = json.Unmarshal(rec.Body.Bytes(), &friends)
	require.NoError(t, err)
	require.Len(t, friends, 1)
	assert.Equal(t, "Bob", friends[0].Username)
}

func TestDuelsEndpoints(t *testing.T) {
	router, memStore := setupTestServer()
	ctx := context.Background()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion"})

	// 1. Alice creates duel challenge against Bob
	duelBody, _ := json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "area",
		"target_value": 20000.0,
		"xp_stake":     300,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	var duel store.Duel
	err := json.Unmarshal(rec.Body.Bytes(), &duel)
	require.NoError(t, err)
	assert.Equal(t, "pending", duel.Status)
	assert.Equal(t, 20000.0, duel.TargetValue)

	// 2. Bob lists duels
	req = httptest.NewRequest(http.MethodGet, "/v1/duels", nil)
	req.Header.Set("X-Dev-User", "usr_bob")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var duels []store.Duel
	err = json.Unmarshal(rec.Body.Bytes(), &duels)
	require.NoError(t, err)
	require.Len(t, duels, 1)

	// 3. Bob accepts duel
	req = httptest.NewRequest(http.MethodPut, "/v1/duels/"+duel.ID+"/accept", nil)
	req.Header.Set("X-Dev-User", "usr_bob")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	// Verify duel is active
	duelsAfter, err := memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	assert.Equal(t, "active", duelsAfter[0].Status)
}

func TestDuelDeclineEndpoint(t *testing.T) {
	router, memStore := setupTestServer()
	ctx := context.Background()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_eve", Username: "Eve", Faction: "Shadow Syndicate"})

	// Alice challenges Bob
	duelBody, _ := json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "area",
		"target_value": 15000.0,
		"xp_stake":     200,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	var duel store.Duel
	err := json.Unmarshal(rec.Body.Bytes(), &duel)
	require.NoError(t, err)

	// Eve tries to decline -> unauthorized / 400
	req = httptest.NewRequest(http.MethodPut, "/v1/duels/"+duel.ID+"/decline", nil)
	req.Header.Set("X-Dev-User", "usr_eve")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)

	// Bob declines -> 200 OK
	req = httptest.NewRequest(http.MethodPut, "/v1/duels/"+duel.ID+"/decline", nil)
	req.Header.Set("X-Dev-User", "usr_bob")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var resp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &resp)
	assert.Equal(t, "ok", resp["status"])
	assert.Equal(t, "declined", resp["action"])

	// Verify duel is declined in store
	duels, err := memStore.GetDuelsByUser(ctx, "usr_alice")
	require.NoError(t, err)
	assert.Equal(t, "declined", duels[0].Status)
}

func TestFriendsAndDuelsAntiAbuseEndpoints(t *testing.T) {
	router, memStore := setupTestServer()
	ctx := context.Background()

	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_alice", Username: "Alice", Faction: "Cyber Vanguard"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_bob", Username: "Bob", Faction: "Iron Legion"})

	// 1. Self-friend rejection
	body, _ := json.Marshal(map[string]string{"target_user_id": "usr_alice"})
	req := httptest.NewRequest(http.MethodPost, "/v1/friends/request", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	var errResp map[string]string
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "CANNOT_FRIEND_SELF", errResp["error"])

	// 2. Self-duel rejection
	duelBody, _ := json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_alice",
		"target_type":  "area",
		"target_value": 10000.0,
		"xp_stake":     100,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "CANNOT_DUEL_SELF", errResp["error"])

	// 3. Invalid XP stake rejection
	duelBody, _ = json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "area",
		"target_value": 10000.0,
		"xp_stake":     2500, // exceeds 1000
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "INVALID_XP_STAKE", errResp["error"])

	// 4. Invalid target value (area < 500)
	duelBody, _ = json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "area",
		"target_value": 200.0,
		"xp_stake":     100,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "INVALID_TARGET_VALUE", errResp["error"])

	// 5. Opponent not found
	duelBody, _ = json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_nonexistent",
		"target_type":  "area",
		"target_value": 5000.0,
		"xp_stake":     100,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "OPPONENT_NOT_FOUND", errResp["error"])

	// 6. Valid duel creation
	duelBody, _ = json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "area",
		"target_value": 5000.0,
		"xp_stake":     200,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	// 7. Duplicate duel rejection
	duelBody, _ = json.Marshal(map[string]interface{}{
		"opponent_id":  "usr_bob",
		"target_type":  "distance",
		"target_value": 5.0,
		"xp_stake":     200,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(duelBody))
	req.Header.Set("X-Dev-User", "usr_alice")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	_ = json.Unmarshal(rec.Body.Bytes(), &errResp)
	assert.Equal(t, "DUEL_ALREADY_EXISTS", errResp["error"])
}

func TestPrivacyZonesEndpoints(t *testing.T) {
	router, _ := setupTestServer()

	// 1. GET /v1/me/privacy-zones initially returns empty list
	req := httptest.NewRequest("GET", "/v1/me/privacy-zones", nil)
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var getResp api.PrivacyZonesPayload
	err := json.Unmarshal(rec.Body.Bytes(), &getResp)
	require.NoError(t, err)
	assert.Empty(t, getResp.PrivacyZones)

	// 2. PUT /v1/me/privacy-zones with valid zones
	putPayload := api.PrivacyZonesPayload{
		PrivacyZones: []store.PrivacyZone{
			{
				Name:         "Home Sanctuary",
				Latitude:     37.7749,
				Longitude:    -122.4194,
				RadiusMeters: 250.0,
				IsEnabled:    true,
			},
			{
				Name:         "Office Park",
				Latitude:     37.7833,
				Longitude:    -122.4167,
				RadiusMeters: 150.0,
				IsEnabled:    false,
			},
		},
	}
	body, _ := json.Marshal(putPayload)
	req = httptest.NewRequest("PUT", "/v1/me/privacy-zones", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var putResp api.PrivacyZonesPayload
	err = json.Unmarshal(rec.Body.Bytes(), &putResp)
	require.NoError(t, err)
	assert.Len(t, putResp.PrivacyZones, 2)
	assert.Equal(t, "Home Sanctuary", putResp.PrivacyZones[0].Name)
	assert.Equal(t, 250.0, putResp.PrivacyZones[0].RadiusMeters)
	assert.NotEmpty(t, putResp.PrivacyZones[0].ID)

	// 3. GET /v1/me/privacy-zones returns the saved zones
	req = httptest.NewRequest("GET", "/v1/me/privacy-zones", nil)
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var verifyResp api.PrivacyZonesPayload
	err = json.Unmarshal(rec.Body.Bytes(), &verifyResp)
	require.NoError(t, err)
	assert.Len(t, verifyResp.PrivacyZones, 2)

	// 4. Reject when count exceeds limit (>5 zones)
	excessiveZones := make([]store.PrivacyZone, 6)
	for i := range excessiveZones {
		excessiveZones[i] = store.PrivacyZone{
			Name:         "Zone",
			Latitude:     37.77,
			Longitude:    -122.41,
			RadiusMeters: 100.0,
			IsEnabled:    true,
		}
	}
	body, _ = json.Marshal(api.PrivacyZonesPayload{PrivacyZones: excessiveZones})
	req = httptest.NewRequest("PUT", "/v1/me/privacy-zones", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "MAX_ZONES_EXCEEDED")

	// 5. Reject radius too small (<50m)
	smallRadiusZone := []store.PrivacyZone{
		{
			Name:         "Tiny",
			Latitude:     37.77,
			Longitude:    -122.41,
			RadiusMeters: 20.0, // below 50m
			IsEnabled:    true,
		},
	}
	body, _ = json.Marshal(api.PrivacyZonesPayload{PrivacyZones: smallRadiusZone})
	req = httptest.NewRequest("PUT", "/v1/me/privacy-zones", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "INVALID_RADIUS")

	// 6. Reject radius too large (>2000m)
	hugeRadiusZone := []store.PrivacyZone{
		{
			Name:         "Huge",
			Latitude:     37.77,
			Longitude:    -122.41,
			RadiusMeters: 5000.0, // above 2000m
			IsEnabled:    true,
		},
	}
	body, _ = json.Marshal(api.PrivacyZonesPayload{PrivacyZones: hugeRadiusZone})
	req = httptest.NewRequest("PUT", "/v1/me/privacy-zones", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_runner_privacy")
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "INVALID_RADIUS")
}

func TestSubmitRunActivityTypeValidationAndSpeedCeiling(t *testing.T) {
	router, _ := setupTestServer()
	now := time.Now().UTC()

	// Loop points in London
	loopPoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now, Speed: 2.5},
		{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(1 * time.Minute), Speed: 2.5},
		{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(2 * time.Minute), Speed: 2.5},
		{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(3 * time.Minute), Speed: 2.5},
		{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(4 * time.Minute), Speed: 2.5},
	}

	// 1. Reject invalid activity type
	invalidReq := api.SubmitRunRequest{
		IdempotencyKey:  "run_invalid_act",
		ActivityType:    "hovercraft",
		DurationSeconds: 240,
		DistanceMeters:  400.0,
		Points:          loopPoints,
	}
	body, _ := json.Marshal(invalidReq)
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "act_runner_1")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "INVALID_ACTIVITY_TYPE")

	// 2. Reject cycling speed (>25 km/h, e.g. 8.3 m/s = 30 km/h) when declared as running
	cyclingPoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: now, Speed: 8.3},
		{Latitude: 51.5009, Longitude: -0.1200, Timestamp: now.Add(10 * time.Second), Speed: 8.3},
		{Latitude: 51.5009, Longitude: -0.1214, Timestamp: now.Add(20 * time.Second), Speed: 8.3},
		{Latitude: 51.5000, Longitude: -0.1214, Timestamp: now.Add(30 * time.Second), Speed: 8.3},
		{Latitude: 51.5001, Longitude: -0.1201, Timestamp: now.Add(40 * time.Second), Speed: 8.3},
	}
	runningCyclingReq := api.SubmitRunRequest{
		IdempotencyKey:  "run_cycling_as_running",
		ActivityType:    "running",
		DurationSeconds: 40,
		DistanceMeters:  400.0,
		Points:          cyclingPoints,
	}
	body, _ = json.Marshal(runningCyclingReq)
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "act_runner_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	assert.Contains(t, rec.Body.String(), "ANOMALY_REJECTED")
	assert.Contains(t, rec.Body.String(), "exceeds human running ceiling")

	// 3. Accept same cycling speed when legitimately declared as cycling
	cyclingLegitReq := api.SubmitRunRequest{
		IdempotencyKey:  "run_cycling_legit",
		ActivityType:    "cycling",
		DurationSeconds: 40,
		DistanceMeters:  400.0,
		Points:          cyclingPoints,
	}
	body, _ = json.Marshal(cyclingLegitReq)
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "act_runner_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
	var captureRes store.CaptureResult
	err := json.Unmarshal(rec.Body.Bytes(), &captureRes)
	require.NoError(t, err)
	assert.Equal(t, "cycling", captureRes.ActivityType)
	assert.True(t, captureRes.LoopDetected)

	// 4. Accept legitimate running activity
	normalRunReq := api.SubmitRunRequest{
		IdempotencyKey:  "run_normal_running",
		ActivityType:    "running",
		DurationSeconds: 240,
		DistanceMeters:  400.0,
		Points:          loopPoints,
	}
	body, _ = json.Marshal(normalRunReq)
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "act_runner_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
	var normalRes store.CaptureResult
	err = json.Unmarshal(rec.Body.Bytes(), &normalRes)
	require.NoError(t, err)
	assert.Equal(t, "running", normalRes.ActivityType)
}

func TestServerTimestampHygiene(t *testing.T) {
	router, st := setupTestServer()
	_ = st

	validPoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-60 * time.Second)},
		{Latitude: 51.5005, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-30 * time.Second)},
		{Latitude: 51.5005, Longitude: -0.1205, Timestamp: time.Now().UTC()},
	}

	// 1. Reject future timestamps (> 10m in the future)
	futurePoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-60 * time.Second)},
		{Latitude: 51.5005, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(30 * time.Minute)}, // +30 mins
		{Latitude: 51.5005, Longitude: -0.1205, Timestamp: time.Now().UTC().Add(31 * time.Minute)},
	}
	body, _ := json.Marshal(api.SubmitRunRequest{
		IdempotencyKey:  "hygiene_future_run",
		DurationSeconds: 60,
		DistanceMeters:  200.0,
		Points:          futurePoints,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "hygiene_user_1")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "FUTURE_TIMESTAMPS")

	// 2. Reject expired timestamps (> 14 days in the past)
	expiredPoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-15 * 24 * time.Hour)}, // 15 days ago
		{Latitude: 51.5005, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-15 * 24 * time.Hour).Add(30 * time.Second)},
		{Latitude: 51.5005, Longitude: -0.1205, Timestamp: time.Now().UTC().Add(-15 * 24 * time.Hour).Add(60 * time.Second)},
	}
	body, _ = json.Marshal(api.SubmitRunRequest{
		IdempotencyKey:  "hygiene_expired_run",
		DurationSeconds: 60,
		DistanceMeters:  200.0,
		Points:          expiredPoints,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "hygiene_user_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "EXPIRED_RUN")

	// 3. Reject non-monotonic timestamps
	nonMonoPoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-30 * time.Second)},
		{Latitude: 51.5005, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-60 * time.Second)}, // time traveled backwards!
		{Latitude: 51.5005, Longitude: -0.1205, Timestamp: time.Now().UTC()},
	}
	body, _ = json.Marshal(api.SubmitRunRequest{
		IdempotencyKey:  "hygiene_non_mono_run",
		DurationSeconds: 60,
		DistanceMeters:  200.0,
		Points:          nonMonoPoints,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "hygiene_user_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "NON_MONOTONIC_TIMESTAMPS")

	// 4. Reject zero-displacement duplicate coordinate track
	duplicatePoints := []geo.TrackPoint{
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-60 * time.Second)},
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC().Add(-30 * time.Second)},
		{Latitude: 51.5000, Longitude: -0.1200, Timestamp: time.Now().UTC()},
	}
	body, _ = json.Marshal(api.SubmitRunRequest{
		IdempotencyKey:  "hygiene_duplicate_points_run",
		DurationSeconds: 60,
		DistanceMeters:  0.0,
		Points:          duplicatePoints,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "hygiene_user_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "DUPLICATE_POINTS")

	// 5. Accept valid track and verify idempotency
	body, _ = json.Marshal(api.SubmitRunRequest{
		IdempotencyKey:  "hygiene_valid_run_idempotent",
		DurationSeconds: 60,
		DistanceMeters:  200.0,
		Points:          validPoints,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "hygiene_user_1")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)

	// Idempotent replay
	reqReplay := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewReader(body))
	reqReplay.Header.Set("Content-Type", "application/json")
	reqReplay.Header.Set("X-Dev-User", "hygiene_user_1")
	recReplay := httptest.NewRecorder()
	router.ServeHTTP(recReplay, reqReplay)
	assert.Equal(t, http.StatusOK, recReplay.Code)
}

func TestActivitySegregatedLeaderboardAndLeague(t *testing.T) {
	router, st := setupTestServer()
	ctx := context.Background()

	u1 := &store.User{ID: "usr_act_runner", Username: "SpeedyRunner", Faction: "Cyber Vanguard", TotalAreaSqm: 10000.0}
	u2 := &store.User{ID: "usr_act_cyclist", Username: "FastCyclist", Faction: "Neon Syndicate", TotalAreaSqm: 50000.0}
	require.NoError(t, st.UpsertUser(ctx, u1))
	require.NoError(t, st.UpsertUser(ctx, u2))

	now := time.Now().UTC()
	// Record a running run for Runner
	_, err := st.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_act_run_1",
		UserID:         u1.ID,
		IdempotencyKey: "idem_act_run_1",
		ActivityType:   "running",
		AreaClaimed:    10000.0,
		Status:         "accepted",
		CreatedAt:      now,
	}, nil, nil)
	require.NoError(t, err)

	// Record a cycling run for Cyclist
	_, err = st.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_act_cyc_1",
		UserID:         u2.ID,
		IdempotencyKey: "idem_act_cyc_1",
		ActivityType:   "cycling",
		AreaClaimed:    50000.0,
		Status:         "accepted",
		CreatedAt:      now,
	}, nil, nil)
	require.NoError(t, err)

	// 1. Leaderboard for running: only Runner has running area
	req := httptest.NewRequest(http.MethodGet, "/v1/leaderboard?activity_type=running", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
	var lbRunning struct {
		Leaderboard []store.LeaderboardEntry `json:"leaderboard"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &lbRunning))
	require.NotEmpty(t, lbRunning.Leaderboard)
	assert.Equal(t, u1.ID, lbRunning.Leaderboard[0].UserID)
	assert.Equal(t, 10000.0, lbRunning.Leaderboard[0].TotalAreaSqm)

	// 2. Leaderboard for cycling: Cyclist is ranked #1 with 50,000 sqm
	req = httptest.NewRequest(http.MethodGet, "/v1/leaderboard?activity_type=cycling", nil)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
	var lbCycling struct {
		Leaderboard []store.LeaderboardEntry `json:"leaderboard"`
	}
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &lbCycling))
	require.NotEmpty(t, lbCycling.Leaderboard)
	assert.Equal(t, u2.ID, lbCycling.Leaderboard[0].UserID)
	assert.Equal(t, 50000.0, lbCycling.Leaderboard[0].TotalAreaSqm)

	// 3. Weekly League for running: standing reflects running participants only
	req = httptest.NewRequest(http.MethodGet, "/v1/league/current?activity_type=running", nil)
	req.Header.Set("X-Dev-User", u1.ID)
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)
	var leagueRunning store.LeagueStanding
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &leagueRunning))
	assert.Equal(t, 1, leagueRunning.WeeklyRuns)
	assert.Equal(t, 10000.0, leagueRunning.WeeklyAreaSqm)
}

func TestActivitySegregatedDuels(t *testing.T) {
	router, st := setupTestServer()
	ctx := context.Background()

	u1 := &store.User{ID: "usr_duel_runner_1", Username: "RunnerOne", Faction: "Cyber Vanguard"}
	u2 := &store.User{ID: "usr_duel_runner_2", Username: "RunnerTwo", Faction: "Neon Syndicate"}
	require.NoError(t, st.UpsertUser(ctx, u1))
	require.NoError(t, st.UpsertUser(ctx, u2))

	// Create running duel
	body, _ := json.Marshal(api.CreateDuelRequest{
		OpponentID:   u2.ID,
		ActivityType: "running",
		TargetType:   "area",
		TargetValue:  10000.0,
		XpStake:      100,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/duels", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", u1.ID)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusCreated, rec.Code)
	var createdDuel store.Duel
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &createdDuel))
	assert.Equal(t, "running", createdDuel.ActivityType)

	// Opponent accepts
	require.NoError(t, st.AcceptDuel(ctx, createdDuel.ID, u2.ID))

	// Opponent records a CYCLING run -> should NOT advance the running duel!
	err := st.UpdateDuelProgress(ctx, u2.ID, "cycling", 5000.0, 1000.0)
	require.NoError(t, err)

	duels, err := st.GetDuelsByUser(ctx, u2.ID)
	require.NoError(t, err)
	require.NotEmpty(t, duels)
	assert.Equal(t, 0.0, duels[0].OpponentProgress, "Cycling run must not advance progress in a running duel")

	// Opponent records a RUNNING run -> advances progress!
	err = st.UpdateDuelProgress(ctx, u2.ID, "running", 5000.0, 1000.0)
	require.NoError(t, err)

	duels, err = st.GetDuelsByUser(ctx, u2.ID)
	require.NoError(t, err)
	require.NotEmpty(t, duels)
	assert.Equal(t, 5000.0, duels[0].OpponentProgress, "Running run must advance progress in running duel")
}

func TestGetAndSetUserSettings(t *testing.T) {
	router, _ := setupTestServer()

	// 1. GET /v1/me/settings default is "off"
	req := httptest.NewRequest(http.MethodGet, "/v1/me/settings", nil)
	req.Header.Set("X-Dev-User", "user_settings_test")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var settings store.UserSettings
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &settings))
	assert.Equal(t, "off", settings.LiveVisibility)

	// 2. PUT /v1/me/settings with valid "nearby"
	putBody, _ := json.Marshal(api.UpdateSettingsRequest{LiveVisibility: "nearby"})
	req = httptest.NewRequest(http.MethodPut, "/v1/me/settings", bytes.NewReader(putBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "user_settings_test")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &settings))
	assert.Equal(t, "nearby", settings.LiveVisibility)

	// 3. Verify GET returns updated setting
	req = httptest.NewRequest(http.MethodGet, "/v1/me/settings", nil)
	req.Header.Set("X-Dev-User", "user_settings_test")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &settings))
	assert.Equal(t, "nearby", settings.LiveVisibility)

	// 4. PUT with invalid value -> 400 Bad Request
	badBody, _ := json.Marshal(map[string]string{"live_visibility": "global"})
	req = httptest.NewRequest(http.MethodPut, "/v1/me/settings", bytes.NewReader(badBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Dev-User", "user_settings_test")
	rec = httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestWebSocketHandshake_AuthAndProtocols(t *testing.T) {
	memStore := store.NewMemoryStore()
	wsHub := ws.NewHub(nil, ws.WithPresenceDelay(0))
	go wsHub.Run()
	t.Cleanup(func() { wsHub.Stop() })

	// Set up production Authenticator with StaticKeyProvider
	rsaKey, err := rsaGenerateKey()
	require.NoError(t, err)
	kid := "test-ws-kid"
	projID := "test-proj-ws"

	authCfg := &config.Config{
		AuthMode:          "firebase",
		Env:               "production",
		FirebaseProjectID: projID,
	}
	keyProvider := auth.NewStaticKeyProvider(map[string]*rsa.PublicKey{kid: &rsaKey.PublicKey})
	prodAuthenticator := auth.NewAuthenticator(authCfg, auth.WithKeyProvider(keyProvider))

	apiHandler := api.NewAPI(memStore, nil,
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(prodAuthenticator),
	)
	router := api.SetupRouter(apiHandler, prodAuthenticator)

	server := httptest.NewServer(router)
	t.Cleanup(func() { server.Close() })

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/v1/ws"

	// 1. Missing credentials -> 401 Unauthorized
	_, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	assert.Error(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	// 2. Query token in production is rejected -> 401 Unauthorized
	validToken, err := buildTestJWT(rsaKey, kid, projID, "runner_ws_valid", time.Now().Add(time.Hour))
	require.NoError(t, err)

	_, resp, err = websocket.DefaultDialer.Dial(wsURL+"?token="+validToken, nil)
	assert.Error(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	// 3. Invalid / expired token in Sec-WebSocket-Protocol -> 401
	expiredToken, err := buildTestJWT(rsaKey, kid, projID, "runner_ws_exp", time.Now().Add(-time.Hour))
	require.NoError(t, err)

	dialer := websocket.Dialer{
		Subprotocols: []string{"bearer", expiredToken},
	}
	_, resp, err = dialer.Dial(wsURL, nil)
	assert.Error(t, err)
	require.NotNil(t, resp)
	assert.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	// 4. Valid token in Sec-WebSocket-Protocol -> 101 Switching Protocols & Subprotocol echoed!
	dialerValid := websocket.Dialer{
		Subprotocols: []string{"bearer", validToken},
	}
	conn, resp, err := dialerValid.Dial(wsURL, nil)
	require.NoError(t, err)
	defer conn.Close()

	assert.Equal(t, http.StatusSwitchingProtocols, resp.StatusCode)
	assert.Equal(t, "bearer", resp.Header.Get("Sec-Websocket-Protocol"))

	// 5. Dev mode test: Dev authenticator still works with ?dev_user
	devCfg := &config.Config{AuthMode: "dev", Env: "development"}
	devAuth := auth.NewAuthenticator(devCfg)
	devAPI := api.NewAPI(memStore, nil, api.WithWebSocketHub(wsHub), api.WithAuthenticator(devAuth))
	devRouter := api.SetupRouter(devAPI, devAuth)
	devServer := httptest.NewServer(devRouter)
	t.Cleanup(func() { devServer.Close() })

	devWSURL := "ws" + strings.TrimPrefix(devServer.URL, "http") + "/v1/ws"
	devConn, devResp, err := websocket.DefaultDialer.Dial(devWSURL+"?dev_user=local_runner_dev", nil)
	require.NoError(t, err)
	defer devConn.Close()
	assert.Equal(t, http.StatusSwitchingProtocols, devResp.StatusCode)
}

func rsaGenerateKey() (*rsa.PrivateKey, error) {
	return rsa.GenerateKey(rand.Reader, 2048)
}

func buildTestJWT(privKey *rsa.PrivateKey, kid, projectID, subject string, exp time.Time) (string, error) {
	now := time.Now().Unix()
	header := map[string]string{
		"alg": "RS256",
		"kid": kid,
		"typ": "JWT",
	}
	hBytes, _ := json.Marshal(header)
	hB64 := base64.RawURLEncoding.EncodeToString(hBytes)

	payload := map[string]interface{}{
		"iss": "https://securetoken.google.com/" + projectID,
		"aud": projectID,
		"sub": subject,
		"exp": exp.Unix(),
		"iat": now,
	}
	pBytes, _ := json.Marshal(payload)
	pB64 := base64.RawURLEncoding.EncodeToString(pBytes)

	signed := hB64 + "." + pB64
	hasher := sha256.New()
	hasher.Write([]byte(signed))
	digest := hasher.Sum(nil)

	sig, err := rsa.SignPKCS1v15(rand.Reader, privKey, crypto.SHA256, digest)
	if err != nil {
		return "", err
	}
	return signed + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

func TestHandleDeleteMe_PurgesAccountAndCascades(t *testing.T) {
	// 1. Production mode unauthorized test: missing auth returns 401
	prodCfg := &config.Config{AuthMode: "production", FirebaseProjectID: "test-firebase-proj"}
	keyProvider := auth.NewStaticKeyProvider(map[string]*rsa.PublicKey{})
	prodAuth := auth.NewAuthenticator(prodCfg, auth.WithKeyProvider(keyProvider))
	prodMemStore := store.NewMemoryStore()
	prodAPI := api.NewAPI(prodMemStore, nil, api.WithAuthenticator(prodAuth))
	prodRouter := api.SetupRouter(prodAPI, prodAuth)

	unauthReq := httptest.NewRequest(http.MethodDelete, "/v1/me", nil)
	unauthRec := httptest.NewRecorder()
	prodRouter.ServeHTTP(unauthRec, unauthReq)
	assert.Equal(t, http.StatusUnauthorized, unauthRec.Code)

	// 2. Dev mode deletion test with cascading data
	router, memStore := setupTestServer()
	ctx := context.Background()
	userID := "runner_delete_me"
	err := memStore.UpsertUser(ctx, &store.User{
		ID:           userID,
		Username:     "DeleteTarget",
		Faction:      "Cyber Vanguard",
		TotalAreaSqm: 5000.0,
		XP:           1200,
		Level:        3,
	})
	require.NoError(t, err)

	// Add privacy zone
	err = memStore.SetPrivacyZones(ctx, userID, []store.PrivacyZone{
		{ID: "pz1", UserID: userID, Name: "Home", Latitude: 37.77, Longitude: -122.41, RadiusMeters: 200, IsEnabled: true},
	})
	require.NoError(t, err)

	// Save device token
	err = memStore.SaveDeviceToken(ctx, userID, "token_12345")
	require.NoError(t, err)

	// Verify user exists
	u, err := memStore.GetUser(ctx, userID)
	require.NoError(t, err)
	require.NotNil(t, u)

	// 3. Issue DELETE /v1/me
	req := httptest.NewRequest(http.MethodDelete, "/v1/me", nil)
	req.Header.Set("X-Dev-User", userID)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]interface{}
	err = json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "deleted", resp["status"])
	assert.Equal(t, userID, resp["user_id"])

	// 4. Verify user and cascading data are completely purged
	purgedUser, err := memStore.GetUser(ctx, userID)
	require.NoError(t, err)
	assert.Nil(t, purgedUser)

	runs, err := memStore.GetRunsByUser(ctx, userID, 10)
	require.NoError(t, err)
	assert.Empty(t, runs)

	zones, err := memStore.GetPrivacyZones(ctx, userID)
	require.NoError(t, err)
	assert.Empty(t, zones)

	tokens, err := memStore.GetDeviceTokens(ctx, userID)
	require.NoError(t, err)
	assert.Empty(t, tokens)
}
