package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type failingPingStore struct {
	store.Store
}

func (f *failingPingStore) Ping(ctx context.Context) error {
	return errors.New("connection refused to postgres:5432")
}

func TestReadyzHealthy(t *testing.T) {
	router, _ := setupTestServer()

	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	var resp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "ready", resp["status"])
	assert.Equal(t, "connected", resp["database"])
}

func TestReadyzUnhealthyOnPingFailure(t *testing.T) {
	memStore := store.NewMemoryStore()
	badStore := &failingPingStore{Store: memStore}
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(badStore, nil, api.WithAuthenticator(authenticator))
	router := api.SetupRouter(apiHandler, authenticator)

	req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)
	var resp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "unhealthy", resp["status"])
	assert.Contains(t, resp["error"], "connection refused")
}

func TestStandardErrorEnvelopeIncludesRequestId(t *testing.T) {
	router, _ := setupTestServer()

	// Make an invalid request missing idempotency_key
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", bytes.NewBufferString(`{"activity_type": "running"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	reqID := rec.Header().Get("X-Request-Id")
	assert.NotEmpty(t, reqID, "X-Request-Id response header should be populated")

	var resp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)
	assert.Equal(t, "MISSING_KEY", resp["error"])
	assert.Equal(t, reqID, resp["request_id"], "Error response JSON envelope must attach request_id matching header")
}

func TestPrometheusMetricsEndpoint(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	wsHub := ws.NewHub(nil)
	apiHandler := api.NewAPI(memStore, nil,
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(authenticator),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	// Hit /healthz and /readyz to generate metrics
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/healthz", nil))
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/readyz", nil))

	// Fetch /metrics
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Header().Get("Content-Type"), "text/plain")

	body := rec.Body.String()
	assert.Contains(t, body, "# HELP http_requests_total")
	assert.Contains(t, body, "# TYPE http_requests_total counter")
	assert.Contains(t, body, "http_requests_total{method=\"GET\",path=\"/healthz\",status=\"200\"} 1")
	assert.Contains(t, body, "http_requests_total{method=\"GET\",path=\"/readyz\",status=\"200\"} 1")
	assert.Contains(t, body, "# HELP http_request_duration_seconds")
	assert.Contains(t, body, "# TYPE http_request_duration_seconds histogram")
	assert.Contains(t, body, "# HELP ws_active_connections")
	assert.Contains(t, body, "# TYPE ws_active_connections gauge")
	assert.Contains(t, body, "ws_active_connections 0")
}

func TestMetricsEndpoint_ProtectedWithBearerToken(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := api.NewAPI(memStore, nil,
		api.WithAuthenticator(authenticator),
		api.WithMetricsToken("secret-metrics-token"),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	// 1. Missing Authorization header -> 401 Unauthorized
	reqNoAuth := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	recNoAuth := httptest.NewRecorder()
	router.ServeHTTP(recNoAuth, reqNoAuth)
	assert.Equal(t, http.StatusUnauthorized, recNoAuth.Code)
	assert.Contains(t, recNoAuth.Header().Get("WWW-Authenticate"), `Bearer realm="metrics"`)

	// 2. Invalid bearer token -> 401 Unauthorized
	reqBadAuth := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	reqBadAuth.Header.Set("Authorization", "Bearer invalid-token")
	recBadAuth := httptest.NewRecorder()
	router.ServeHTTP(recBadAuth, reqBadAuth)
	assert.Equal(t, http.StatusUnauthorized, recBadAuth.Code)

	// 3. Valid bearer token -> 200 OK
	reqGoodAuth := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	reqGoodAuth.Header.Set("Authorization", "Bearer secret-metrics-token")
	recGoodAuth := httptest.NewRecorder()
	router.ServeHTTP(recGoodAuth, reqGoodAuth)
	assert.Equal(t, http.StatusOK, recGoodAuth.Code)
	assert.Contains(t, recGoodAuth.Body.String(), "# HELP http_requests_total")
}

func TestHandleWebSocket_RequiresAuthenticationBeforeUpgrade(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "firebase", Env: "production", FirebaseProjectID: "test-proj"}
	authenticator := auth.NewAuthenticator(cfg)
	wsHub := ws.NewHub(nil)
	apiHandler := api.NewAPI(memStore, nil,
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(authenticator),
	)
	router := api.SetupRouter(apiHandler, authenticator)

	// 1. Unauthenticated WebSocket upgrade attempt
	req := httptest.NewRequest(http.MethodGet, "/v1/ws", nil)
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	req.Header.Set("Sec-WebSocket-Version", "13")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)

	// Connection MUST NOT be upgraded to 101 Switching Protocols.
	// Must return HTTP 401 Unauthorized.
	assert.NotEqual(t, http.StatusSwitchingProtocols, rec.Code)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)

	var errResp map[string]string
	err := json.Unmarshal(rec.Body.Bytes(), &errResp)
	require.NoError(t, err)
	assert.Equal(t, "UNAUTHORIZED", errResp["error"])

	// 2. Invalid Bearer token attempt
	reqWithBadToken := httptest.NewRequest(http.MethodGet, "/v1/ws", nil)
	reqWithBadToken.Header.Set("Upgrade", "websocket")
	reqWithBadToken.Header.Set("Connection", "Upgrade")
	reqWithBadToken.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	reqWithBadToken.Header.Set("Sec-WebSocket-Version", "13")
	reqWithBadToken.Header.Set("Authorization", "Bearer invalid-jwt-token")
	recWithBadToken := httptest.NewRecorder()

	router.ServeHTTP(recWithBadToken, reqWithBadToken)
	assert.NotEqual(t, http.StatusSwitchingProtocols, recWithBadToken.Code)
	assert.Equal(t, http.StatusUnauthorized, recWithBadToken.Code)
}

