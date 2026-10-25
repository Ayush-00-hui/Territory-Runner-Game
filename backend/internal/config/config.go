package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
)

var (
	// ErrDevAuthRequiresDevEnv is returned when AUTH_MODE=dev is specified without explicit ENV=development.
	ErrDevAuthRequiresDevEnv = errors.New("security violation: AUTH_MODE=dev strictly requires explicit ENV=development")
	// ErrDevModeInProduction is preserved for backward compatibility.
	ErrDevModeInProduction = ErrDevAuthRequiresDevEnv
	// ErrMissingFirebaseProjectID is returned when AUTH_MODE=firebase without FIREBASE_PROJECT_ID.
	ErrMissingFirebaseProjectID = errors.New("security violation: FIREBASE_PROJECT_ID is required when AUTH_MODE is not dev")
	// ErrMissingAllowedOrigins is returned when ENV=production, ALLOWED_ORIGINS is empty, and ALLOW_ANY_ORIGIN!=true.
	ErrMissingAllowedOrigins = errors.New("security violation: ALLOWED_ORIGINS must not be empty in production unless ALLOW_ANY_ORIGIN=true is explicitly set")
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
	AllowAnyOrigin    bool
	MaxPointsPerRun   int
	MaxRunDurationSec int
	RunMigrations     bool
	MetricsToken      string
	TrustedProxies    string
}

// Load reads configuration from environment variables with sensible defaults.
func Load() (*Config, error) {
	port := getEnv("PORT", "8080")
	dbURL := getEnv("DATABASE_URL", "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable")
	authMode := getEnv("AUTH_MODE", "firebase")
	env := getEnv("ENV", "production")
	firebaseProjectID := getEnv("FIREBASE_PROJECT_ID", "")
	geminiKey := getEnv("GEMINI_API_KEY", "")
	geminiModel := getEnv("GEMINI_MODEL", "gemini-2.5-flash")
	metricsToken := getEnv("METRICS_TOKEN", "")
	trustedProxies := getEnv("TRUSTED_PROXIES", "")
	runMigrations := strings.ToLower(getEnv("RUN_MIGRATIONS", "false")) == "true" || getEnv("RUN_MIGRATIONS", "false") == "1"
	allowAnyOrigin := strings.ToLower(getEnv("ALLOW_ANY_ORIGIN", "false")) == "true" || getEnv("ALLOW_ANY_ORIGIN", "false") == "1"

	allowedOriginsStr := os.Getenv("ALLOWED_ORIGINS")
	var allowedOrigins []string
	if allowedOriginsStr != "" {
		for _, o := range strings.Split(allowedOriginsStr, ",") {
			o = strings.TrimSpace(o)
			if o != "" {
				allowedOrigins = append(allowedOrigins, o)
			}
		}
	} else if env == "development" || allowAnyOrigin {
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
		AllowAnyOrigin:    allowAnyOrigin,
		MaxPointsPerRun:   maxPoints,
		MaxRunDurationSec: maxDuration,
		RunMigrations:     runMigrations,
		MetricsToken:      metricsToken,
		TrustedProxies:    trustedProxies,
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Validate checks for security violations or invalid combinations.
func (c *Config) Validate() error {
	if c.AuthMode == "dev" {
		if c.Env != "development" {
			return ErrDevAuthRequiresDevEnv
		}
	} else if c.FirebaseProjectID == "" {
		return ErrMissingFirebaseProjectID
	}

	if c.Env == "production" {
		if len(c.AllowedOrigins) == 0 && !c.AllowAnyOrigin {
			return ErrMissingAllowedOrigins
		}
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
