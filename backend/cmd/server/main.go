package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/migrations"
)

func main() {
	// 0. Handle container healthcheck subcommand
	if len(os.Args) > 1 && (os.Args[1] == "healthcheck" || os.Args[1] == "--healthcheck") {
		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}
		client := &http.Client{Timeout: 3 * time.Second}
		resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/healthz", port))
		if err != nil || resp.StatusCode != http.StatusOK {
			if err != nil {
				fmt.Fprintf(os.Stderr, "healthcheck failed: %v\n", err)
			} else {
				fmt.Fprintf(os.Stderr, "healthcheck returned HTTP %d\n", resp.StatusCode)
			}
			os.Exit(1)
		}
		os.Exit(0)
	}

	// Structured JSON logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	loadLocalEnv()

	logger.Info("starting Territory Runner Go backend server")

	cfg, err := config.Load()
	if err != nil {
		logger.Error("configuration error", "error", err)
		os.Exit(1)
	}

	logger.Info("configuration loaded",
		"env", cfg.Env,
		"auth_mode", cfg.AuthMode,
		"port", cfg.Port,
	)

	// Context for DB setup and graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Automated database migrations (guarded by PostgreSQL advisory lock via golang-migrate)
	if cfg.RunMigrations {
		logger.Info("running automated database migrations (RUN_MIGRATIONS=true)")
		migCtx, migCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer migCancel()
		if err := migrations.Run(migCtx, cfg.DatabaseURL, logger); err != nil {
			logger.Error("database migration failure", "error", err)
			os.Exit(1)
		}
	}

	var dataStore store.Store

	pgStore, err := store.NewPostgresStore(ctx, cfg.DatabaseURL)
	if err != nil {
		if cfg.Env == "production" {
			logger.Error("fatal: could not connect to PostgreSQL/PostGIS in production", "error", err)
			os.Exit(1)
		}
		logger.Warn("PostgreSQL/PostGIS unavailable; falling back to in-memory store for local dev", "error", err)
		dataStore = store.NewMemoryStore()
	} else {
		logger.Info("connected to PostgreSQL/PostGIS successfully")
		dataStore = pgStore
	}
	defer dataStore.Close()

	authenticator := auth.NewAuthenticator(cfg)
	coachSvc := coach.NewService(cfg.GeminiAPIKey, coach.WithModel(cfg.GeminiModel), coach.WithLogger(logger))
	wsHub := ws.NewHub(logger, ws.WithAllowedOrigins(cfg.AllowedOrigins))
	go wsHub.Run()
	defer wsHub.Stop()

	fcmNotifier := notify.NewFCMClient(dataStore, logger)

	// Periodic territory decay worker (runs hourly to decay inactive territory strength at 15.0%/day)
	decayCtx, cancelDecay := context.WithCancel(context.Background())
	defer cancelDecay()
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		defer ticker.Stop()
		for {
			select {
			case <-decayCtx.Done():
				return
			case <-ticker.C:
				if err := dataStore.ApplyTerritoryDecay(decayCtx, 15.0); err != nil && !errors.Is(err, context.Canceled) {
					logger.Warn("periodic territory decay encountered error", "error", err)
				}
			}
		}
	}()

	apiHandler := api.NewAPI(dataStore, logger,
		api.WithCoachService(coachSvc),
		api.WithWebSocketHub(wsHub),
		api.WithNotifier(fcmNotifier),
		api.WithAuthenticator(authenticator),
		api.WithLimits(cfg.MaxPointsPerRun, cfg.MaxRunDurationSec),
		api.WithMetricsToken(cfg.MetricsToken),
		api.WithTrustedProxies(cfg.TrustedProxies),
	)
	router := api.SetupRouter(apiHandler, authenticator, cfg.AllowedOrigins...)


	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Server shutdown channel
	serverErrors := make(chan error, 1)

	go func() {
		logger.Info("HTTP server listening", "addr", server.Addr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrors <- fmt.Errorf("HTTP listen error: %w", err)
		}
	}()

	// Graceful shutdown listener
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		logger.Error("server fatal error", "error", err)
		os.Exit(1)
	case sig := <-shutdown:
		logger.Info("shutdown signal received", "signal", sig.String())
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		if err := server.Shutdown(shutdownCtx); err != nil {
			logger.Error("graceful shutdown failed", "error", err)
			_ = server.Close()
		}
		logger.Info("server stopped cleanly")
	}
}

func loadLocalEnv() {
	paths := []string{".env", "../.env"}
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err == nil {
			for _, line := range strings.Split(string(data), "\n") {
				line = strings.TrimSpace(line)
				if line == "" || strings.HasPrefix(line, "#") {
					continue
				}
				parts := strings.SplitN(line, "=", 2)
				if len(parts) == 2 {
					key := strings.TrimSpace(parts[0])
					val := strings.TrimSpace(parts[1])
					if _, exists := os.LookupEnv(key); !exists {
						os.Setenv(key, val)
					}
				}
			}
			return
		}
	}
}
