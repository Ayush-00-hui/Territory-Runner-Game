package api

import (
	"net/http"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

// SetupRouter initializes the Chi router with middlewares, routes, and authentication.
func SetupRouter(api *API, authenticator *auth.Authenticator) http.Handler {
	r := chi.NewRouter()

	// Standard production middlewares
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Permissive CORS for local flutter dev and web clients
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Dev-User", "Idempotency-Key"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Public Health Endpoint
	r.Get("/healthz", api.HandleHealthz)

	// Real-Time WebSocket Route
	r.Get("/v1/ws", api.HandleWebSocket)

	// API v1 routes
	r.Route("/v1", func(v1 chi.Router) {
		v1.Use(authenticator.Middleware)

		v1.Get("/me", api.HandleGetMe)
		v1.Post("/runs", api.HandleSubmitRun)
		v1.Get("/runs", api.HandleGetRuns)
		v1.Post("/runs/{id}/coach", api.HandleRunCoach)
		v1.Get("/territories", api.HandleGetTerritories)
		v1.Get("/leaderboard", api.HandleGetLeaderboard)
	})

	return r
}
