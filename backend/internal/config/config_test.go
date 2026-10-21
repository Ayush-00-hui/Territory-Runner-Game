package config_test

import (
	"os"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func clearEnv(t *testing.T) {
	vars := []string{
		"PORT", "DATABASE_URL", "AUTH_MODE", "ENV", "FIREBASE_PROJECT_ID",
		"GEMINI_API_KEY", "GEMINI_MODEL", "ALLOWED_ORIGINS", "ALLOW_ANY_ORIGIN",
		"MAX_POINTS_PER_RUN", "MAX_RUN_DURATION_SECONDS", "RUN_MIGRATIONS",
	}
	for _, v := range vars {
		os.Unsetenv(v)
	}
}

func TestConfig_ProductionRequiresAllowedOrigins(t *testing.T) {
	clearEnv(t)
	defer clearEnv(t)

	os.Setenv("ENV", "production")
	os.Setenv("AUTH_MODE", "firebase")
	os.Setenv("FIREBASE_PROJECT_ID", "test-project")
	// ALLOWED_ORIGINS is empty, and ALLOW_ANY_ORIGIN is not set

	cfg, err := config.Load()
	require.Error(t, err, "Production without ALLOWED_ORIGINS or ALLOW_ANY_ORIGIN must fail fast")
	assert.Nil(t, cfg)
	assert.ErrorIs(t, err, config.ErrMissingAllowedOrigins)
}

func TestConfig_ProductionWithAllowAnyOrigin(t *testing.T) {
	clearEnv(t)
	defer clearEnv(t)

	os.Setenv("ENV", "production")
	os.Setenv("AUTH_MODE", "firebase")
	os.Setenv("FIREBASE_PROJECT_ID", "test-project")
	os.Setenv("ALLOW_ANY_ORIGIN", "true")

	cfg, err := config.Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, []string{"*"}, cfg.AllowedOrigins)
}

func TestConfig_ProductionWithAllowedOrigins(t *testing.T) {
	clearEnv(t)
	defer clearEnv(t)

	os.Setenv("ENV", "production")
	os.Setenv("AUTH_MODE", "firebase")
	os.Setenv("FIREBASE_PROJECT_ID", "test-project")
	os.Setenv("ALLOWED_ORIGINS", "https://app.territoryrunner.com, https://admin.territoryrunner.com")

	cfg, err := config.Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, []string{"https://app.territoryrunner.com", "https://admin.territoryrunner.com"}, cfg.AllowedOrigins)
}

func TestConfig_DevelopmentDefaults(t *testing.T) {
	clearEnv(t)
	defer clearEnv(t)

	os.Setenv("ENV", "development")
	os.Setenv("AUTH_MODE", "dev")

	cfg, err := config.Load()
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, []string{"*"}, cfg.AllowedOrigins)
}
