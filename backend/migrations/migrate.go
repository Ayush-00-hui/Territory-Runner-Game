package migrations

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/golang-migrate/migrate/v4"
	pgxmigrate "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
)

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
