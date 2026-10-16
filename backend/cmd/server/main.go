package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/api"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
)

func main() {
	// Structured JSON logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

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

	apiHandler := api.NewAPI(dataStore, logger,
		api.WithCoachService(coachSvc),
		api.WithWebSocketHub(wsHub),
		api.WithAuthenticator(authenticator),
		api.WithLimits(cfg.MaxPointsPerRun, cfg.MaxRunDurationSec),
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
