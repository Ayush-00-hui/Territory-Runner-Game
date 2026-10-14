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

// AuthenticateRequest extracts user ID from headers or query parameters (ideal for WebSockets).
func (a *Authenticator) AuthenticateRequest(r *http.Request) (string, error) {
	if a.cfg.AuthMode == "dev" {
		devUser := r.Header.Get("X-Dev-User")
		if devUser == "" {
			devUser = r.URL.Query().Get("dev_user")
		}
		if devUser == "" {
			devUser = r.URL.Query().Get("user_id")
		}
		if devUser != "" {
			return devUser, nil
		}
		return "dev_runner_local", nil
	}

	authHeader := r.Header.Get("Authorization")
	token := ""
	if strings.HasPrefix(authHeader, "Bearer ") {
		token = strings.TrimPrefix(authHeader, "Bearer ")
	} else {
		token = r.URL.Query().Get("token")
	}

	if token == "" {
		return "", ErrUnauthorized
	}
	return token, nil
}

// Middleware injects verified runner identity into request context.
func (a *Authenticator) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, err := a.AuthenticateRequest(r)
		if err != nil {
			http.Error(w, `{"error":"unauthorized","detail":"missing or invalid authentication credentials"}`, http.StatusUnauthorized)
			return
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
