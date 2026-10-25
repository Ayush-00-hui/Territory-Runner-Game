package api_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestClientIP_UntrustedByDefault(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
	req.RemoteAddr = "192.0.2.1:12345"
	req.Header.Set("X-Forwarded-For", "203.0.113.195")
	req.Header.Set("X-Real-IP", "203.0.113.195")

	// Without trusted proxies configured, headers MUST be ignored
	clientIP := api.GetClientIP(req, nil)
	assert.Equal(t, "192.0.2.1", clientIP, "Untrusted proxy must not honor X-Forwarded-For or X-Real-IP")

	key := api.KeyForRequest(req)
	assert.Equal(t, "ip:192.0.2.1", key)
}

func TestClientIP_WithTrustedProxies(t *testing.T) {
	checker := api.ParseTrustedProxies("127.0.0.1, 10.0.0.0/8, 172.16.0.0/12")
	require.NotNil(t, checker)

	t.Run("Untrusted Peer Spoofing Ignored", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
		req.RemoteAddr = "203.0.113.50:54321" // Public IP, not in trusted proxies
		req.Header.Set("X-Forwarded-For", "8.8.8.8")
		req.Header.Set("X-Real-IP", "8.8.8.8")

		clientIP := api.GetClientIP(req, checker)
		assert.Equal(t, "203.0.113.50", clientIP, "Untrusted peer header spoofing must be rejected")
	})

	t.Run("Trusted Proxy Single XFF Header", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
		req.RemoteAddr = "127.0.0.1:4321" // Trusted proxy
		req.Header.Set("X-Forwarded-For", "198.51.100.77")

		clientIP := api.GetClientIP(req, checker)
		assert.Equal(t, "198.51.100.77", clientIP)
	})

	t.Run("Trusted Proxy Multi-Hop XFF Chain", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
		req.RemoteAddr = "10.0.0.1:4321" // Trusted internal gateway
		// 10.0.0.2 is internal proxy (trusted), 198.51.100.99 is real client
		req.Header.Set("X-Forwarded-For", "198.51.100.99, 10.0.0.2")

		clientIP := api.GetClientIP(req, checker)
		assert.Equal(t, "198.51.100.99", clientIP, "Must extract the first untrusted upstream client IP")
	})

	t.Run("Trusted Proxy X-Real-IP Fallback", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
		req.RemoteAddr = "172.16.0.5:4321" // Trusted private subnet
		req.Header.Set("X-Real-IP", "198.51.100.88")

		clientIP := api.GetClientIP(req, checker)
		assert.Equal(t, "198.51.100.88", clientIP)
	})
}

func TestKeyForRequest_AuthenticatedUserPrecedence(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
	req.RemoteAddr = "192.0.2.1:12345"
	ctx := auth.WithUserID(req.Context(), "usr_athlete_42")
	req = req.WithContext(ctx)

	key := api.KeyForRequest(req)
	assert.Equal(t, "usr:usr_athlete_42", key, "Authenticated user ID must take precedence over IP")
}

func TestRateLimiter_TokenBucket(t *testing.T) {
	rl := api.NewRateLimiter(2.0, 3.0) // 3 tokens max, 2 tokens/sec
	defer rl.Close()

	// 3 allowed bursts
	allowed, retry := rl.Allow("test_key")
	assert.True(t, allowed)
	assert.Equal(t, 0, retry)

	allowed, retry = rl.Allow("test_key")
	assert.True(t, allowed)
	assert.Equal(t, 0, retry)

	allowed, retry = rl.Allow("test_key")
	assert.True(t, allowed)
	assert.Equal(t, 0, retry)

	// 4th request exhausted
	allowed, retry = rl.Allow("test_key")
	assert.False(t, allowed)
	assert.GreaterOrEqual(t, retry, 1)

	// Wait 600ms for > 1 token to refill
	time.Sleep(600 * time.Millisecond)
	allowed, _ = rl.Allow("test_key")
	assert.True(t, allowed, "Token must be available after refill")
}

func TestRateLimitMiddleware_BlocksWhenExceeded(t *testing.T) {
	rl := api.NewRateLimiter(1.0, 1.0)
	defer rl.Close()

	handler := api.RateLimitMiddleware(rl)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))

	// First request succeeds
	req1 := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
	req1.RemoteAddr = "198.51.100.1:1234"
	w1 := httptest.NewRecorder()
	handler.ServeHTTP(w1, req1)
	assert.Equal(t, http.StatusOK, w1.Code)

	// Second request from same IP is rate limited
	req2 := httptest.NewRequest(http.MethodPost, "/v1/runs", nil)
	req2.RemoteAddr = "198.51.100.1:1234"
	w2 := httptest.NewRecorder()
	handler.ServeHTTP(w2, req2)
	assert.Equal(t, http.StatusTooManyRequests, w2.Code)
	assert.NotEmpty(t, w2.Header().Get("Retry-After"))
	assert.Contains(t, w2.Body.String(), "RATE_LIMIT_EXCEEDED")
}
