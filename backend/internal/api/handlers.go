package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/ws"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

// API encapsulates HTTP handlers and service dependencies.
type API struct {
	store             store.Store
	geoEng            *geo.Engine
	detector          *anticheat.Detector
	coachSvc          *coach.Service
	wsHub             *ws.Hub
	authenticator     *auth.Authenticator
	logger            *slog.Logger
	maxPointsPerRun   int
	maxRunDurationSec int
	runsLimiter       *RateLimiter
	coachLimiter      *RateLimiter
}

// Option configures API dependencies.
type Option func(*API)

// WithCoachService injects a custom coach service.
func WithCoachService(svc *coach.Service) Option {
	return func(a *API) {
		if svc != nil {
			a.coachSvc = svc
		}
	}
}

// WithWebSocketHub injects a real-time WebSocket hub.
func WithWebSocketHub(hub *ws.Hub) Option {
	return func(a *API) {
		a.wsHub = hub
	}
}

// WithAuthenticator injects the authenticator for WebSocket handshakes.
func WithAuthenticator(auth *auth.Authenticator) Option {
	return func(a *API) {
		a.authenticator = auth
	}
}

// WithLimits configures maximum points per run and maximum duration.
func WithLimits(maxPoints, maxDurationSec int) Option {
	return func(a *API) {
		if maxPoints > 0 {
			a.maxPointsPerRun = maxPoints
		}
		if maxDurationSec > 0 {
			a.maxRunDurationSec = maxDurationSec
		}
	}
}

// WithRateLimiters injects custom rate limiters for runs and coach endpoints.
func WithRateLimiters(runsLimiter, coachLimiter *RateLimiter) Option {
	return func(a *API) {
		if runsLimiter != nil {
			a.runsLimiter = runsLimiter
		}
		if coachLimiter != nil {
			a.coachLimiter = coachLimiter
		}
	}
}

// RunsLimiter returns the runs endpoint rate limiter.
func (a *API) RunsLimiter() *RateLimiter {
	return a.runsLimiter
}

// CoachLimiter returns the coach endpoint rate limiter.
func (a *API) CoachLimiter() *RateLimiter {
	return a.coachLimiter
}

// NewAPI creates an API handler instance.
func NewAPI(s store.Store, logger *slog.Logger, opts ...Option) *API {
	if logger == nil {
		logger = slog.Default()
	}
	a := &API{
		store:             s,
		geoEng:            geo.NewEngine(),
		detector:          anticheat.NewDetector(),
		coachSvc:          coach.NewService("", coach.WithLogger(logger)),
		logger:            logger,
		maxPointsPerRun:   20000,
		maxRunDurationSec: 86400,
		// Default rate limit: 10 burst, refill 0.5/sec (1 token per 2 sec)
		runsLimiter: NewRateLimiter(0.5, 10),
		// Coach rate limit: 5 burst, refill 0.2/sec (1 token per 5 sec)
		coachLimiter: NewRateLimiter(0.2, 5),
	}
	for _, opt := range opts {
		opt(a)
	}
	return a
}

// HandleHealthz handles GET /healthz liveness checks.
func (a *API) HandleHealthz(w http.ResponseWriter, r *http.Request) {
	dbStatus := "connected"
	if err := a.store.Ping(r.Context()); err != nil {
		dbStatus = "disconnected: " + err.Error()
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ok",
		"database": dbStatus,
		"time":     time.Now().UTC().Format(time.RFC3339),
	})
}

// HandleGetMe handles GET /v1/me runner profile.
func (a *API) HandleGetMe(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	u, err := a.store.GetUser(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to fetch user", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to load user profile")
		return
	}

	if u == nil {
		// Auto-initialize profile for new runner
		u = &store.User{
			ID:           uid,
			Username:     "Runner_" + uid[:min(6, len(uid))],
			Faction:      "Cyber Vanguard",
			TotalAreaSqm: 0.0,
			XP:           0,
			Level:        1,
			TotalRuns:    0,
			CreatedAt:    time.Now().UTC(),
		}
		if err := a.store.UpsertUser(r.Context(), u); err != nil {
			a.logger.Error("failed to create user", "error", err, "uid", uid)
		}
	}

	writeJSON(w, http.StatusOK, u)
}

// SubmitRunRequest defines the payload for POST /v1/runs.
type SubmitRunRequest struct {
	IdempotencyKey  string           `json:"idempotency_key"`
	Points          []geo.TrackPoint `json:"points"`
	DurationSeconds int              `json:"duration_seconds"`
	DistanceMeters  float64          `json:"distance_meters"`
	ClientPreview   *ClientPreview   `json:"client_preview,omitempty"`
}

type ClientPreview struct {
	AreaClaimed float64 `json:"area_claimed"`
	XpAwarded   int     `json:"xp_awarded"`
}

// HandleSubmitRun handles POST /v1/runs.
func (a *API) HandleSubmitRun(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	// 1. Enforce 2 MB maximum payload size to prevent memory exhaustion
	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)

	var req SubmitRunRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) || strings.Contains(err.Error(), "request body too large") {
			writeError(w, http.StatusRequestEntityTooLarge, "PAYLOAD_TOO_LARGE", "Request body exceeds maximum permitted size of 2 MB")
			return
		}
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed JSON request body")
		return
	}

	if req.IdempotencyKey == "" {
		writeError(w, http.StatusBadRequest, "MISSING_KEY", "idempotency_key is required")
		return
	}

	// 2. Validate point counts against configured limits
	if len(req.Points) < 3 {
		writeError(w, http.StatusBadRequest, "INSUFFICIENT_POINTS", "A minimum of 3 track points is required to form a run")
		return
	}
	maxPts := a.maxPointsPerRun
	if maxPts <= 0 {
		maxPts = 20000
	}
	if len(req.Points) > maxPts {
		writeError(w, http.StatusBadRequest, "TOO_MANY_POINTS", fmt.Sprintf("Run exceeds maximum allowed track points (%d)", maxPts))
		return
	}

	// 3. Validate run duration limits
	maxDur := a.maxRunDurationSec
	if maxDur <= 0 {
		maxDur = 86400
	}
	if req.DurationSeconds < 0 || req.DurationSeconds > maxDur {
		writeError(w, http.StatusBadRequest, "INVALID_DURATION", fmt.Sprintf("Run duration must be between 0 and %d seconds", maxDur))
		return
	}

	// 4. Reject non-monotonic timestamps
	for i := 1; i < len(req.Points); i++ {
		if !req.Points[i].Timestamp.IsZero() && !req.Points[i-1].Timestamp.IsZero() {
			if req.Points[i].Timestamp.Before(req.Points[i-1].Timestamp) {
				writeError(w, http.StatusBadRequest, "NON_MONOTONIC_TIMESTAMPS", "Track points must have monotonically non-decreasing timestamps")
				return
			}
		}
	}

	// 5. Fast-path: Check for idempotent replay
	if existing, err := a.store.GetRunByIdempotencyKey(r.Context(), req.IdempotencyKey); err == nil && existing != nil {
		a.logger.Info("idempotent replay served", "key", req.IdempotencyKey, "run_id", existing.ID)
		res, _ := a.store.CaptureRunAndMutateTerritories(r.Context(), existing, nil, nil)
		writeJSON(w, http.StatusOK, res)
		return
	}

	// 2. Anti-cheat / GPS Anomaly Detection & Spoofing Mitigation
	anomalyRes := a.detector.EvaluateTrack(req.Points)
	if anomalyRes.IsAnomaly && anomalyRes.Score >= 50.0 {
		a.logger.Warn("run rejected due to critical anomaly", "score", anomalyRes.Score, "reasons", anomalyRes.Reasons)
		writeError(w, http.StatusUnprocessableEntity, "ANOMALY_REJECTED", strings.Join(anomalyRes.Reasons, "; "))
		return
	}

	// 3. Spatial loop enclosure detection using exact Dart engine rules
	loops, err := a.geoEng.ProcessTrack(req.Points)
	if err != nil {
		if errors.Is(err, geo.ErrLoopSelfIntersecting) {
			writeError(w, http.StatusBadRequest, "INVALID_LOOP", "Loop crossed itself — try again")
			return
		}
		if errors.Is(err, geo.ErrLoopAreaTooLarge) {
			writeError(w, http.StatusBadRequest, "INVALID_LOOP", err.Error())
			return
		}
		a.logger.Warn("loop extraction warning", "error", err)
	}

	runID := "run_" + uuid.New().String()
	runRecord := &store.Run{
		ID:              runID,
		UserID:          uid,
		IdempotencyKey:  req.IdempotencyKey,
		DurationSeconds: req.DurationSeconds,
		DistanceMeters:  req.DistanceMeters,
		AnomalyScore:    anomalyRes.Score,
		AnomalyReasons:  anomalyRes.Reasons,
		Status:          "accepted",
	}
	if anomalyRes.IsAnomaly {
		runRecord.Status = "flagged_review"
	}

	result, err := a.store.CaptureRunAndMutateTerritories(r.Context(), runRecord, loops, req.Points)
	if err != nil {
		a.logger.Error("failed to capture run and mutate territories", "error", err)
		writeError(w, http.StatusInternalServerError, "TRANSACTION_FAILED", "Failed to persist territory capture")
		return
	}

	// 5. Fan out real-time conquest broadcast and targeted victim alerts
	if a.wsHub != nil && result.LoopDetected && result.AreaClaimedSqm > 0 {
		username := "Runner_" + uid[:min(6, len(uid))]
		if u, err := a.store.GetUser(r.Context(), uid); err == nil && u != nil {
			username = u.Username
		}
		a.wsHub.BroadcastConquest(uid, username, result.AreaClaimedSqm, result.RivalsAffected)
	}

	writeJSON(w, http.StatusCreated, result)
}

// HandleGetRuns handles GET /v1/runs.
func (a *API) HandleGetRuns(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	limit := 20
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	runs, err := a.store.GetRunsByUser(r.Context(), uid, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve runs")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"runs":  runs,
		"total": len(runs),
	})
}

// HandleGetTerritories handles GET /v1/territories?bbox=minLng,minLat,maxLng,maxLat.
func (a *API) HandleGetTerritories(w http.ResponseWriter, r *http.Request) {
	bboxStr := r.URL.Query().Get("bbox")
	var minLng, minLat, maxLng, maxLat float64
	var err error

	if bboxStr != "" {
		parts := strings.Split(bboxStr, ",")
		if len(parts) == 4 {
			minLng, err = strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
			minLat, _ = strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
			maxLng, _ = strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
			maxLat, _ = strconv.ParseFloat(strings.TrimSpace(parts[3]), 64)
		}
	}

	// Default fallback bbox if unspecified: global or full map extent
	if minLng == 0 && maxLng == 0 {
		minLng, minLat, maxLng, maxLat = -180.0, -90.0, 180.0, 90.0
	}

	territories, err := a.store.GetTerritoriesInBBox(r.Context(), minLng, minLat, maxLng, maxLat)
	if err != nil {
		a.logger.Error("failed to query territories in bbox", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to load territories")
		return
	}

	currentUID := auth.GetUserID(r.Context())

	// Format as standard GeoJSON FeatureCollection
	features := make([]map[string]interface{}, 0, len(territories))
	for _, t := range territories {
		var geomObj interface{}
		if t.GeoJSON != "" {
			_ = json.Unmarshal([]byte(t.GeoJSON), &geomObj)
		}
		feat := map[string]interface{}{
			"type": "Feature",
			"id":   t.ID,
			"properties": map[string]interface{}{
				"owner_id":         t.OwnerID,
				"username":         t.Username,
				"is_self":          t.OwnerID == currentUID,
				"area_sqm":         t.AreaSqm,
				"strength":         t.Strength,
				"last_defended_at": t.LastDefendedAt,
				"updated_at":       t.UpdatedAt,
			},
			"geometry": geomObj,
		}
		features = append(features, feat)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"type":     "FeatureCollection",
		"features": features,
	})
}

// HandleGetLeaderboard handles GET /v1/leaderboard.
func (a *API) HandleGetLeaderboard(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	lb, err := a.store.GetLeaderboard(r.Context(), limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to load leaderboard")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"leaderboard": lb,
	})
}

// HandleRunCoach handles POST /v1/runs/{id}/coach.
func (a *API) HandleRunCoach(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	runID := chi.URLParam(r, "id")
	if runID == "" {
		writeError(w, http.StatusBadRequest, "INVALID_RUN_ID", "Run ID is required")
		return
	}

	var req coach.RunContext
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&req)
	}
	req.RunID = runID

	insight := a.coachSvc.GenerateInsight(r.Context(), req)
	writeJSON(w, http.StatusOK, insight)
}

// HandleWebSocket handles GET /v1/ws real-time WebSocket connection upgrades.
func (a *API) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	if a.wsHub == nil {
		writeError(w, http.StatusServiceUnavailable, "WS_DISABLED", "WebSocket hub is not enabled")
		return
	}

	uid := auth.GetUserID(r.Context())
	if uid == "" && a.authenticator != nil {
		var err error
		uid, err = a.authenticator.AuthenticateRequest(r)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing or invalid credentials for WebSocket")
			return
		}
	}
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing authentication credentials for WebSocket")
		return
	}

	username := "Runner_" + uid[:min(6, len(uid))]
	faction := "Cyber Vanguard"
	if u, err := a.store.GetUser(r.Context(), uid); err == nil && u != nil {
		username = u.Username
		faction = u.Faction
	}

	a.wsHub.ServeWS(w, r, uid, username, faction)
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, code, detail string) {
	writeJSON(w, status, map[string]string{
		"error":  code,
		"detail": detail,
	})
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
