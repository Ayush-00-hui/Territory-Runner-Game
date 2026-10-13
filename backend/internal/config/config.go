package config

import (
	"errors"
	"os"
)

var (
	// ErrDevModeInProduction is returned when AUTH_MODE=dev is specified with ENV=production.
	ErrDevModeInProduction = errors.New("security violation: AUTH_MODE=dev is strictly forbidden when ENV=production")
)

// Config encapsulates backend service configuration.
type Config struct {
	Port         string
	DatabaseURL  string
	AuthMode     string // "firebase" or "dev"
	Env          string // "development", "staging", "production"
	GeminiAPIKey string
}

// Load reads configuration from environment variables with sensible defaults.
func Load() (*Config, error) {
	port := getEnv("PORT", "8080")
	dbURL := getEnv("DATABASE_URL", "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable")
	authMode := getEnv("AUTH_MODE", "dev")
	env := getEnv("ENV", "development")
	geminiKey := getEnv("GEMINI_API_KEY", "")

	cfg := &Config{
		Port:         port,
		DatabaseURL:  dbURL,
		AuthMode:     authMode,
		Env:          env,
		GeminiAPIKey: geminiKey,
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
	return nil
}

func getEnv(key, defaultVal string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	return val
}
