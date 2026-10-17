package api

import (
	"context"
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
	IdempotencyKey  string           `json:"idempotency_key"`
	ActivityType    string           `json:"activity_type,omitempty"`
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

	// 2. Anti-cheat / GPS Anomaly Detection & Spoofing Mitigation (activity-aware)
	anomalyRes := a.detector.EvaluateTrackWithActivity(req.Points, activityType)
	if anomalyRes.IsAnomaly && anomalyRes.Score >= 50.0 {
		a.logger.Warn("run rejected due to critical anomaly", "score", anomalyRes.Score, "reasons", anomalyRes.Reasons, "activity_type", activityType)
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
		ActivityType:    activityType,
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

// HandleGetCurrentLeague handles GET /v1/league/current.
func (a *API) HandleGetCurrentLeague(w http.ResponseWriter, r *http.Request) {
	uid := auth.GetUserID(r.Context())
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user context")
		return
	}

	now := time.Now().UTC()
	weekStart := league.CurrentWeekStart(now)

	standings, err := a.store.GetWeeklyStandings(r.Context(), weekStart)
	if err != nil {
		a.logger.Error("failed to query weekly standings", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to retrieve weekly standings")
		return
	}

	user, _ := a.store.GetUser(r.Context(), uid)
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

	req.Faction = strings.TrimSpace(req.Faction)
	if req.Faction == "" {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "Faction name cannot be empty")
		return
	}

	if err := a.store.UpdateUserFaction(r.Context(), uid, req.Faction); err != nil {
		a.logger.Error("failed to update user faction", "error", err, "uid", uid, "faction", req.Faction)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to update user faction")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"faction": req.Faction,
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
	OpponentID  string  `json:"opponent_id"`
	TargetType  string  `json:"target_type"` // "area" or "distance"
	TargetValue float64 `json:"target_value"`
	XpStake     int     `json:"xp_stake"`
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

	if err := a.store.RespondFriendRequest(r.Context(), id, uid, req.Action); err != nil {
		writeError(w, http.StatusBadRequest, "RESPOND_ERROR", err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status": "ok",
		"action": req.Action,
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

	duel := &store.Duel{
		ChallengerID: uid,
		OpponentID:   req.OpponentID,
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
