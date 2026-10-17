package api

import (
	"net/http"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

// SetupRouter initializes the Chi router with middlewares, routes, and authentication.
func SetupRouter(api *API, authenticator *auth.Authenticator, allowedOrigins ...string) http.Handler {
	r := chi.NewRouter()

	// Standard production middlewares
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	origins := allowedOrigins
	if len(origins) == 0 {
		origins = []string{"*"}
	}

	allowCredentials := true
	for _, o := range origins {
		if o == "*" {
			// Per CORS specification, wildcard '*' cannot be used with AllowCredentials: true
			allowCredentials = false
			break
		}
	}

	// CORS configuration based on allowed origins
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   origins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Dev-User", "Idempotency-Key"},
		ExposedHeaders:   []string{"Link", "Retry-After"},
		AllowCredentials: allowCredentials,
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

		// Per-user and per-IP rate-limited runs submission
		if api.runsLimiter != nil {
			v1.With(RateLimitMiddleware(api.runsLimiter)).Post("/runs", api.HandleSubmitRun)
		} else {
			v1.Post("/runs", api.HandleSubmitRun)
		}

		v1.Get("/runs", api.HandleGetRuns)

		// Per-user and per-IP rate-limited coach generation
		if api.coachLimiter != nil {
			v1.With(RateLimitMiddleware(api.coachLimiter)).Post("/runs/{id}/coach", api.HandleRunCoach)
		} else {
			v1.Post("/runs/{id}/coach", api.HandleRunCoach)
		}

		v1.Get("/territories", api.HandleGetTerritories)
		v1.Get("/leaderboard", api.HandleGetLeaderboard)
		v1.Post("/device-token", api.HandleRegisterDeviceToken)
		v1.Get("/league/current", api.HandleGetCurrentLeague)
		v1.Get("/factions/standings", api.HandleGetFactionStandings)
		v1.Put("/me/faction", api.HandleUpdateUserFaction)
	})

	return r
}
