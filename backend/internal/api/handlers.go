package api

import (
	"context"
	cryptorand "crypto/rand"
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
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/league"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/notify"
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
	notifier          notify.Notifier
	authenticator     *auth.Authenticator
	logger            *slog.Logger
	maxPointsPerRun   int
	maxRunDurationSec int
	runsLimiter       *RateLimiter
	coachLimiter      *RateLimiter
	metrics           *MetricsCollector
	metricsToken      string
	trustedProxies    *TrustedProxyChecker
	teamDenyList      []string
	teamLimiter       *RateLimiter
}

// Option configures API dependencies.
type Option func(*API)

// WithNotifier injects an FCM push alert notifier.
func WithNotifier(n notify.Notifier) Option {
	return func(a *API) {
		a.notifier = n
	}
}

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

// WithMetrics configures a custom metrics collector.
func WithMetrics(m *MetricsCollector) Option {
	return func(a *API) {
		if m != nil {
			a.metrics = m
		}
	}
}

// WithMetricsToken configures a secret bearer token required for GET /metrics scraping.
func WithMetricsToken(token string) Option {
	return func(a *API) {
		a.metricsToken = token
	}
}

// WithTrustedProxies configures trusted upstream proxy CIDRs/IPs for rate limiting and IP validation.
func WithTrustedProxies(proxies string) Option {
	return func(a *API) {
		a.trustedProxies = ParseTrustedProxies(proxies)
		if a.runsLimiter != nil {
			a.runsLimiter.SetTrustedProxies(proxies)
		}
		if a.coachLimiter != nil {
			a.coachLimiter.SetTrustedProxies(proxies)
		}
		if a.teamLimiter != nil {
			a.teamLimiter.SetTrustedProxies(proxies)
		}
	}
}

// WithTeamDenyList configures a custom deny-list of prohibited or abusive terms for team names.
func WithTeamDenyList(denyList []string) Option {
	return func(a *API) {
		a.teamDenyList = denyList
	}
}

// WithTeamLimiter configures a custom rate limiter for team/faction changes.
func WithTeamLimiter(limiter *RateLimiter) Option {
	return func(a *API) {
		if limiter != nil {
			a.teamLimiter = limiter
		}
	}
}

// RunsLimiter returns the runs endpoint rate limiter.
func (a *API) RunsLimiter() *RateLimiter {

	return a.runsLimiter
}

// WithDetector configures a custom anticheat detector.
func WithDetector(d *anticheat.Detector) Option {
	return func(a *API) {
		if d != nil {
			a.detector = d
		}
	}
}

// WithCadenceModel configures whether the Tier 2 ML cadence model is enabled in the detector.
func WithCadenceModel(enabled bool) Option {
	return func(a *API) {
		cfg := a.detector.Config()
		cfg.EnableCadenceModel = enabled
		cfg.EnableMLTier2 = enabled
		a.detector = anticheat.NewDetectorWithEnsemble(a.detector.MLEnsemble(), cfg)
	}
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
		// Team change rate limit: 3 changes per day (capacity 3, refill rate 3/86400 per second)
		teamLimiter: NewRateLimiter(3.0/86400.0, 3.0),
		metrics:     NewMetricsCollector(),
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

// HandleReadyz handles GET /readyz readiness checks verifying database connectivity.
func (a *API) HandleReadyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := a.store.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "unhealthy",
			"error":  err.Error(),
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ready",
		"database": "connected",
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
		// Auto-initialize profile for new runner with a permanent unique RunnerCode
		u = &store.User{
			ID:           uid,
			RunnerCode:   store.GenerateRunnerCode(),
			Username:     "Runner_" + uid[:min(6, len(uid))],
			Faction:      "",
			TotalAreaSqm: 0.0,
			XP:           0,
			Level:        1,
			TotalRuns:    0,
			CreatedAt:    time.Now().UTC(),
		}
		if err := a.store.UpsertUser(r.Context(), u); err != nil {
			a.logger.Error("failed to create user", "error", err, "uid", uid)
		}
	} else {
		u.Faction = SanitizeTeamName(u.Faction)
	}

	writeJSON(w, http.StatusOK, u)
}

// UpdateMeRequest carries updates to a runner's profile upon login or profile edits.
type UpdateMeRequest struct {
	Username string `json:"username"`
}

// HandleUpdateMe handles PUT /v1/me to sync username and ensure a permanent unique runner_code.
func (a *API) HandleUpdateMe(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req UpdateMeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}

	cleaned := strings.Join(strings.Fields(strings.TrimSpace(req.Username)), " ")
	if cleaned == "" {
		writeError(w, http.StatusBadRequest, "INVALID_USERNAME", "Runner name cannot be empty")
		return
	}
	if strings.ContainsAny(cleaned, "<>") {
		writeError(w, http.StatusBadRequest, "INVALID_USERNAME", "Runner name cannot contain angle brackets")
		return
	}
	runes := []rune(cleaned)
	if len(runes) < 2 || len(runes) > 24 {
		writeError(w, http.StatusBadRequest, "INVALID_USERNAME", "Runner name must be between 2 and 24 characters")
		return
	}

	u, err := a.store.UpdateUsername(r.Context(), uid, cleaned)
	if err != nil {
		a.logger.Error("failed to update runner profile", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update runner profile")
		return
	}
	u.Faction = SanitizeTeamName(u.Faction)
	writeJSON(w, http.StatusOK, u)
}

// HandleSearchUsers handles GET /v1/users/search?q=... to discover friends by Runner ID or Name.
func (a *API) HandleSearchUsers(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if query == "" {
		writeJSON(w, http.StatusOK, []store.UserSearchResult{})
		return
	}

	results, err := a.store.SearchUsers(r.Context(), uid, query, 20)
	if err != nil {
		a.logger.Error("failed to search users", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to search runners")
		return
	}
	if results == nil {
		results = []store.UserSearchResult{}
	}
	for i := range results {
		results[i].Faction = SanitizeTeamName(results[i].Faction)
	}

	writeJSON(w, http.StatusOK, results)
}

// HandleDeleteMe handles DELETE /v1/me runner account deletion and data purge.
func (a *API) HandleDeleteMe(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	a.logger.Info("purging user account and cascading data", "uid", uid)
	if err := a.store.DeleteUser(r.Context(), uid); err != nil {
		a.logger.Error("failed to delete user account", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to delete user account")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "deleted",
		"message": "User account and all associated data have been permanently purged",
		"user_id": uid,
	})
}

// PrivacyZonesPayload encapsulates privacy zones GET/PUT payload.
type PrivacyZonesPayload struct {
	PrivacyZones []store.PrivacyZone `json:"privacy_zones"`
}

// HandleGetPrivacyZones handles GET /v1/me/privacy-zones.
func (a *API) HandleGetPrivacyZones(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	zones, err := a.store.GetPrivacyZones(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to get privacy zones", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve privacy zones")
		return
	}

	writeJSON(w, http.StatusOK, PrivacyZonesPayload{PrivacyZones: zones})
}

// HandleUpdatePrivacyZones handles PUT /v1/me/privacy-zones.
func (a *API) HandleUpdatePrivacyZones(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var payload PrivacyZonesPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	// Limit count to prevent abuse (maximum 5 zones per runner)
	if len(payload.PrivacyZones) > 5 {
		writeError(w, http.StatusBadRequest, "MAX_ZONES_EXCEEDED", "Maximum 5 privacy zones allowed per user")
		return
	}

	cleaned := make([]store.PrivacyZone, 0, len(payload.PrivacyZones))
	evals := make([]geo.PrivacyZoneEvaluator, 0, len(payload.PrivacyZones))
	now := time.Now().UTC()

	for _, z := range payload.PrivacyZones {
		// Enforce reasonable radius boundaries (50m to 2000m)
		if z.RadiusMeters < 50.0 || z.RadiusMeters > 2000.0 {
			writeError(w, http.StatusBadRequest, "INVALID_RADIUS", "Privacy zone radius must be between 50m and 2000m")
			return
		}

		if z.Latitude < -90.0 || z.Latitude > 90.0 || z.Longitude < -180.0 || z.Longitude > 180.0 {
			writeError(w, http.StatusBadRequest, "INVALID_COORDINATES", "Coordinates must be valid WGS84 coordinates")
			return
		}

		name := strings.TrimSpace(z.Name)
		if name == "" {
			name = "Privacy Zone"
		}
		if len(name) > 100 {
			name = name[:100]
		}

		id := strings.TrimSpace(z.ID)
		if id == "" {
			id = "zone_" + uuid.New().String()
		}

		createdAt := z.CreatedAt
		if createdAt.IsZero() {
			createdAt = now
		}

		zone := store.PrivacyZone{
			ID:           id,
			UserID:       uid,
			Name:         name,
			Latitude:     z.Latitude,
			Longitude:    z.Longitude,
			RadiusMeters: z.RadiusMeters,
			IsEnabled:    z.IsEnabled,
			CreatedAt:    createdAt,
		}
		cleaned = append(cleaned, zone)
		evals = append(evals, geo.PrivacyZoneEvaluator{
			Latitude:     z.Latitude,
			Longitude:    z.Longitude,
			RadiusMeters: z.RadiusMeters,
			IsEnabled:    z.IsEnabled,
		})
	}

	if err := a.store.SetPrivacyZones(r.Context(), uid, cleaned); err != nil {
		a.logger.Error("failed to save privacy zones", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to persist privacy zones")
		return
	}

	// Update WebSocket hub exclusion cache
	if a.wsHub != nil {
		a.wsHub.UpdateUserPrivacyZones(uid, evals)
	}

	writeJSON(w, http.StatusOK, PrivacyZonesPayload{PrivacyZones: cleaned})
}

// SubmitRunRequest defines the payload for POST /v1/runs.
type SubmitRunRequest struct {
	IdempotencyKey  string                   `json:"idempotency_key"`
	ActivityType    string                   `json:"activity_type,omitempty"`
	StepCount       *int                     `json:"step_count,omitempty"`
	Points          []geo.TrackPoint         `json:"points"`
	DurationSeconds int                      `json:"duration_seconds"`
	DistanceMeters  float64                  `json:"distance_meters"`
	ClientPreview   *ClientPreview           `json:"client_preview,omitempty"`
	MotionWindows   []anticheat.MotionWindow `json:"motion_windows,omitempty"`
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

	activityType := strings.ToLower(strings.TrimSpace(req.ActivityType))
	if activityType == "" {
		activityType = "running"
	}
	if activityType != "running" && activityType != "walking" && activityType != "cycling" {
		writeError(w, http.StatusBadRequest, "INVALID_ACTIVITY_TYPE", "Activity type must be 'running', 'walking', or 'cycling'")
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

	// 4. Server timestamp hygiene & track integrity validation
	now := time.Now().UTC()
	if req.DurationSeconds > 30 {
		for _, pt := range req.Points {
			if pt.Timestamp.IsZero() {
				writeError(w, http.StatusBadRequest, "MISSING_TIMESTAMPS", "Track points with zero or missing timestamps are not permitted for runs > 30s")
				return
			}
		}
	}
	for i := 0; i < len(req.Points); i++ {
		ts := req.Points[i].Timestamp
		if !ts.IsZero() {
			if ts.After(now.Add(10 * time.Minute)) {
				writeError(w, http.StatusBadRequest, "FUTURE_TIMESTAMPS", "Track point timestamp is in the future")
				return
			}
			if ts.Before(now.Add(-14 * 24 * time.Hour)) {
				writeError(w, http.StatusBadRequest, "EXPIRED_RUN", "Track point timestamps exceed maximum allowed offline buffering age of 14 days")
				return
			}
		}
		if i > 0 && !ts.IsZero() && !req.Points[i-1].Timestamp.IsZero() {
			if ts.Before(req.Points[i-1].Timestamp) {
				writeError(w, http.StatusBadRequest, "NON_MONOTONIC_TIMESTAMPS", "Track points must have monotonically non-decreasing timestamps")
				return
			}
		}
	}

	// Reject tracks that consist entirely of duplicate coordinates (zero displacement)
	allIdenticalCoords := true
	for i := 1; i < len(req.Points); i++ {
		if req.Points[i].Latitude != req.Points[0].Latitude || req.Points[i].Longitude != req.Points[0].Longitude {
			allIdenticalCoords = false
			break
		}
	}
	if allIdenticalCoords {
		writeError(w, http.StatusBadRequest, "DUPLICATE_POINTS", "Track consists entirely of duplicate or zero-displacement points")
		return
	}

	// 5. Fast-path: Check for idempotent replay
	if existing, err := a.store.GetRunByIdempotencyKey(r.Context(), req.IdempotencyKey); err == nil && existing != nil {
		a.logger.Info("idempotent replay served", "key", req.IdempotencyKey, "run_id", existing.ID)
		res, _ := a.store.CaptureRunAndMutateTerritories(r.Context(), existing, nil, nil)
		if existing.Status == "flagged_review" {
			writeJSON(w, http.StatusAccepted, res)
			return
		}
		writeJSON(w, http.StatusOK, res)
		return
	}

	// 6. Anti-cheat / GPS Anomaly Detection & Spoofing Mitigation (activity-aware & motion-aware)
	anomalyRes := a.detector.EvaluateTrackWithMotion(req.Points, activityType, req.DurationSeconds, req.DistanceMeters, req.MotionWindows)
	if anomalyRes.IsAnomaly && anomalyRes.Score >= 50.0 {
		a.logger.Warn("run rejected due to critical anomaly", "score", anomalyRes.Score, "reasons", anomalyRes.Reasons, "activity_type", activityType)
		writeError(w, http.StatusUnprocessableEntity, "ANOMALY_REJECTED", strings.Join(anomalyRes.Reasons, "; "))
		return
	}

	// 7. Spatial loop enclosure detection using activity-aware kinematics
	loops, err := geo.ProcessTrackWithActivity(req.Points, activityType)
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
		ID:                 runID,
		UserID:             uid,
		IdempotencyKey:     req.IdempotencyKey,
		ActivityType:       activityType,
		StepCount:          req.StepCount,
		DurationSeconds:    req.DurationSeconds,
		DistanceMeters:     req.DistanceMeters,
		AnomalyScore:       anomalyRes.Score,
		AnomalyReasons:     anomalyRes.Reasons,
		VerificationStatus: anomalyRes.VerificationStatus,
		Status:             "accepted",
	}
	if anomalyRes.IsAnomaly {
		runRecord.Status = "flagged_review"
		loops = nil
	}

	result, err := a.store.CaptureRunAndMutateTerritories(r.Context(), runRecord, loops, req.Points)
	if err != nil {
		a.logger.Error("failed to capture run and mutate territories", "error", err)
		writeError(w, http.StatusInternalServerError, "TRANSACTION_FAILED", "Failed to persist territory capture")
		return
	}

	if runRecord.Status == "flagged_review" {
		writeJSON(w, http.StatusAccepted, result)
		return
	}

	// 5. Fan out real-time conquest broadcast and push notifications
	if result.LoopDetected && result.AreaClaimedSqm > 0 {
		username := "Runner_" + uid[:min(6, len(uid))]
		if u, err := a.store.GetUser(r.Context(), uid); err == nil && u != nil {
			username = u.Username
		}
		if a.wsHub != nil {
			a.wsHub.BroadcastConquest(uid, username, result.AreaClaimedSqm, result.RivalsAffected)
		}
		if a.notifier != nil && len(result.RivalsAffected) > 0 {
			go func(rivals []string, territoryID, runnerName string, area float64) {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				for _, rUID := range rivals {
					_ = a.notifier.SendTerritoryAlertToUser(ctx, rUID, territoryID, runnerName, area)
				}
			}(result.RivalsAffected, result.RunID, username, result.AreaClaimedSqm)
		}
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
	activityType := r.URL.Query().Get("activity_type")

	lb, err := a.store.GetLeaderboard(r.Context(), limit, activityType)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to load leaderboard")
		return
	}

	for i := range lb {
		lb[i].Faction = SanitizeTeamName(lb[i].Faction)
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
	faction := ""
	if u, err := a.store.GetUser(r.Context(), uid); err == nil && u != nil {
		username = u.Username
		faction = SanitizeTeamName(u.Faction)
	}

	if settings, err := a.store.GetUserSettings(r.Context(), uid); err == nil && settings != nil {
		a.wsHub.UpdateUserVisibility(uid, settings.LiveVisibility)
	}

	if zones, err := a.store.GetPrivacyZones(r.Context(), uid); err == nil && len(zones) > 0 {
		evals := make([]geo.PrivacyZoneEvaluator, len(zones))
		for i, z := range zones {
			evals[i] = geo.PrivacyZoneEvaluator{
				Latitude:     z.Latitude,
				Longitude:    z.Longitude,
				RadiusMeters: z.RadiusMeters,
				IsEnabled:    z.IsEnabled,
			}
		}
		a.wsHub.UpdateUserPrivacyZones(uid, evals)
	}

	a.wsHub.ServeWS(w, r, uid, username, faction)
}

// DeviceTokenRequest encapsulates device registration payload.
type DeviceTokenRequest struct {
	Token string `json:"token"`
}

// HandleRegisterDeviceToken handles POST /v1/device-token.
func (a *API) HandleRegisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req DeviceTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	trimmed := strings.TrimSpace(req.Token)
	if trimmed == "" {
		writeError(w, http.StatusBadRequest, "INVALID_TOKEN", "Device token cannot be empty")
		return
	}

	if err := a.store.SaveDeviceToken(r.Context(), uid, trimmed); err != nil {
		a.logger.Error("failed to register device token", "user_id", uid, "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to register device token")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "registered",
		"token":  trimmed,
	})
}

// HandleGetSettings handles GET /v1/me/settings.
func (a *API) HandleGetSettings(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	settings, err := a.store.GetUserSettings(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to get user settings", "user_id", uid, "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve user settings")
		return
	}

	writeJSON(w, http.StatusOK, settings)
}

// UpdateSettingsRequest defines payload for updating settings.
type UpdateSettingsRequest struct {
	LiveVisibility string `json:"live_visibility,omitempty"`
	Timezone       string `json:"timezone,omitempty"`
	LandReminders  *bool  `json:"land_reminders,omitempty"`
}

// HandleUpdateSettings handles PUT /v1/me/settings.
func (a *API) HandleUpdateSettings(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req UpdateSettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	existing, err := a.store.GetUserSettings(r.Context(), uid)
	if err != nil || existing == nil {
		existing = &store.UserSettings{
			LiveVisibility: "off",
			Timezone:       "UTC",
			LandReminders:  true,
		}
	}

	if req.LiveVisibility != "" {
		vis := strings.ToLower(strings.TrimSpace(req.LiveVisibility))
		if vis != "off" && vis != "friends" && vis != "nearby" {
			writeError(w, http.StatusBadRequest, "INVALID_SETTING", "live_visibility must be one of: off, friends, nearby")
			return
		}
		existing.LiveVisibility = vis
	}

	if req.Timezone != "" {
		tz := strings.TrimSpace(req.Timezone)
		if len(tz) > 64 {
			tz = tz[:64]
		}
		existing.Timezone = tz
	}

	if req.LandReminders != nil {
		existing.LandReminders = *req.LandReminders
	}

	if err := a.store.UpdateUserSettings(r.Context(), uid, existing); err != nil {
		a.logger.Error("failed to update user settings", "user_id", uid, "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update user settings")
		return
	}

	if a.wsHub != nil {
		a.wsHub.UpdateUserVisibility(uid, existing.LiveVisibility)
	}

	writeJSON(w, http.StatusOK, existing)
}

// HandleGetCurrentLeague handles GET /v1/league/current.
func (a *API) HandleGetCurrentLeague(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	activityType := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("activity_type")))
	if activityType == "" {
		activityType = "running"
	}

	now := time.Now().UTC()
	weekStart := league.CurrentWeekStart(now)

	standings, err := a.store.GetWeeklyStandings(r.Context(), weekStart, activityType)
	if err != nil {
		a.logger.Error("failed to query weekly standings", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve weekly standings")
		return
	}

	for i := range standings {
		standings[i].Faction = SanitizeTeamName(standings[i].Faction)
	}

	user, _ := a.store.GetUser(r.Context(), uid)
	if user != nil {
		user.Faction = SanitizeTeamName(user.Faction)
	}
	result := league.CalculateStandings(uid, standings, now, user)

	writeJSON(w, http.StatusOK, result)
}

// HandleGetFactionStandings handles GET /v1/factions/standings.
func (a *API) HandleGetFactionStandings(w http.ResponseWriter, r *http.Request) {
	standings, err := a.store.GetFactionStandings(r.Context())
	if err != nil {
		a.logger.Error("failed to get faction standings", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve faction standings")
		return
	}
	if standings != nil {
		validStandings := make([]store.FactionStanding, 0, len(standings.Standings))
		for _, s := range standings.Standings {
			clean := SanitizeTeamName(s.Faction)
			if clean != "" {
				s.Faction = clean
				validStandings = append(validStandings, s)
			}
		}
		standings.Standings = validStandings
	}
	writeJSON(w, http.StatusOK, standings)
}

// UpdateFactionRequest payload for PUT /v1/me/faction.
type UpdateFactionRequest struct {
	Faction string `json:"faction"`
}

// HandleUpdateUserFaction handles PUT /v1/me/faction.
func (a *API) HandleUpdateUserFaction(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	var req UpdateFactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}

	valResult, err := ValidateTeamName(req.Faction, a.teamDenyList)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_TEAM_NAME", err.Error())
		return
	}

	cleanedName := valResult.DisplayName

	// Check existing stored user faction to avoid penalizing no-op updates
	currentUser, _ := a.store.GetUser(r.Context(), uid)
	if currentUser != nil && SanitizeTeamName(currentUser.Faction) == cleanedName {
		writeJSON(w, http.StatusOK, map[string]string{
			"status":  "ok",
			"faction": cleanedName,
		})
		return
	}

	// Rate-limit team changes per user (3 changes per day by default)
	if a.teamLimiter != nil {
		key := "usr:" + uid
		allowed, retryAfter := a.teamLimiter.Allow(key)
		if !allowed {
			w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
			writeJSON(w, http.StatusTooManyRequests, map[string]interface{}{
				"error":       "RATE_LIMIT_EXCEEDED",
				"detail":      "Team change rate limit exceeded. You can only change teams 3 times per day.",
				"retry_after": retryAfter,
			})
			return
		}
	}

	if err := a.store.UpdateUserFaction(r.Context(), uid, cleanedName); err != nil {
		a.logger.Error("failed to update user faction", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update user faction")
		return
	}

	oldTeam := ""
	if currentUser != nil {
		oldTeam = SanitizeTeamName(currentUser.Faction)
	}
	// Log team change at INFO level without personal data (no UID, username, email, IP, or GPS)
	a.logger.Info("user team changed", "old_team", oldTeam, "new_team", cleanedName)

	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"faction": cleanedName,
	})
}

// SendFriendRequestBody carries target user identifier.
type SendFriendRequestBody struct {
	TargetUserID string `json:"target_user_id"`
}

// RespondFriendRequestBody carries action to accept or decline.
type RespondFriendRequestBody struct {
	Action string `json:"action"` // "accept" or "decline"
}

// CreateDuelRequest carries configuration for a head-to-head challenge.
type CreateDuelRequest struct {
	OpponentID   string  `json:"opponent_id"`
	ActivityType string  `json:"activity_type,omitempty"`
	TargetType   string  `json:"target_type"` // "area" or "distance"
	TargetValue  float64 `json:"target_value"`
	XpStake      int     `json:"xp_stake"`
}

// HandleGetFriends handles GET /v1/friends.
func (a *API) HandleGetFriends(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	friends, err := a.store.GetFriends(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to get friends", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve friends")
		return
	}
	if friends == nil {
		friends = []store.FriendUser{}
	}
	for i := range friends {
		friends[i].Faction = SanitizeTeamName(friends[i].Faction)
	}

	writeJSON(w, http.StatusOK, friends)
}

// HandleGetFriendRequests handles GET /v1/friends/requests.
func (a *API) HandleGetFriendRequests(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	reqs, err := a.store.GetFriendRequests(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to get friend requests", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve friend requests")
		return
	}
	if reqs == nil {
		reqs = []store.FriendRequestDetail{}
	}

	writeJSON(w, http.StatusOK, reqs)
}

// HandleSendFriendRequest handles POST /v1/friends/request.
func (a *API) HandleSendFriendRequest(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	var req SendFriendRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}

	req.TargetUserID = strings.TrimSpace(req.TargetUserID)
	if req.TargetUserID == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Target user ID cannot be empty")
		return
	}

	if req.TargetUserID == uid {
		writeError(w, http.StatusBadRequest, "CANNOT_FRIEND_SELF", "Cannot send friend request to yourself")
		return
	}

	friendship, err := a.store.SendFriendRequest(r.Context(), uid, req.TargetUserID)
	if err != nil {
		errStr := err.Error()
		if strings.Contains(errStr, "yourself") {
			writeError(w, http.StatusBadRequest, "CANNOT_FRIEND_SELF", errStr)
			return
		}
		if strings.Contains(errStr, "not found") {
			writeError(w, http.StatusNotFound, "RUNNER_NOT_FOUND", "No runner found with that Runner ID or name.")
			return
		}
		if strings.Contains(errStr, "limit") {
			writeError(w, http.StatusBadRequest, "FRIEND_REQUEST_LIMIT_EXCEEDED", errStr)
			return
		}
		if strings.Contains(errStr, "already") {
			writeError(w, http.StatusBadRequest, "FRIEND_REQUEST_ALREADY_EXISTS", errStr)
			return
		}
		writeError(w, http.StatusBadRequest, "FRIEND_REQUEST_ERROR", errStr)
		return
	}

	writeJSON(w, http.StatusCreated, friendship)
}

// HandleRespondFriendRequest handles PUT /v1/friends/request/{id}.
func (a *API) HandleRespondFriendRequest(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing request ID")
		return
	}

	var req RespondFriendRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}

	req.Action = strings.ToLower(strings.TrimSpace(req.Action))
	if req.Action != "accept" && req.Action != "decline" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Action must be 'accept' or 'decline'")
		return
	}

	f, err := a.store.RespondFriendRequest(r.Context(), id, uid, req.Action)
	if err != nil {
		writeError(w, http.StatusBadRequest, "RESPOND_ERROR", err.Error())
		return
	}

	if a.wsHub != nil && f != nil {
		a.wsHub.InvalidateFriends(f.RequesterID, f.AddresseeID)
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"action": req.Action,
	})
}

// HandleRemoveFriend handles DELETE /v1/friends/{friendID}.
func (a *API) HandleRemoveFriend(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	friendID := chi.URLParam(r, "friendID")
	if friendID == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing friend ID")
		return
	}

	if err := a.store.RemoveFriend(r.Context(), uid, friendID); err != nil {
		writeError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
		return
	}

	if a.wsHub != nil {
		a.wsHub.InvalidateFriends(uid, friendID)
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "removed",
	})
}

// HandleGetDuels handles GET /v1/duels.
func (a *API) HandleGetDuels(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	duels, err := a.store.GetDuelsByUser(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to get duels", "error", err, "uid", uid)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve duels")
		return
	}
	if duels == nil {
		duels = []store.Duel{}
	}

	writeJSON(w, http.StatusOK, duels)
}

// HandleCreateDuel handles POST /v1/duels.
func (a *API) HandleCreateDuel(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	var req CreateDuelRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Invalid request body")
		return
	}

	req.OpponentID = strings.TrimSpace(req.OpponentID)
	if req.OpponentID == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Opponent ID cannot be empty")
		return
	}

	if req.OpponentID == uid {
		writeError(w, http.StatusBadRequest, "CANNOT_DUEL_SELF", "Cannot challenge yourself to a duel")
		return
	}

	// Validate XP Stake bounds
	if req.XpStake < 0 || req.XpStake > 1000 {
		writeError(w, http.StatusBadRequest, "INVALID_XP_STAKE", "XP stake must be between 0 and 1000")
		return
	}

	// Validate Target Type and Value bounds
	if req.TargetType != "distance" {
		req.TargetType = "area"
	}

	if req.TargetType == "area" {
		if req.TargetValue <= 0 {
			req.TargetValue = 10000.0 // Default 10,000 sqm
		} else if req.TargetValue < 500.0 || req.TargetValue > 500000.0 {
			writeError(w, http.StatusBadRequest, "INVALID_TARGET_VALUE", "Area duel target must be between 500 and 500,000 sqm")
			return
		}
	} else if req.TargetType == "distance" {
		if req.TargetValue <= 0 {
			req.TargetValue = 5.0 // Default 5 km
		} else if req.TargetValue >= 100.0 {
			if req.TargetValue < 500.0 || req.TargetValue > 50000.0 {
				writeError(w, http.StatusBadRequest, "INVALID_TARGET_VALUE", "Distance duel target must be between 500m (0.5km) and 50,000m (50km)")
				return
			}
			req.TargetValue = req.TargetValue / 1000.0
		} else if req.TargetValue < 0.5 || req.TargetValue > 50.0 {
			writeError(w, http.StatusBadRequest, "INVALID_TARGET_VALUE", "Distance duel target must be between 0.5 and 50.0 km")
			return
		}
	}

	activityType := strings.ToLower(strings.TrimSpace(req.ActivityType))
	if activityType == "" {
		activityType = "running"
	}
	if activityType != "running" && activityType != "walking" && activityType != "cycling" {
		writeError(w, http.StatusBadRequest, "INVALID_ACTIVITY_TYPE", "Activity type must be 'running', 'walking', or 'cycling'")
		return
	}

	duel := &store.Duel{
		ChallengerID: uid,
		OpponentID:   req.OpponentID,
		ActivityType: activityType,
		TargetType:   req.TargetType,
		TargetValue:  req.TargetValue,
		XpStake:      req.XpStake,
	}

	if err := a.store.CreateDuel(r.Context(), duel); err != nil {
		errStr := err.Error()
		if strings.Contains(errStr, "yourself") {
			writeError(w, http.StatusBadRequest, "CANNOT_DUEL_SELF", errStr)
			return
		}
		if strings.Contains(errStr, "already exists") {
			writeError(w, http.StatusBadRequest, "DUEL_ALREADY_EXISTS", errStr)
			return
		}
		if strings.Contains(errStr, "limit") || strings.Contains(errStr, "reached") {
			writeError(w, http.StatusBadRequest, "DUEL_LIMIT_EXCEEDED", errStr)
			return
		}
		if strings.Contains(errStr, "target") {
			writeError(w, http.StatusBadRequest, "INVALID_TARGET_VALUE", errStr)
			return
		}
		if strings.Contains(errStr, "xp stake") {
			writeError(w, http.StatusBadRequest, "INVALID_XP_STAKE", errStr)
			return
		}
		if strings.Contains(errStr, "not found") {
			writeError(w, http.StatusBadRequest, "OPPONENT_NOT_FOUND", errStr)
			return
		}
		writeError(w, http.StatusBadRequest, "CREATE_DUEL_ERROR", errStr)
		return
	}

	writeJSON(w, http.StatusCreated, duel)
}

// HandleAcceptDuel handles PUT /v1/duels/{id}/accept.
func (a *API) HandleAcceptDuel(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing duel ID")
		return
	}

	if err := a.store.AcceptDuel(r.Context(), id, uid); err != nil {
		writeError(w, http.StatusBadRequest, "ACCEPT_DUEL_ERROR", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"action": "accepted",
	})
}

// HandleDeclineDuel handles PUT /v1/duels/{id}/decline.
func (a *API) HandleDeclineDuel(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
		return
	}

	id := chi.URLParam(r, "id")
	if id == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Missing duel ID")
		return
	}

	if err := a.store.DeclineDuel(r.Context(), id, uid); err != nil {
		writeError(w, http.StatusBadRequest, "DECLINE_DUEL_ERROR", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"action": "declined",
	})
}

// HandleGetCurrentSeason handles GET /v1/seasons/current.
func (a *API) HandleGetCurrentSeason(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	now := time.Now().UTC()
	season, err := a.store.GetCurrentSeason(r.Context(), now)
	if err != nil {
		a.logger.Error("failed to get current season", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to get current season")
		return
	}

	timeRemaining := int64(season.EndsAt.Sub(now).Seconds())
	if timeRemaining < 0 {
		timeRemaining = 0
	}

	userStanding, err := a.store.GetSeasonStandingByUser(r.Context(), season.ID, uid)
	if err != nil {
		a.logger.Warn("failed to get season user standing", "user_id", uid, "error", err)
	}

	factionStandings, err := a.store.GetSeasonFactionStandings(r.Context(), season.ID)
	if err != nil {
		a.logger.Error("failed to get season faction standings", "error", err)
		factionStandings = []store.SeasonFactionStanding{}
	}
	if factionStandings == nil {
		factionStandings = []store.SeasonFactionStanding{}
	}

	resp := store.CurrentSeasonResponse{
		Season:               *season,
		TimeRemainingSeconds: timeRemaining,
		UserStanding:         userStanding,
		FactionStandings:     factionStandings,
	}

	writeJSON(w, http.StatusOK, resp)
}

// HandleGetMyCrew handles GET /v1/crews/my.
func (a *API) HandleGetMyCrew(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	crew, role, err := a.store.GetCrewByUserID(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to check crew membership", "user_id", uid, "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to check crew membership")
		return
	}

	if crew == nil {
		writeJSON(w, http.StatusOK, store.MyCrewResponse{Crew: nil})
		return
	}

	now := time.Now().UTC()
	weekStart := league.CurrentWeekStart(now)

	members, err := a.store.GetCrewMembers(r.Context(), crew.ID, weekStart)
	if err != nil {
		a.logger.Error("failed to get crew members", "crew_id", crew.ID, "error", err)
		members = []store.CrewMember{}
	}
	if members == nil {
		members = []store.CrewMember{}
	}

	activeGoal, err := a.store.GetActiveCrewGoal(r.Context(), crew.ID, weekStart)
	if err != nil {
		a.logger.Warn("failed to get active crew goal", "crew_id", crew.ID, "error", err)
	}

	resp := store.MyCrewResponse{
		Crew:       crew,
		Role:       role,
		Members:    members,
		ActiveGoal: activeGoal,
	}

	writeJSON(w, http.StatusOK, resp)
}

// CreateCrewRequest encapsulates parameters to create a new runner crew.
type CreateCrewRequest struct {
	Name string `json:"name"`
}

func generateCrewJoinCode() string {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, 4)
	if _, err := cryptorand.Read(b); err != nil {
		return fmt.Sprintf("CRW-%04X", time.Now().UnixNano()%0xFFFF)
	}
	var res strings.Builder
	res.WriteString("CRW-")
	for _, v := range b {
		res.WriteByte(charset[int(v)%len(charset)])
	}
	return res.String()
}

// HandleCreateCrew handles POST /v1/crews.
func (a *API) HandleCreateCrew(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req CreateCrewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	valRes, err := ValidateTeamName(req.Name)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_CREW_NAME", err.Error())
		return
	}

	var crew *store.Crew
	for attempts := 0; attempts < 3; attempts++ {
		joinCode := generateCrewJoinCode()
		crew, err = a.store.CreateCrew(r.Context(), uid, valRes.DisplayName, joinCode)
		if err == nil {
			break
		}
		if !strings.Contains(err.Error(), "join_code") {
			break
		}
	}

	if err != nil {
		errStr := err.Error()
		if strings.Contains(errStr, "already a member of a crew") || strings.Contains(errStr, "already in a crew") {
			writeError(w, http.StatusBadRequest, "USER_ALREADY_IN_CREW", errStr)
			return
		}
		if strings.Contains(errStr, "already taken") || strings.Contains(errStr, "unique") {
			writeError(w, http.StatusBadRequest, "CREW_NAME_TAKEN", "A crew with this name already exists")
			return
		}
		a.logger.Error("failed to create crew", "error", err)
		writeError(w, http.StatusBadRequest, "CREATE_CREW_ERROR", errStr)
		return
	}

	writeJSON(w, http.StatusCreated, crew)
}

// JoinCrewRequest encapsulates the join code required to enter a crew.
type JoinCrewRequest struct {
	JoinCode string `json:"join_code"`
}

// HandleJoinCrew handles POST /v1/crews/join.
func (a *API) HandleJoinCrew(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req JoinCrewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	joinCode := strings.ToUpper(strings.TrimSpace(req.JoinCode))
	if joinCode == "" {
		writeError(w, http.StatusBadRequest, "INVALID_JOIN_CODE", "Join code cannot be empty")
		return
	}

	crew, err := a.store.JoinCrew(r.Context(), uid, joinCode)
	if err != nil {
		errStr := err.Error()
		errLower := strings.ToLower(errStr)
		if strings.Contains(errLower, "not found") || strings.Contains(errLower, "invalid join code") {
			writeError(w, http.StatusNotFound, "CREW_NOT_FOUND", "No crew found with that join code")
			return
		}
		if strings.Contains(errLower, "already in a crew") || strings.Contains(errLower, "already a member") {
			writeError(w, http.StatusBadRequest, "USER_ALREADY_IN_CREW", errStr)
			return
		}
		if strings.Contains(errLower, "maximum capacity") || strings.Contains(errLower, "full") {
			writeError(w, http.StatusBadRequest, "CREW_FULL", "Crew has reached maximum capacity of 10 members")
			return
		}
		a.logger.Error("failed to join crew", "error", err)
		writeError(w, http.StatusBadRequest, "JOIN_CREW_ERROR", errStr)
		return
	}

	writeJSON(w, http.StatusOK, crew)
}

// SetCrewGoalRequest encapsulates a leader's weekly target definition.
type SetCrewGoalRequest struct {
	GoalType    string  `json:"goal_type"`
	TargetValue float64 `json:"target_value"`
}

// HandleSetCrewGoal handles POST /v1/crews/goals.
func (a *API) HandleSetCrewGoal(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	var req SetCrewGoalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_JSON", "Malformed request body")
		return
	}

	goalType := strings.ToLower(strings.TrimSpace(req.GoalType))
	if goalType != "distance" && goalType != "area" {
		writeError(w, http.StatusBadRequest, "INVALID_GOAL_TYPE", "Goal type must be 'distance' or 'area'")
		return
	}

	if req.TargetValue <= 0 {
		writeError(w, http.StatusBadRequest, "INVALID_TARGET_VALUE", "Target value must be greater than zero")
		return
	}

	crew, role, err := a.store.GetCrewByUserID(r.Context(), uid)
	if err != nil {
		a.logger.Error("failed to find crew for user", "user_id", uid, "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve crew")
		return
	}
	if crew == nil {
		writeError(w, http.StatusBadRequest, "NOT_IN_CREW", "User is not a member of any crew")
		return
	}

	if role != "leader" {
		writeError(w, http.StatusForbidden, "FORBIDDEN", "Only crew leaders can set weekly goals")
		return
	}

	now := time.Now().UTC()
	weekStart := league.CurrentWeekStart(now)

	goal, err := a.store.SetCrewGoal(r.Context(), crew.ID, goalType, req.TargetValue, weekStart, uid)
	if err != nil {
		a.logger.Error("failed to set crew goal", "error", err)
		writeError(w, http.StatusBadRequest, "SET_GOAL_ERROR", err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, goal)
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, code, detail string) {
	resp := map[string]string{
		"error":  code,
		"detail": detail,
	}
	if reqID := w.Header().Get("X-Request-Id"); reqID != "" {
		resp["request_id"] = reqID
	}
	writeJSON(w, status, resp)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
