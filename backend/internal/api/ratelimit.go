package api

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
)

// RateLimiter implements an in-memory token bucket rate limiter per key.
type RateLimiter struct {
	mu          sync.Mutex
	buckets     map[string]*bucket
	rate        float64 // tokens added per second
	capacity    float64 // maximum tokens held
	cleanTicker *time.Ticker
	stopCleanup chan struct{}
}

type bucket struct {
	tokens     float64
	lastRefill time.Time
}

// NewRateLimiter creates a RateLimiter that refills `rate` tokens per second up to `capacity`.
func NewRateLimiter(rate float64, capacity float64) *RateLimiter {
	rl := &RateLimiter{
		buckets:     make(map[string]*bucket),
		rate:        rate,
		capacity:    capacity,
		cleanTicker: time.NewTicker(5 * time.Minute),
		stopCleanup: make(chan struct{}),
	}
	go rl.cleanupLoop()
	return rl
}

func (rl *RateLimiter) cleanupLoop() {
	for {
		select {
		case <-rl.cleanTicker.C:
			rl.mu.Lock()
			now := time.Now()
			for k, b := range rl.buckets {
				// Remove buckets that have been at capacity and idle for > 10 minutes
				if now.Sub(b.lastRefill) > 10*time.Minute && b.tokens >= rl.capacity {
					delete(rl.buckets, k)
				}
			}
			rl.mu.Unlock()
		case <-rl.stopCleanup:
			rl.cleanTicker.Stop()
			return
		}
	}
}

// Close stops the cleanup goroutine.
func (rl *RateLimiter) Close() {
	close(rl.stopCleanup)
}

// Allow checks if a token can be consumed for the given key.
// Returns (allowed, retryAfterSeconds).
func (rl *RateLimiter) Allow(key string) (bool, int) {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	b, exists := rl.buckets[key]
	if !exists {
		b = &bucket{
			tokens:     rl.capacity - 1.0,
			lastRefill: now,
		}
		rl.buckets[key] = b
		return true, 0
	}

	// Refill tokens based on elapsed time
	elapsed := now.Sub(b.lastRefill).Seconds()
	b.tokens = math.Min(rl.capacity, b.tokens+(elapsed*rl.rate))
	b.lastRefill = now

	if b.tokens >= 1.0 {
		b.tokens -= 1.0
		return true, 0
	}

	// Calculate seconds until 1 token is available
	missing := 1.0 - b.tokens
	retryAfter := int(math.Ceil(missing / rl.rate))
	if retryAfter < 1 {
		retryAfter = 1
	}
	return false, retryAfter
}

// KeyForRequest returns the rate limit identifier: authenticated User ID, or client IP.
func KeyForRequest(r *http.Request) string {
	uid := auth.GetUserID(r.Context())
	if uid != "" {
		return "usr:" + uid
	}
	// Fall back to client IP (handles X-Forwarded-For, X-Real-IP, RemoteAddr)
	ip := r.Header.Get("X-Forwarded-For")
	if ip != "" {
		parts := strings.Split(ip, ",")
		return "ip:" + strings.TrimSpace(parts[0])
	}
	ip = r.Header.Get("X-Real-IP")
	if ip != "" {
		return "ip:" + strings.TrimSpace(ip)
	}
	return "ip:" + r.RemoteAddr
}

// RateLimitMiddleware creates HTTP middleware enforcing rate limits.
func RateLimitMiddleware(limiter *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := KeyForRequest(r)
			allowed, retryAfter := limiter.Allow(key)
			if !allowed {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", retryAfter))
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				_ = json.NewEncoder(w).Encode(map[string]interface{}{
					"error":       "RATE_LIMIT_EXCEEDED",
					"detail":      "Rate limit exceeded. Please wait before retrying.",
					"retry_after": retryAfter,
				})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
