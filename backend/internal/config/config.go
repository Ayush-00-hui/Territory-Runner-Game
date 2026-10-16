package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
)

var (
	// ErrDevModeInProduction is returned when AUTH_MODE=dev is specified with ENV=production.
	ErrDevModeInProduction = errors.New("security violation: AUTH_MODE=dev is strictly forbidden when ENV=production")
	// ErrMissingFirebaseProjectID is returned when AUTH_MODE=firebase without FIREBASE_PROJECT_ID.
	ErrMissingFirebaseProjectID = errors.New("security violation: FIREBASE_PROJECT_ID is required when AUTH_MODE is not dev")
)

// Config encapsulates backend service configuration.
type Config struct {
	Port              string
	DatabaseURL       string
	AuthMode          string // "firebase" or "dev"
	Env               string // "development", "staging", "production"
	FirebaseProjectID string
	GeminiAPIKey      string
	GeminiModel       string
	AllowedOrigins    []string
	MaxPointsPerRun   int
	MaxRunDurationSec int
}

// Load reads configuration from environment variables with sensible defaults.
func Load() (*Config, error) {
	port := getEnv("PORT", "8085")
	dbURL := getEnv("DATABASE_URL", "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable")
	authMode := getEnv("AUTH_MODE", "dev")
	env := getEnv("ENV", "development")
	firebaseProjectID := getEnv("FIREBASE_PROJECT_ID", "")
	geminiKey := getEnv("GEMINI_API_KEY", "")
	geminiModel := getEnv("GEMINI_MODEL", "gemini-2.5-flash")

	allowedOriginsStr := os.Getenv("ALLOWED_ORIGINS")
	var allowedOrigins []string
	if allowedOriginsStr != "" {
		for _, o := range strings.Split(allowedOriginsStr, ",") {
			o = strings.TrimSpace(o)
			if o != "" {
				allowedOrigins = append(allowedOrigins, o)
			}
		}
	} else if env == "development" {
		allowedOrigins = []string{"*"}
	}

	maxPoints := 20000
	if val := os.Getenv("MAX_POINTS_PER_RUN"); val != "" {
		if p, err := strconv.Atoi(val); err == nil && p > 0 {
			maxPoints = p
		}
	}

	maxDuration := 86400 // 24 hours
	if val := os.Getenv("MAX_RUN_DURATION_SECONDS"); val != "" {
		if d, err := strconv.Atoi(val); err == nil && d > 0 {
			maxDuration = d
		}
	}

	cfg := &Config{
		Port:              port,
		DatabaseURL:       dbURL,
		AuthMode:          authMode,
		Env:               env,
		FirebaseProjectID: firebaseProjectID,
		GeminiAPIKey:      geminiKey,
		GeminiModel:       geminiModel,
		AllowedOrigins:    allowedOrigins,
		MaxPointsPerRun:   maxPoints,
		MaxRunDurationSec: maxDuration,
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Validate checks for security violations or invalid combinations.
func (c *Config) Validate() error {
	if c.Env == "production" && c.AuthMode == "dev" {
		return ErrDevModeInProduction
	}
	if c.AuthMode != "dev" && c.FirebaseProjectID == "" {
		return ErrMissingFirebaseProjectID
	}
	return nil
}

func getEnv(key, defaultVal string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	return val
}

