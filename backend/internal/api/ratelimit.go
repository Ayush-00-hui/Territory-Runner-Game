package api

import (
	"encoding/json"
	"fmt"
	"math"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
)

// TrustedProxyChecker validates whether an IP address belongs to configured trusted proxies.
type TrustedProxyChecker struct {
	cidrs []*net.IPNet
	ips   []net.IP
}

// ParseTrustedProxies parses a comma-separated list of IP addresses and CIDR subnets.
func ParseTrustedProxies(s string) *TrustedProxyChecker {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	checker := &TrustedProxyChecker{}
	parts := strings.Split(s, ",")
	for _, part := range parts {
		p := strings.TrimSpace(part)
		if p == "" {
			continue
		}
		if _, ipNet, err := net.ParseCIDR(p); err == nil {
			checker.cidrs = append(checker.cidrs, ipNet)
			continue
		}
		if ip := net.ParseIP(p); ip != nil {
			checker.ips = append(checker.ips, ip)
		}
	}
	if len(checker.cidrs) == 0 && len(checker.ips) == 0 {
		return nil
	}
	return checker
}

// IsTrusted returns true if the specified IP is within the trusted proxies list.
func (c *TrustedProxyChecker) IsTrusted(ip net.IP) bool {
	if c == nil || ip == nil {
		return false
	}
	for _, trustedIP := range c.ips {
		if trustedIP.Equal(ip) {
			return true
		}
	}
	for _, cidr := range c.cidrs {
		if cidr.Contains(ip) {
			return true
		}
	}
	return false
}

// GetClientIP extracts the client IP address. X-Forwarded-For and X-Real-IP are ONLY
// trusted if the immediate peer (RemoteAddr) is in the configured TRUSTED_PROXIES list.
func GetClientIP(r *http.Request, checker *TrustedProxyChecker) string {
	remoteHost := r.RemoteAddr
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		remoteHost = host
	}
	remoteIP := net.ParseIP(remoteHost)

	// If no trusted proxy checker or remote peer IP is not trusted,
	// do NOT trust X-Forwarded-For or X-Real-IP headers. Return peer IP.
	if checker == nil || remoteIP == nil || !checker.IsTrusted(remoteIP) {
		return remoteHost
	}

	// Remote peer is a trusted proxy. Inspect forwarding headers.
	// 1. Inspect X-Forwarded-For from right to left
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		var ips []string
		for _, p := range parts {
			trimmed := strings.TrimSpace(p)
			if trimmed != "" {
				ips = append(ips, trimmed)
			}
		}
		// Walk backwards to find the first untrusted upstream IP
		for i := len(ips) - 1; i >= 0; i-- {
			candidateIP := net.ParseIP(ips[i])
			if candidateIP == nil {
				continue
			}
			if !checker.IsTrusted(candidateIP) {
				return ips[i]
			}
		}
		// If all IPs in XFF were trusted, return the leftmost valid one
		if len(ips) > 0 {
			return ips[0]
		}
	}

	// 2. Inspect X-Real-IP
	if xri := strings.TrimSpace(r.Header.Get("X-Real-IP")); xri != "" {
		if parsed := net.ParseIP(xri); parsed != nil {
			return xri
		}
	}

	return remoteHost
}

// RateLimiter implements an in-memory token bucket rate limiter per key.
type RateLimiter struct {
	mu             sync.Mutex
	buckets        map[string]*bucket
	rate           float64 // tokens added per second
	capacity       float64 // maximum tokens held
	cleanTicker    *time.Ticker
	stopCleanup    chan struct{}
	trustedProxies *TrustedProxyChecker
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

// SetTrustedProxies configures trusted reverse proxy CIDRs/IPs for client IP extraction.
func (rl *RateLimiter) SetTrustedProxies(proxies string) {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	rl.trustedProxies = ParseTrustedProxies(proxies)
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
func (rl *RateLimiter) KeyForRequest(r *http.Request) string {
	uid := auth.GetUserID(r.Context())
	if uid != "" {
		return "usr:" + uid
	}

	rl.mu.Lock()
	checker := rl.trustedProxies
	rl.mu.Unlock()

	if checker == nil {
		checker = ParseTrustedProxies(os.Getenv("TRUSTED_PROXIES"))
	}

	clientIP := GetClientIP(r, checker)
	return "ip:" + clientIP
}

// KeyForRequest returns the rate limit identifier: authenticated User ID, or client IP.
// Uses TRUSTED_PROXIES environment variable if configured.
func KeyForRequest(r *http.Request) string {
	uid := auth.GetUserID(r.Context())
	if uid != "" {
		return "usr:" + uid
	}
	checker := ParseTrustedProxies(os.Getenv("TRUSTED_PROXIES"))
	clientIP := GetClientIP(r, checker)
	return "ip:" + clientIP
}

// RateLimitMiddleware creates HTTP middleware enforcing rate limits.
func RateLimitMiddleware(limiter *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := limiter.KeyForRequest(r)
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
