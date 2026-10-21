package migrations

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"github.com/golang-migrate/migrate/v4"
	pgxmigrate "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
)

// ErrLegacyDatabaseDetected is returned when pre-existing tables exist without a schema_migrations tracking table.
var ErrLegacyDatabaseDetected = errors.New("database migration failed: legacy database detected (pre-existing tables exist without 'schema_migrations' tracking table). To baseline safely, run migrations with BASELINE_ON_LEGACY=true or initialize a fresh database")

// DetectLegacySchema checks whether application tables exist in the public schema without a schema_migrations table.
func DetectLegacySchema(ctx context.Context, db *sql.DB) (bool, error) {
	var schemaMigrationsExists bool
	err := db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM information_schema.tables 
			WHERE table_schema = 'public' AND table_name = 'schema_migrations'
		);
	`).Scan(&schemaMigrationsExists)
	if err != nil {
		return false, fmt.Errorf("failed to check schema_migrations existence: %w", err)
	}

	if schemaMigrationsExists {
		return false, nil
	}

	var legacyTableCount int
	err = db.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM information_schema.tables 
		WHERE table_schema = 'public' AND table_name IN ('users', 'territories', 'runs');
	`).Scan(&legacyTableCount)
	if err != nil {
		return false, fmt.Errorf("failed to check legacy tables: %w", err)
	}

	return legacyTableCount > 0, nil
}

// Run applies all pending embedded database migrations against the given connection string.
// It executes migrations inside an advisory lock (guarded by pg_advisory_lock via pgx driver)
// ensuring concurrent instances do not collide or execute migrations simultaneously.
// Returns nil if migrations successfully applied or if already up-to-date (ErrNoChange).
func Run(ctx context.Context, connString string, logger *slog.Logger) error {
	if logger == nil {
		logger = slog.Default()
	}

	logger.Info("checking database migrations status")

	cfg, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return fmt.Errorf("invalid database connection string: %w", err)
	}

	// Open a standard sql.DB connection for golang-migrate
	db := stdlib.OpenDB(*cfg.ConnConfig)
	defer db.Close()

	// Verify database connectivity
	pingCtx, pingCancel := context.WithTimeout(ctx, 5*time.Second)
	defer pingCancel()
	if err := db.PingContext(pingCtx); err != nil {
		return fmt.Errorf("failed to ping database before running migrations: %w", err)
	}

	// Detect legacy schema created without schema_migrations
	isLegacy, err := DetectLegacySchema(ctx, db)
	if err != nil {
		return err
	}
	allowBaseline := strings.ToLower(os.Getenv("BASELINE_ON_LEGACY")) == "true" || os.Getenv("BASELINE_ON_LEGACY") == "1"
	if isLegacy && !allowBaseline {
		return ErrLegacyDatabaseDetected
	}

	// pgx driver automatically acquires a PostgreSQL session-level advisory lock
	driver, err := pgxmigrate.WithInstance(db, &pgxmigrate.Config{
		MigrationsTable: pgxmigrate.DefaultMigrationsTable,
	})
	if err != nil {
		return fmt.Errorf("failed to instantiate pgx migration driver: %w", err)
	}

	sourceDriver, err := iofs.New(FS, ".")
	if err != nil {
		return fmt.Errorf("failed to instantiate iofs migration driver: %w", err)
	}

	m, err := migrate.NewWithInstance("iofs", sourceDriver, "postgres", driver)
	if err != nil {
		return fmt.Errorf("failed to create migrate instance: %w", err)
	}
	defer m.Close()

	if isLegacy && allowBaseline {
		logger.Warn("legacy database detected without schema_migrations; baselining to version 1 as requested by BASELINE_ON_LEGACY")
		if err := m.Force(1); err != nil {
			return fmt.Errorf("failed to baseline legacy database to version 1: %w", err)
		}
	}

	start := time.Now()
	if err := m.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			logger.Info("database schema is already up-to-date (no migrations required)")
			return nil
		}
		return fmt.Errorf("database migration failed: %w", err)
	}

	version, dirty, _ := m.Version()
	logger.Info("database migrations applied successfully",
		"version", version,
		"dirty", dirty,
		"duration", time.Since(start).String(),
	)

	return nil
}

// GetEmbeddedMigrationFiles returns the list of all embedded .sql migration filenames.
func GetEmbeddedMigrationFiles() ([]string, error) {
	entries, err := FS.ReadDir(".")
	if err != nil {
		return nil, err
	}
	var files []string
	for _, entry := range entries {
		if !entry.IsDir() {
			files = append(files, entry.Name())
		}
	}
	return files, nil
}
