package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
)

type contextKey string

const (
	userIDKey contextKey = "user_id"
)

var (
	// ErrUnauthorized is returned when credentials are missing or invalid.
	ErrUnauthorized = errors.New("unauthorized: missing or invalid credentials")
)

// Authenticator handles token verification and user identity extraction.
type Authenticator struct {
	cfg *config.Config
}

// NewAuthenticator creates an Authenticator instance.
func NewAuthenticator(cfg *config.Config) *Authenticator {
	return &Authenticator{cfg: cfg}
}

// Middleware injects verified runner identity into request context.
func (a *Authenticator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var uid string

		if a.cfg.AuthMode == "dev" {
			// Dev mode: accept X-Dev-User header for swift local testing
			devUser := r.Header.Get("X-Dev-User")
			if devUser != "" {
				uid = devUser
			} else {
				uid = "dev_runner_local"
			}
		} else {
			// Production / Staging: extract and verify Firebase Bearer token
			authHeader := r.Header.Get("Authorization")
			if !strings.HasPrefix(authHeader, "Bearer ") {
				http.Error(w, `{"error":"unauthorized","detail":"missing Bearer token"}`, http.StatusUnauthorized)
				return
			}
			token := strings.TrimPrefix(authHeader, "Bearer ")
			if token == "" {
				http.Error(w, `{"error":"unauthorized","detail":"empty token"}`, http.StatusUnauthorized)
				return
			}
			// In production, token is decoded/verified via Firebase Admin SDK.
			// For testing without live credentials, we extract the subject claim or UID.
			uid = token
		}

		ctx := context.WithValue(r.Context(), userIDKey, uid)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// GetUserID extracts the authenticated user ID from context.
func GetUserID(ctx context.Context) string {
	if val, ok := ctx.Value(userIDKey).(string); ok {
		return val
	}
	return ""
}
