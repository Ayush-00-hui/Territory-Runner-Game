package store

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PostgresStore implements the Store interface using PostgreSQL and PostGIS.
type PostgresStore struct {
	pool *pgxpool.Pool
}

// NewPostgresStore initializes a connection pool to PostGIS.
func NewPostgresStore(ctx context.Context, connString string) (*PostgresStore, error) {
	cfg, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse postgres conn string: %w", err)
	}

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create postgres connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping postgis: %w", err)
	}

	return &PostgresStore{pool: pool}, nil
}

// Ping checks database liveness.
func (s *PostgresStore) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}

// Close shuts down the connection pool.
func (s *PostgresStore) Close() {
	s.pool.Close()
}

// GetUser retrieves a user by ID.
func (s *PostgresStore) GetUser(ctx context.Context, id string) (*User, error) {
	query := `
		SELECT id, username, faction, total_area_sqm, xp, level, total_runs, created_at, updated_at
		FROM users
		WHERE id = $1;
	`
	var u User
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&u.ID, &u.Username, &u.Faction, &u.TotalAreaSqm, &u.XP, &u.Level, &u.TotalRuns, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error querying user: %w", err)
	}
	return &u, nil
}

// UpsertUser inserts or updates a user profile.
func (s *PostgresStore) UpsertUser(ctx context.Context, u *User) error {
	query := `
		INSERT INTO users (id, username, faction, total_area_sqm, xp, level, total_runs, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		ON CONFLICT (id) DO UPDATE SET
			username = EXCLUDED.username,
			faction = EXCLUDED.faction,
			updated_at = NOW();
	`
	_, err := s.pool.Exec(ctx, query, u.ID, u.Username, u.Faction, u.TotalAreaSqm, u.XP, u.Level, u.TotalRuns)
	return err
}

// DeleteUser permanently purges a user record and cascades to all associated territories, runs, duels, and privacy zones.
func (s *PostgresStore) DeleteUser(ctx context.Context, userID string) error {
	query := `DELETE FROM users WHERE id = $1;`
	_, err := s.pool.Exec(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("error deleting user %s: %w", userID, err)
	}
	return nil
}

// GetRunsByUser retrieves recent runs for a user.
func (s *PostgresStore) GetRunsByUser(ctx context.Context, userID string, limit int) ([]Run, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT id, user_id, idempotency_key, COALESCE(activity_type, 'running'), step_count, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
		FROM runs
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2;
	`
	rows, err := s.pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var runs []Run
	for rows.Next() {
		var r Run
		if err := rows.Scan(
			&r.ID, &r.UserID, &r.IdempotencyKey, &r.ActivityType, &r.StepCount, &r.DurationSeconds, &r.DistanceMeters,
			&r.AreaClaimed, &r.AnomalyScore, &r.AnomalyReasons, &r.Status, &r.CreatedAt,
		); err != nil {
			return nil, err
		}
		runs = append(runs, r)
	}
	return runs, nil
}

// GetRunByIdempotencyKey fetches an existing run by idempotency key.
func (s *PostgresStore) GetRunByIdempotencyKey(ctx context.Context, key string) (*Run, error) {
	query := `
		SELECT id, user_id, idempotency_key, COALESCE(activity_type, 'running'), step_count, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
		FROM runs
		WHERE idempotency_key = $1;
	`
	var r Run
	err := s.pool.QueryRow(ctx, query, key).Scan(
		&r.ID, &r.UserID, &r.IdempotencyKey, &r.ActivityType, &r.StepCount, &r.DurationSeconds, &r.DistanceMeters,
		&r.AreaClaimed, &r.AnomalyScore, &r.AnomalyReasons, &r.Status, &r.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &r, nil
}

// GetTerritoriesInBBox returns GeoJSON representations of territories intersecting the bounding box.
func (s *PostgresStore) GetTerritoriesInBBox(ctx context.Context, minLng, minLat, maxLng, maxLat float64) ([]Territory, error) {
	query := `
		SELECT t.id, t.owner_id, u.username, ST_AsGeoJSON(t.geom), t.area_sqm, COALESCE(t.strength, 100.0), COALESCE(t.last_defended_at, t.updated_at), COALESCE(t.last_decayed_at, t.last_defended_at, t.updated_at), t.updated_at
		FROM territories t
		JOIN users u ON t.owner_id = u.id
		WHERE ST_Intersects(t.geom, ST_MakeEnvelope($1, $2, $3, $4, 4326));
	`
	rows, err := s.pool.Query(ctx, query, minLng, minLat, maxLng, maxLat)
	if err != nil {
		return nil, fmt.Errorf("bbox query failed: %w", err)
	}
	defer rows.Close()

	now := time.Now().UTC()
	var list []Territory
	for rows.Next() {
		var t Territory
		if err := rows.Scan(&t.ID, &t.OwnerID, &t.Username, &t.GeoJSON, &t.AreaSqm, &t.Strength, &t.LastDefendedAt, &t.LastDecayedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		t.Strength = t.EffectiveStrength(now)
		list = append(list, t)
	}
	return list, nil
}

// GetAllTerritories returns all persisted territories in PostgreSQL.
func (s *PostgresStore) GetAllTerritories(ctx context.Context) ([]Territory, error) {
	query := `
		SELECT t.id, t.owner_id, u.username, ST_AsGeoJSON(t.geom), t.area_sqm, COALESCE(t.strength, 100.0), COALESCE(t.last_defended_at, t.updated_at), COALESCE(t.last_decayed_at, t.last_defended_at, t.updated_at), t.updated_at
		FROM territories t
		JOIN users u ON t.owner_id = u.id;
	`
	rows, err := s.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("get all territories query failed: %w", err)
	}
	defer rows.Close()

	var list []Territory
	for rows.Next() {
		var t Territory
		if err := rows.Scan(&t.ID, &t.OwnerID, &t.Username, &t.GeoJSON, &t.AreaSqm, &t.Strength, &t.LastDefendedAt, &t.LastDecayedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, t)
	}
	return list, nil
}

// CaptureRunAndMutateTerritories executes the entire spatial capture lifecycle in ONE atomic transaction.
func (s *PostgresStore) CaptureRunAndMutateTerritories(
	ctx context.Context,
	run *Run,
	loops []geo.EnclosedLoop,
	rawTrack []geo.TrackPoint,
) (*CaptureResult, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx) // Safe no-op if committed

	// 1. Transaction-scoped advisory lock:
	// Serializes geographic mutations to prevent concurrent spatial race conditions and deadlocks.
	// Automatically releases upon COMMIT or ROLLBACK.
	if _, err := tx.Exec(ctx, "SELECT pg_advisory_xact_lock(hashtext('territory_mutation_lock'));"); err != nil {
		return nil, fmt.Errorf("failed to acquire spatial advisory lock: %w", err)
	}

	// 2. Idempotency Check:
	var existing Run
	err = tx.QueryRow(ctx, `
		SELECT id, user_id, idempotency_key, COALESCE(activity_type, 'running'), duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
		FROM runs WHERE idempotency_key = $1;
	`, run.IdempotencyKey).Scan(
		&existing.ID, &existing.UserID, &existing.IdempotencyKey, &existing.ActivityType, &existing.DurationSeconds,
		&existing.DistanceMeters, &existing.AreaClaimed, &existing.AnomalyScore,
		&existing.AnomalyReasons, &existing.Status, &existing.CreatedAt,
	)
	if err == nil {
		// Run was already processed; return cached result idempotently
		var userTotalArea float64
		_ = tx.QueryRow(ctx, "SELECT total_area_sqm FROM users WHERE id = $1;", existing.UserID).Scan(&userTotalArea)

		var geojson string
		territoryID := fmt.Sprintf("poly_%s_territory", existing.UserID)
		_ = tx.QueryRow(ctx, "SELECT ST_AsGeoJSON(geom) FROM territories WHERE id = $1;", territoryID).Scan(&geojson)

		xpAwarded := 0
		if existing.AreaClaimed >= MinCaptureFloorSqm {
			xpAwarded = int(math.Max(5, math.Round(existing.AreaClaimed/20.0)))
		}
		return &CaptureResult{
			RunID:              existing.ID,
			IdempotencyKey:     existing.IdempotencyKey,
			ActivityType:       existing.ActivityType,
			Status:             existing.Status,
			AnomalyScore:       existing.AnomalyScore,
			AnomalyReasons:     existing.AnomalyReasons,
			LoopDetected:       existing.AreaClaimed > 0,
			AreaClaimedSqm:     existing.AreaClaimed,
			XpAwarded:          xpAwarded,
			PlayerTotalAreaSqm: userTotalArea,
			TerritoryGeoJSON:   geojson,
		}, nil
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("error verifying idempotency: %w", err)
	}

	var territoryGeoJSON string
	var playerTotalArea float64
	var areaClaimed float64
	var xpAwarded int
	var rivalsAffected []string
	var weakBonusArea float64

	if len(loops) == 0 {
		_ = tx.QueryRow(ctx, "SELECT total_area_sqm FROM users WHERE id = $1;", run.UserID).Scan(&playerTotalArea)
	}

	// 3. Process spatial loop capture for all closed loops
	for _, loop := range loops {
		if len(loop.Polygon) < 3 {
			continue
		}
		polyWKT := polygonToWKT(loop.Polygon)
		territoryID := fmt.Sprintf("poly_%s_territory", run.UserID)

		// A. Union into player's territory:
		// ST_Union operates on geometry, cast to ::geography for geodesic area
		unionQuery := `
			INSERT INTO territories (id, owner_id, geom, area_sqm, strength, last_defended_at, last_decayed_at, updated_at)
			VALUES ($1, $2, ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_PolygonFromText($3, 4326)), 3)), ST_Area(ST_MakeValid(ST_PolygonFromText($3, 4326))::geography), 100.0, NOW(), NOW(), NOW())
			ON CONFLICT (id) DO UPDATE SET
				geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Union(territories.geom, ST_MakeValid(ST_PolygonFromText($3, 4326)))), 3)),
				area_sqm = ST_Area(ST_MakeValid(ST_Union(territories.geom, ST_MakeValid(ST_PolygonFromText($3, 4326))))::geography),
				strength = 100.0,
				last_defended_at = NOW(),
				last_decayed_at = NOW(),
				updated_at = NOW()
			RETURNING ST_AsGeoJSON(geom), area_sqm;
		`
		if err := tx.QueryRow(ctx, unionQuery, territoryID, run.UserID, polyWKT).Scan(&territoryGeoJSON, &playerTotalArea); err != nil {
			return nil, fmt.Errorf("failed to union owner territory: %w", err)
		}

		// Check for weak rivals before clipping to award 1.5x XP bonus
		checkRivalsQuery := `
			SELECT owner_id, COALESCE(strength, 100.0), COALESCE(last_defended_at, updated_at)
			FROM territories
			WHERE owner_id != $1
			  AND ST_Intersects(geom, ST_MakeValid(ST_PolygonFromText($2, 4326)));
		`
		if rRows, err := tx.Query(ctx, checkRivalsQuery, run.UserID, polyWKT); err == nil {
			now := time.Now().UTC()
			for rRows.Next() {
				var rOwner string
				var rStrength float64
				var rLastDefended time.Time
				if rRows.Scan(&rOwner, &rStrength, &rLastDefended) == nil {
					rivalsAffected = append(rivalsAffected, rOwner)
					effStr := CalculateEffectiveStrength(rStrength, rLastDefended, now)
					if effStr < TerritoryWeakThreshold {
						weakBonusArea += loop.AreaSqMeters * 0.5
					}
				}
			}
			rRows.Close()
		}

		// B. ST_Difference against rival territories:
		diffQuery := `
			UPDATE territories
			SET
				geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Difference(geom, ST_MakeValid(ST_PolygonFromText($1, 4326)))), 3)),
				area_sqm = ST_Area(ST_MakeValid(ST_Difference(geom, ST_MakeValid(ST_PolygonFromText($1, 4326))))::geography),
				updated_at = NOW()
			WHERE owner_id != $2
			  AND ST_Intersects(geom, ST_MakeValid(ST_PolygonFromText($1, 4326)))
			RETURNING owner_id;
		`
		rows, err := tx.Query(ctx, diffQuery, polyWKT, run.UserID)
		if err != nil {
			return nil, fmt.Errorf("failed to clip rival territories: %w", err)
		}
		for rows.Next() {
			var rOwner string
			if scanErr := rows.Scan(&rOwner); scanErr == nil && rOwner != "" {
				rivalsAffected = append(rivalsAffected, rOwner)
			}
		}
		rows.Close()

		areaClaimed += loop.AreaSqMeters
	}

	if len(loops) > 0 {
		// Clean up overtaken rival territories
		cleanupQuery := `
			DELETE FROM territories
			WHERE owner_id != $1
			  AND (ST_IsEmpty(geom) OR area_sqm <= 0.001);
		`
		if _, err := tx.Exec(ctx, cleanupQuery, run.UserID); err != nil {
			return nil, fmt.Errorf("failed to clean empty rival territories: %w", err)
		}

		// Enforce 25 m² minimum new area floor before awarding XP, league, or duel credit
		if areaClaimed >= MinCaptureFloorSqm {
			effectiveXpArea := areaClaimed
			if run.VerificationStatus != "unverified_motion" {
				// Only verified motion runs receive high-value weak-territory 1.5x bonus
				effectiveXpArea += weakBonusArea
			}
			xpAwarded = int(math.Max(5, math.Round(effectiveXpArea/20.0)))
		} else {
			areaClaimed = 0.0
			xpAwarded = 0
		}
	}

	// 4. Update user total area and XP
	updateUserQuery := `
		UPDATE users
		SET
			total_area_sqm = $1,
			xp = xp + $2,
			total_runs = total_runs + 1,
			updated_at = NOW()
		WHERE id = $3;
	`
	if _, err := tx.Exec(ctx, updateUserQuery, playerTotalArea, xpAwarded, run.UserID); err != nil {
		return nil, fmt.Errorf("failed to update user stats: %w", err)
	}

	// 5. Insert run record
	var pathWKT *string
	if len(rawTrack) >= 2 {
		wkt := lineStringToWKT(rawTrack)
		pathWKT = &wkt
	}

	activityType := run.ActivityType
	if activityType == "" {
		activityType = "running"
	}

	insertRunQuery := `
		INSERT INTO runs (id, user_id, idempotency_key, activity_type, step_count, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, path, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, CASE WHEN $11::text IS NOT NULL THEN ST_GeomFromText($11, 4326) ELSE NULL END, $12, $13);
	`
	anomalyReasons := run.AnomalyReasons
	if anomalyReasons == nil {
		anomalyReasons = []string{}
	}
	status := run.Status
	if status == "" {
		status = "accepted"
	}
	createdAt := time.Now().UTC()
	if !run.CreatedAt.IsZero() {
		createdAt = run.CreatedAt
	}

	if _, err := tx.Exec(ctx, insertRunQuery,
		run.ID, run.UserID, run.IdempotencyKey, activityType, run.StepCount, run.DurationSeconds, run.DistanceMeters,
		areaClaimed, run.AnomalyScore, anomalyReasons, pathWKT, status, createdAt,
	); err != nil {
		return nil, fmt.Errorf("failed to insert run: %w", err)
	}

	// Update season progress for current month within transaction
	seasonID := fmt.Sprintf("season_%d_%02d", createdAt.Year(), createdAt.Month())
	seasonName := fmt.Sprintf("%s %d", createdAt.Month().String(), createdAt.Year())
	seasonStart := time.Date(createdAt.Year(), createdAt.Month(), 1, 0, 0, 0, 0, time.UTC)
	seasonEnd := time.Date(createdAt.Year(), createdAt.Month()+1, 1, 0, 0, 0, 0, time.UTC)

	// Update season progress for current month within transaction (guarded by savepoint)
	if _, err := tx.Exec(ctx, "SAVEPOINT season_update;"); err == nil {
		_, errSeason := tx.Exec(ctx, `
			INSERT INTO seasons (id, name, starts_at, ends_at, created_at)
			VALUES ($1, $2, $3, $4, NOW())
			ON CONFLICT (id) DO NOTHING;
		`, seasonID, seasonName, seasonStart, seasonEnd)

		if errSeason == nil {
			_, errSeason = tx.Exec(ctx, `
				INSERT INTO season_standings (season_id, user_id, faction, total_area_sqm, total_distance_m, xp, updated_at)
				SELECT $1, $2, COALESCE(u.faction, ''), $3, $4, $5, NOW()
				FROM users u WHERE u.id = $2
				ON CONFLICT (season_id, user_id) DO UPDATE SET
					total_area_sqm = season_standings.total_area_sqm + EXCLUDED.total_area_sqm,
					total_distance_m = season_standings.total_distance_m + EXCLUDED.total_distance_m,
					xp = season_standings.xp + EXCLUDED.xp,
					faction = CASE WHEN EXCLUDED.faction != '' THEN EXCLUDED.faction ELSE season_standings.faction END,
					updated_at = NOW();
			`, seasonID, run.UserID, areaClaimed, run.DistanceMeters, xpAwarded)
		}

		if errSeason != nil {
			_, _ = tx.Exec(ctx, "ROLLBACK TO SAVEPOINT season_update;")
		} else {
			_, _ = tx.Exec(ctx, "RELEASE SAVEPOINT season_update;")
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit capture transaction: %w", err)
	}

	if run.Status != "flagged_review" && run.Status != "unverified_motion" && run.VerificationStatus != "unverified_motion" {
		_ = s.UpdateDuelProgress(ctx, run.UserID, activityType, areaClaimed, run.DistanceMeters)
	}

	return &CaptureResult{
		RunID:              run.ID,
		IdempotencyKey:     run.IdempotencyKey,
		ActivityType:       activityType,
		StepCount:          run.StepCount,
		Status:             run.Status,
		VerificationStatus: run.VerificationStatus,
		AnomalyScore:       run.AnomalyScore,
		AnomalyReasons:     run.AnomalyReasons,
		LoopDetected:       len(loops) > 0,
		AreaClaimedSqm:     areaClaimed,
		XpAwarded:          xpAwarded,
		PlayerTotalAreaSqm: playerTotalArea,
		TerritoryGeoJSON:   territoryGeoJSON,
		RivalsAffected:     rivalsAffected,
	}, nil
}

// GetLeaderboard fetches the top users ranked by claimed surface area, optionally filtered by activity type.
func (s *PostgresStore) GetLeaderboard(ctx context.Context, limit int, activityType string) ([]LeaderboardEntry, error) {
	if limit <= 0 {
		limit = 50
	}
	activityType = strings.ToLower(strings.TrimSpace(activityType))
	var query string
	var args []interface{}

	if activityType != "" && activityType != "all" {
		query = `
			SELECT u.id, u.username, u.faction, COALESCE(SUM(r.area_claimed), 0.0) AS total_area_sqm, u.level, COUNT(r.id) AS total_runs
			FROM users u
			JOIN runs r ON u.id = r.user_id AND r.status = 'accepted' AND r.activity_type = $1
			GROUP BY u.id, u.username, u.faction, u.level
			ORDER BY total_area_sqm DESC
			LIMIT $2;
		`
		args = []interface{}{activityType, limit}
	} else {
		query = `
			SELECT id, username, faction, total_area_sqm, level, total_runs
			FROM users
			ORDER BY total_area_sqm DESC
			LIMIT $1;
		`
		args = []interface{}{limit}
	}

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []LeaderboardEntry
	rank := 1
	for rows.Next() {
		var e LeaderboardEntry
		e.Rank = rank
		if err := rows.Scan(&e.UserID, &e.Username, &e.Faction, &e.TotalAreaSqm, &e.Level, &e.TotalRuns); err != nil {
			return nil, err
		}
		entries = append(entries, e)
		rank++
	}
	return entries, nil
}

// ApplyTerritoryDecay updates all territories by decaying strength based on elapsed days since last_decayed_at.
// It updates ONLY last_decayed_at and updated_at, never modifying last_defended_at.
func (s *PostgresStore) ApplyTerritoryDecay(ctx context.Context, decayPerDay float64) error {
	if decayPerDay <= 0 {
		decayPerDay = 15.0
	}
	query := `
		UPDATE territories
		SET
			strength = GREATEST(0.0, LEAST(100.0, strength - (EXTRACT(EPOCH FROM (NOW() - COALESCE(last_decayed_at, last_defended_at, updated_at))) / 86400.0 * $1))),
			last_decayed_at = NOW(),
			updated_at = NOW();
	`
	_, err := s.pool.Exec(ctx, query, decayPerDay)
	if err != nil {
		return fmt.Errorf("failed to apply territory decay: %w", err)
	}
	return nil
}

// UpdateTerritoryDefense updates a territory's strength and marks it defended as of now.
func (s *PostgresStore) UpdateTerritoryDefense(ctx context.Context, territoryID string, newStrength float64) error {
	if newStrength < 0 {
		newStrength = 0
	} else if newStrength > 100 {
		newStrength = 100
	}
	query := `
		UPDATE territories
		SET
			strength = $1,
			last_defended_at = NOW(),
			last_decayed_at = NOW(),
			updated_at = NOW()
		WHERE id = $2;
	`
	tag, err := s.pool.Exec(ctx, query, newStrength, territoryID)
	if err != nil {
		return fmt.Errorf("failed to update territory defense: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("territory %s not found", territoryID)
	}
	return nil
}

// GetTerritoryByID retrieves a territory by its unique ID.
func (s *PostgresStore) GetTerritoryByID(ctx context.Context, id string) (*Territory, error) {
	query := `
		SELECT t.id, t.owner_id, u.username, ST_AsGeoJSON(t.geom), t.area_sqm, COALESCE(t.strength, 100.0), COALESCE(t.last_defended_at, t.updated_at), COALESCE(t.last_decayed_at, t.last_defended_at, t.updated_at), t.updated_at
		FROM territories t
		JOIN users u ON t.owner_id = u.id
		WHERE t.id = $1;
	`
	var t Territory
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&t.ID, &t.OwnerID, &t.Username, &t.GeoJSON, &t.AreaSqm, &t.Strength, &t.LastDefendedAt, &t.LastDecayedAt, &t.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error querying territory by id: %w", err)
	}
	t.Strength = t.EffectiveStrength(time.Now().UTC())
	return &t, nil
}

// SaveDeviceToken persists or updates an FCM registration token for a user.
func (s *PostgresStore) SaveDeviceToken(ctx context.Context, userID, token string) error {
	query := `
		INSERT INTO device_tokens (user_id, token, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id, token) DO UPDATE SET updated_at = NOW();
	`
	_, err := s.pool.Exec(ctx, query, userID, token)
	return err
}

// GetDeviceTokens returns all active FCM device tokens registered for a user.
func (s *PostgresStore) GetDeviceTokens(ctx context.Context, userID string) ([]string, error) {
	query := `
		SELECT token
		FROM device_tokens
		WHERE user_id = $1
		ORDER BY updated_at DESC;
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var tok string
		if err := rows.Scan(&tok); err == nil && tok != "" {
			tokens = append(tokens, tok)
		}
	}
	return tokens, nil
}

// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart, optionally filtered by activity.
func (s *PostgresStore) GetWeeklyStandings(ctx context.Context, weekStart time.Time, activityType string) ([]WeeklyParticipant, error) {
	activityType = strings.ToLower(strings.TrimSpace(activityType))
	var query string
	var args []interface{}

	if activityType != "" && activityType != "all" {
		query = `
			SELECT r.user_id, u.username, u.faction, COALESCE(SUM(r.area_claimed), 0.0) AS weekly_area, COUNT(r.id) AS weekly_runs
			FROM runs r
			JOIN users u ON u.id = r.user_id
			WHERE r.created_at >= $1
			  AND r.status = 'accepted'
			  AND r.activity_type = $2
			GROUP BY r.user_id, u.username, u.faction
			ORDER BY weekly_area DESC, weekly_runs DESC;
		`
		args = []interface{}{weekStart, activityType}
	} else {
		query = `
			SELECT r.user_id, u.username, u.faction, COALESCE(SUM(r.area_claimed), 0.0) AS weekly_area, COUNT(r.id) AS weekly_runs
			FROM runs r
			JOIN users u ON u.id = r.user_id
			WHERE r.created_at >= $1
			  AND r.status = 'accepted'
			GROUP BY r.user_id, u.username, u.faction
			ORDER BY weekly_area DESC, weekly_runs DESC;
		`
		args = []interface{}{weekStart}
	}

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var standings []WeeklyParticipant
	for rows.Next() {
		var p WeeklyParticipant
		if err := rows.Scan(&p.UserID, &p.Username, &p.Faction, &p.WeeklyAreaSqm, &p.WeeklyRuns); err != nil {
			return nil, err
		}
		standings = append(standings, p)
	}
	return standings, nil
}

// GetFactionStandings aggregates territory dominance by athletic faction in PostgreSQL.
func (s *PostgresStore) GetFactionStandings(ctx context.Context) (*FactionStandingsResponse, error) {
	query := `
		SELECT 
			u.faction, 
			COALESCE(SUM(t.area_sqm), 0.0) AS total_area, 
			COUNT(DISTINCT u.id) AS member_count
		FROM users u
		LEFT JOIN territories t ON t.owner_id = u.id
		WHERE u.faction IS NOT NULL AND u.faction != ''
		GROUP BY u.faction
		ORDER BY total_area DESC, member_count DESC;
	`
	rows, err := s.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query faction standings: %w", err)
	}
	defer rows.Close()

	factions := make(map[string]FactionStanding)

	var totalGlobalArea float64
	for rows.Next() {
		var faction string
		var area float64
		var members int
		if err := rows.Scan(&faction, &area, &members); err != nil {
			return nil, fmt.Errorf("failed to scan faction row: %w", err)
		}
		factions[faction] = FactionStanding{
			Faction:      faction,
			TotalAreaSqm: area,
			MemberCount:  members,
		}
		totalGlobalArea += area
	}

	var standings []FactionStanding
	for _, standing := range factions {
		if totalGlobalArea > 0 {
			standing.Percentage = math.Round((standing.TotalAreaSqm/totalGlobalArea)*1000.0) / 10.0
		} else {
			standing.Percentage = 0.0
		}
		standings = append(standings, standing)
	}

	sort.Slice(standings, func(i, j int) bool {
		if standings[i].TotalAreaSqm == standings[j].TotalAreaSqm {
			return standings[i].MemberCount > standings[j].MemberCount
		}
		return standings[i].TotalAreaSqm > standings[j].TotalAreaSqm
	})

	return &FactionStandingsResponse{
		TotalAreaSqm: totalGlobalArea,
		Standings:    standings,
	}, nil
}

// UpdateUserFaction updates a user's chosen athletic faction in PostgreSQL.
func (s *PostgresStore) UpdateUserFaction(ctx context.Context, userID, faction string) error {
	query := `
		UPDATE users
		SET faction = $1, updated_at = NOW()
		WHERE id = $2;
	`
	cmd, err := s.pool.Exec(ctx, query, faction, userID)
	if err != nil {
		return fmt.Errorf("failed to update user faction: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("user not found: %s", userID)
	}
	return nil
}

func polygonToWKT(ring []geo.LatLng) string {
	points := append([]geo.LatLng(nil), ring...)
	// Ensure ring is closed
	if points[0].Latitude != points[len(points)-1].Latitude || points[0].Longitude != points[len(points)-1].Longitude {
		points = append(points, points[0])
	}
	var sb strings.Builder
	sb.WriteString("POLYGON((")
	for i, pt := range points {
		if i > 0 {
			sb.WriteString(", ")
		}
		// PostGIS WKT convention: <longitude> <latitude>
		sb.WriteString(fmt.Sprintf("%f %f", pt.Longitude, pt.Latitude))
	}
	sb.WriteString("))")
	return sb.String()
}

func lineStringToWKT(points []geo.TrackPoint) string {
	var sb strings.Builder
	sb.WriteString("LINESTRING(")
	for i, pt := range points {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(fmt.Sprintf("%f %f", pt.Longitude, pt.Latitude))
	}
	sb.WriteString(")")
	return sb.String()
}

// SendFriendRequest creates a new pending friendship request from requesterID to addresseeID.
func (s *PostgresStore) SendFriendRequest(ctx context.Context, requesterID, addresseeID string) (*Friendship, error) {
	// Attempt resolution by username if addresseeID doesn't match an exact user ID
	var resolvedAddresseeID string
	resolveQuery := `SELECT id FROM users WHERE id = $1 OR LOWER(username) = LOWER($1) LIMIT 1;`
	if err := s.pool.QueryRow(ctx, resolveQuery, addresseeID).Scan(&resolvedAddresseeID); err == nil {
		addresseeID = resolvedAddresseeID
	}

	if requesterID == addresseeID {
		return nil, fmt.Errorf("cannot send friend request to yourself")
	}

	var existingStatus string
	checkQuery := `
		SELECT status FROM friendships
		WHERE (requester_id = $1 AND addressee_id = $2)
		   OR (requester_id = $2 AND addressee_id = $1)
		LIMIT 1;
	`
	err := s.pool.QueryRow(ctx, checkQuery, requesterID, addresseeID).Scan(&existingStatus)
	if err == nil {
		if existingStatus == "accepted" {
			return nil, fmt.Errorf("already friends")
		}
		if existingStatus == "pending" {
			return nil, fmt.Errorf("friend request already pending")
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("failed to check existing friendship: %w", err)
	}

	// Anti-abuse: check pending limits
	var pendingSent int
	_ = s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM friendships WHERE requester_id = $1 AND status = 'pending';`, requesterID).Scan(&pendingSent)
	if pendingSent >= 25 {
		return nil, fmt.Errorf("maximum pending friend request limit (25) reached")
	}

	var pendingReceived int
	_ = s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM friendships WHERE addressee_id = $1 AND status = 'pending';`, addresseeID).Scan(&pendingReceived)
	if pendingReceived >= 50 {
		return nil, fmt.Errorf("target runner has reached maximum pending friend requests limit (50)")
	}

	id := fmt.Sprintf("friendship_%d", time.Now().UnixNano())
	insertQuery := `
		INSERT INTO friendships (id, requester_id, addressee_id, status, created_at, updated_at)
		VALUES ($1, $2, $3, 'pending', NOW(), NOW())
		RETURNING id, requester_id, addressee_id, status, created_at, updated_at;
	`
	var f Friendship
	err = s.pool.QueryRow(ctx, insertQuery, id, requesterID, addresseeID).Scan(
		&f.ID, &f.RequesterID, &f.AddresseeID, &f.Status, &f.CreatedAt, &f.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert friend request: %w", err)
	}
	return &f, nil
}

// RespondFriendRequest accepts or declines a pending friend request and returns the updated Friendship.
func (s *PostgresStore) RespondFriendRequest(ctx context.Context, friendshipID, userID, action string) (*Friendship, error) {
	if action != "accept" && action != "decline" {
		return nil, fmt.Errorf("invalid action: %s (must be 'accept' or 'decline')", action)
	}

	newStatus := "accepted"
	if action == "decline" {
		newStatus = "declined"
	}

	query := `
		UPDATE friendships
		SET status = $1, updated_at = NOW()
		WHERE id = $2 AND addressee_id = $3 AND status = 'pending'
		RETURNING id, requester_id, addressee_id, status, created_at, updated_at;
	`
	var f Friendship
	err := s.pool.QueryRow(ctx, query, newStatus, friendshipID, userID).Scan(
		&f.ID, &f.RequesterID, &f.AddresseeID, &f.Status, &f.CreatedAt, &f.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("pending request not found or unauthorized")
		}
		return nil, fmt.Errorf("failed to respond to friend request: %w", err)
	}
	return &f, nil
}

// RemoveFriend dissolves an accepted mutual friendship between userA and userB.
func (s *PostgresStore) RemoveFriend(ctx context.Context, userA, userB string) error {
	query := `
		DELETE FROM friendships
		WHERE ((requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1))
		  AND status = 'accepted';
	`
	cmd, err := s.pool.Exec(ctx, query, userA, userB)
	if err != nil {
		return fmt.Errorf("failed to remove friend: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("friendship not found")
	}
	return nil
}

// GetFriends returns all accepted friends of the given user.
func (s *PostgresStore) GetFriends(ctx context.Context, userID string) ([]FriendUser, error) {
	query := `
		SELECT u.id, u.username, u.faction, u.total_area_sqm, u.level, u.xp, u.total_runs
		FROM users u
		JOIN friendships f ON (
			(f.requester_id = u.id AND f.addressee_id = $1) OR
			(f.addressee_id = u.id AND f.requester_id = $1)
		)
		WHERE f.status = 'accepted'
		ORDER BY u.total_area_sqm DESC;
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query friends: %w", err)
	}
	defer rows.Close()

	var friends []FriendUser
	for rows.Next() {
		var u FriendUser
		if err := rows.Scan(&u.ID, &u.Username, &u.Faction, &u.TotalAreaSqm, &u.Level, &u.XP, &u.TotalRuns); err != nil {
			return nil, fmt.Errorf("failed to scan friend row: %w", err)
		}
		friends = append(friends, u)
	}
	return friends, nil
}

// GetFriendRequests returns all pending friend requests involving the user.
func (s *PostgresStore) GetFriendRequests(ctx context.Context, userID string) ([]FriendRequestDetail, error) {
	query := `
		SELECT 
			f.id, f.requester_id, req.username, req.faction,
			f.addressee_id, addr.username, f.status, f.created_at,
			(f.addressee_id = $1) AS is_incoming
		FROM friendships f
		JOIN users req ON req.id = f.requester_id
		JOIN users addr ON addr.id = f.addressee_id
		WHERE (f.requester_id = $1 OR f.addressee_id = $1) AND f.status = 'pending'
		ORDER BY f.created_at DESC;
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query friend requests: %w", err)
	}
	defer rows.Close()

	var details []FriendRequestDetail
	for rows.Next() {
		var d FriendRequestDetail
		if err := rows.Scan(
			&d.ID, &d.RequesterID, &d.RequesterName, &d.RequesterFaction,
			&d.AddresseeID, &d.AddresseeName, &d.Status, &d.CreatedAt, &d.IsIncoming,
		); err != nil {
			return nil, fmt.Errorf("failed to scan friend request row: %w", err)
		}
		details = append(details, d)
	}
	return details, nil
}

// CreateDuel initiates a new head-to-head duel challenge.
func (s *PostgresStore) CreateDuel(ctx context.Context, d *Duel) error {
	if d.ChallengerID == d.OpponentID {
		return fmt.Errorf("cannot challenge yourself to a duel")
	}
	if strings.TrimSpace(d.OpponentID) == "" {
		return fmt.Errorf("opponent ID cannot be empty")
	}

	// Validate XP Stake
	if d.XpStake < 0 || d.XpStake > 1000 {
		return fmt.Errorf("xp stake must be between 0 and 1000")
	}
	if d.XpStake == 0 {
		d.XpStake = 100
	}

	// Validate Target Type and Value
	if d.TargetType != "distance" {
		d.TargetType = "area"
	}
	if d.TargetType == "area" {
		if d.TargetValue <= 0 {
			d.TargetValue = 10000.0
		} else if d.TargetValue < 500.0 || d.TargetValue > 500000.0 {
			return fmt.Errorf("target value for area duel must be between 500 and 500,000 sqm")
		}
	} else {
		if d.TargetValue <= 0 {
			d.TargetValue = 5.0
		} else if d.TargetValue >= 100.0 {
			if d.TargetValue < 500.0 || d.TargetValue > 50000.0 {
				return fmt.Errorf("distance duel target must be between 500m (0.5km) and 50,000m (50km)")
			}
			d.TargetValue = d.TargetValue / 1000.0
		} else {
			if d.TargetValue < 0.5 || d.TargetValue > 50.0 {
				return fmt.Errorf("distance duel target must be between 0.5 and 50.0 km")
			}
		}
	}

	// Check if opponent exists
	var opponentExists bool
	_ = s.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1);`, d.OpponentID).Scan(&opponentExists)
	if !opponentExists {
		return fmt.Errorf("opponent not found: %s", d.OpponentID)
	}

	// Anti-abuse: Check duplicate active/pending duel between these two runners
	var existingDuels int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM duels
		WHERE ((challenger_id = $1 AND opponent_id = $2) OR (challenger_id = $2 AND opponent_id = $1))
		  AND status IN ('pending', 'active')
		  AND expires_at > NOW();
	`, d.ChallengerID, d.OpponentID).Scan(&existingDuels)
	if err == nil && existingDuels > 0 {
		return fmt.Errorf("an active or pending duel already exists between these runners")
	}

	// Anti-abuse: Check concurrent active duels limit (max 5 active per runner)
	var activeCount int
	_ = s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM duels
		WHERE (challenger_id = $1 OR opponent_id = $1)
		  AND status = 'active'
		  AND expires_at > NOW();
	`, d.ChallengerID).Scan(&activeCount)
	if activeCount >= 5 {
		return fmt.Errorf("maximum active duel limit (5) reached")
	}

	// Anti-abuse: Check pending challenges limit (max 10 pending created)
	var pendingCreated int
	_ = s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM duels
		WHERE challenger_id = $1
		  AND status = 'pending'
		  AND expires_at > NOW();
	`, d.ChallengerID).Scan(&pendingCreated)
	if pendingCreated >= 10 {
		return fmt.Errorf("maximum pending duel challenge limit (10) reached")
	}

	// Anti-abuse: Check opponent pending challenges limit (max 10 pending received)
	var opponentPending int
	_ = s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM duels
		WHERE opponent_id = $1
		  AND status = 'pending'
		  AND expires_at > NOW();
	`, d.OpponentID).Scan(&opponentPending)
	if opponentPending >= 10 {
		return fmt.Errorf("opponent has reached maximum pending duel challenges (10)")
	}

	if d.ID == "" {
		d.ID = fmt.Sprintf("duel_%s", uuid.New().String())
	}
	if d.ExpiresAt.IsZero() {
		d.ExpiresAt = time.Now().UTC().Add(24 * time.Hour)
	}
	if d.ActivityType == "" {
		d.ActivityType = "running"
	}

	query := `
		INSERT INTO duels (id, challenger_id, opponent_id, activity_type, target_type, target_value, status, challenger_progress, opponent_progress, xp_stake, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, 'pending', 0.0, 0.0, $7, $8, NOW());
	`
	_, err = s.pool.Exec(ctx, query, d.ID, d.ChallengerID, d.OpponentID, d.ActivityType, d.TargetType, d.TargetValue, d.XpStake, d.ExpiresAt)
	if err != nil {
		return fmt.Errorf("failed to insert duel: %w", err)
	}
	return nil
}

// GetDuelsByUser retrieves active, pending, and recent duels involving the user.
func (s *PostgresStore) GetDuelsByUser(ctx context.Context, userID string) ([]Duel, error) {
	query := `
		SELECT 
			d.id, d.challenger_id, ch.username, d.opponent_id, op.username,
			COALESCE(d.activity_type, 'running'), d.target_type, d.target_value, d.status, d.challenger_progress, d.opponent_progress,
			COALESCE(d.winner_id, ''), d.xp_stake, d.expires_at, d.created_at, d.completed_at
		FROM duels d
		JOIN users ch ON ch.id = d.challenger_id
		JOIN users op ON op.id = d.opponent_id
		WHERE d.challenger_id = $1 OR d.opponent_id = $1
		ORDER BY d.created_at DESC;
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query duels: %w", err)
	}
	defer rows.Close()

	now := time.Now().UTC()
	var duels []Duel
	for rows.Next() {
		var d Duel
		if err := rows.Scan(
			&d.ID, &d.ChallengerID, &d.ChallengerUsername, &d.OpponentID, &d.OpponentUsername,
			&d.ActivityType, &d.TargetType, &d.TargetValue, &d.Status, &d.ChallengerProgress, &d.OpponentProgress,
			&d.WinnerID, &d.XpStake, &d.ExpiresAt, &d.CreatedAt, &d.CompletedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan duel row: %w", err)
		}

		// Check expiration
		if (d.Status == "active" || d.Status == "pending") && now.After(d.ExpiresAt) {
			if d.Status == "active" {
				if d.ChallengerProgress > d.OpponentProgress {
					d.WinnerID = d.ChallengerID
					d.Status = "completed"
				} else if d.OpponentProgress > d.ChallengerProgress {
					d.WinnerID = d.OpponentID
					d.Status = "completed"
				} else {
					d.Status = "expired"
				}
				completedTime := d.ExpiresAt
				d.CompletedAt = &completedTime
			} else {
				d.Status = "expired"
			}
			// Asynchronously update expired status in DB and award XP if winner
			go func(dID, status, winner string, xp int) {
				_, _ = s.pool.Exec(context.Background(), `UPDATE duels SET status = $1, winner_id = NULLIF($2, ''), completed_at = NOW() WHERE id = $3;`, status, winner, dID)
				if winner != "" && xp > 0 {
					_, _ = s.pool.Exec(context.Background(), `UPDATE users SET xp = xp + $1 WHERE id = $2;`, xp, winner)
				}
			}(d.ID, d.Status, d.WinnerID, d.XpStake)
		}

		duels = append(duels, d)
	}
	return duels, nil
}

// AcceptDuel transitions a pending duel to active.
func (s *PostgresStore) AcceptDuel(ctx context.Context, duelID, userID string) error {
	query := `
		UPDATE duels
		SET status = 'active', expires_at = NOW() + INTERVAL '24 hours'
		WHERE id = $1 AND opponent_id = $2 AND status = 'pending' AND expires_at > NOW();
	`
	cmd, err := s.pool.Exec(ctx, query, duelID, userID)
	if err != nil {
		return fmt.Errorf("failed to accept duel: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("pending duel not found, expired, or unauthorized")
	}
	return nil
}

// DeclineDuel marks a pending duel as declined.
func (s *PostgresStore) DeclineDuel(ctx context.Context, duelID, userID string) error {
	query := `
		UPDATE duels
		SET status = 'declined'
		WHERE id = $1 AND opponent_id = $2 AND status = 'pending';
	`
	cmd, err := s.pool.Exec(ctx, query, duelID, userID)
	if err != nil {
		return fmt.Errorf("failed to decline duel: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("pending duel not found or unauthorized")
	}
	return nil
}

// UpdateDuelProgress increments progress for any active duels involving userID matching the run's activity type.
func (s *PostgresStore) UpdateDuelProgress(ctx context.Context, userID, activityType string, areaDelta, distanceDelta float64) error {
	activityType = strings.ToLower(strings.TrimSpace(activityType))
	if activityType == "" {
		activityType = "running"
	}
	query := `
		SELECT id, challenger_id, opponent_id, target_type, target_value, challenger_progress, opponent_progress, xp_stake
		FROM duels
		WHERE status = 'active' AND expires_at > NOW() AND (challenger_id = $1 OR opponent_id = $1) AND activity_type = $2;
	`
	rows, err := s.pool.Query(ctx, query, userID, activityType)
	if err != nil {
		return fmt.Errorf("failed to query active duels for progress: %w", err)
	}
	defer rows.Close()

	type duelUpdate struct {
		id          string
		newChProg   float64
		newOpProg   float64
		isCompleted bool
		winnerID    string
		xpStake     int
	}

	var updates []duelUpdate
	for rows.Next() {
		var id, chID, opID, targetType string
		var targetValue, chProg, opProg float64
		var xpStake int
		if err := rows.Scan(&id, &chID, &opID, &targetType, &targetValue, &chProg, &opProg, &xpStake); err != nil {
			continue
		}

		var increment float64
		if targetType == "distance" {
			increment = distanceDelta / 1000.0 // in km
		} else {
			increment = areaDelta // in m²
		}
		if increment <= 0 {
			continue
		}

		if chID == userID {
			chProg += increment
		} else if opID == userID {
			opProg += increment
		}

		isCompleted := false
		winnerID := ""
		if chProg >= targetValue {
			isCompleted = true
			winnerID = chID
		} else if opProg >= targetValue {
			isCompleted = true
			winnerID = opID
		}

		updates = append(updates, duelUpdate{
			id:          id,
			newChProg:   chProg,
			newOpProg:   opProg,
			isCompleted: isCompleted,
			winnerID:    winnerID,
			xpStake:     xpStake,
		})
	}

	for _, u := range updates {
		if u.isCompleted {
			_, _ = s.pool.Exec(ctx, `
				UPDATE duels
				SET challenger_progress = $1, opponent_progress = $2, status = 'completed', winner_id = $3, completed_at = NOW()
				WHERE id = $4;
			`, u.newChProg, u.newOpProg, u.winnerID, u.id)
			if u.winnerID != "" {
				_, _ = s.pool.Exec(ctx, `UPDATE users SET xp = xp + $1 WHERE id = $2;`, u.xpStake, u.winnerID)
			}
		} else {
			_, _ = s.pool.Exec(ctx, `
				UPDATE duels
				SET challenger_progress = $1, opponent_progress = $2
				WHERE id = $3;
			`, u.newChProg, u.newOpProg, u.id)
		}
	}

	return nil
}

// GetPrivacyZones returns all privacy zones configured for a user.
func (s *PostgresStore) GetPrivacyZones(ctx context.Context, userID string) ([]PrivacyZone, error) {
	query := `
		SELECT id, user_id, name, latitude, longitude, radius_meters, is_enabled, created_at
		FROM privacy_zones
		WHERE user_id = $1
		ORDER BY created_at ASC;
	`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query privacy zones: %w", err)
	}
	defer rows.Close()

	var zones []PrivacyZone
	for rows.Next() {
		var z PrivacyZone
		if err := rows.Scan(&z.ID, &z.UserID, &z.Name, &z.Latitude, &z.Longitude, &z.RadiusMeters, &z.IsEnabled, &z.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan privacy zone: %w", err)
		}
		zones = append(zones, z)
	}
	if zones == nil {
		zones = []PrivacyZone{}
	}
	return zones, nil
}

// SetPrivacyZones replaces all privacy zones for a user.
func (s *PostgresStore) SetPrivacyZones(ctx context.Context, userID string, zones []PrivacyZone) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin tx for privacy zones: %w", err)
	}
	defer tx.Rollback(ctx)

	// Delete existing zones for this user
	if _, err := tx.Exec(ctx, `DELETE FROM privacy_zones WHERE user_id = $1;`, userID); err != nil {
		return fmt.Errorf("failed to clear existing privacy zones: %w", err)
	}

	insertQuery := `
		INSERT INTO privacy_zones (id, user_id, name, latitude, longitude, radius_meters, is_enabled, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
	`
	now := time.Now().UTC()
	for _, z := range zones {
		createdAt := z.CreatedAt
		if createdAt.IsZero() {
			createdAt = now
		}
		if _, err := tx.Exec(ctx, insertQuery, z.ID, userID, z.Name, z.Latitude, z.Longitude, z.RadiusMeters, z.IsEnabled, createdAt); err != nil {
			return fmt.Errorf("failed to insert privacy zone %s: %w", z.ID, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit privacy zones: %w", err)
	}
	return nil
}

// GetUserSettings returns user settings defaulting live_visibility to 'off', timezone to 'UTC', and land_reminders to true.
func (s *PostgresStore) GetUserSettings(ctx context.Context, userID string) (*UserSettings, error) {
	var vis, tz string
	var reminders bool
	err := s.pool.QueryRow(ctx, `
		SELECT 
			COALESCE(live_visibility, 'off'),
			COALESCE(timezone, 'UTC'),
			COALESCE(land_reminders, true)
		FROM users WHERE id = $1;
	`, userID).Scan(&vis, &tz, &reminders)
	if err != nil {
		// User might not exist yet in users table, default safely
		return &UserSettings{LiveVisibility: "off", Timezone: "UTC", LandReminders: true}, nil
	}
	if vis == "" {
		vis = "off"
	}
	if tz == "" {
		tz = "UTC"
	}
	return &UserSettings{LiveVisibility: vis, Timezone: tz, LandReminders: reminders}, nil
}

// UpdateUserSettings updates user settings, creating user row if absent.
func (s *PostgresStore) UpdateUserSettings(ctx context.Context, userID string, settings *UserSettings) error {
	vis := "off"
	tz := "UTC"
	reminders := true
	if settings != nil {
		if settings.LiveVisibility != "" {
			vis = settings.LiveVisibility
		}
		if settings.Timezone != "" {
			tz = settings.Timezone
		}
		reminders = settings.LandReminders
	}

	query := `
		INSERT INTO users (id, username, live_visibility, timezone, land_reminders, updated_at)
		VALUES ($1, $1, $2, $3, $4, NOW())
		ON CONFLICT (id) DO UPDATE
		SET live_visibility = EXCLUDED.live_visibility,
		    timezone = EXCLUDED.timezone,
		    land_reminders = EXCLUDED.land_reminders,
		    updated_at = NOW();
	`
	if _, err := s.pool.Exec(ctx, query, userID, vis, tz, reminders); err != nil {
		return fmt.Errorf("failed to update user settings: %w", err)
	}
	return nil
}

// DecayAdvisoryLockKey is the stable cluster-wide 32-bit key for guarding decay notifications.
const DecayAdvisoryLockKey = 7429103

// TryAcquireDecayLock attempts to acquire a cluster-wide Postgres advisory lock for the decay notification job.
func (s *PostgresStore) TryAcquireDecayLock(ctx context.Context) (bool, func(), error) {
	conn, err := s.pool.Acquire(ctx)
	if err != nil {
		return false, func() {}, fmt.Errorf("failed to acquire pgx connection for advisory lock: %w", err)
	}

	var acquired bool
	err = conn.QueryRow(ctx, `SELECT pg_try_advisory_lock($1);`, DecayAdvisoryLockKey).Scan(&acquired)
	if err != nil {
		conn.Release()
		return false, func() {}, fmt.Errorf("error attempting advisory lock: %w", err)
	}

	if !acquired {
		conn.Release()
		return false, func() {}, nil
	}

	unlock := func() {
		defer conn.Release()
		_, _ = conn.Exec(context.Background(), `SELECT pg_advisory_unlock($1);`, DecayAdvisoryLockKey)
	}
	return true, unlock, nil
}

// GetRecentDecayNotifications returns decay notifications sent to ownerID since the specified time.
func (s *PostgresStore) GetRecentDecayNotifications(ctx context.Context, ownerID string, since time.Time) ([]DecayNotification, error) {
	query := `
		SELECT id, owner_id, territory_id, threshold, sent_at
		FROM decay_notifications
		WHERE owner_id = $1 AND sent_at >= $2
		ORDER BY sent_at DESC;
	`
	rows, err := s.pool.Query(ctx, query, ownerID, since)
	if err != nil {
		return nil, fmt.Errorf("failed to query recent decay notifications: %w", err)
	}
	defer rows.Close()

	var notifs []DecayNotification
	for rows.Next() {
		var n DecayNotification
		if err := rows.Scan(&n.ID, &n.OwnerID, &n.TerritoryID, &n.Threshold, &n.SentAt); err != nil {
			return nil, fmt.Errorf("failed to scan decay notification: %w", err)
		}
		notifs = append(notifs, n)
	}
	return notifs, rows.Err()
}

// HasDecayNotificationBeenSent checks if a notification for territoryID and threshold has been sent since the specified time.
func (s *PostgresStore) HasDecayNotificationBeenSent(ctx context.Context, territoryID string, threshold int, since time.Time) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM decay_notifications
			WHERE territory_id = $1 AND threshold = $2 AND sent_at >= $3
		);
	`
	var exists bool
	err := s.pool.QueryRow(ctx, query, territoryID, threshold, since).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed to check existing decay notification: %w", err)
	}
	return exists, nil
}

// RecordDecayNotification stores a recorded decay push notification for deduplication.
func (s *PostgresStore) RecordDecayNotification(ctx context.Context, ownerID, territoryID string, threshold int, sentAt time.Time) error {
	query := `
		INSERT INTO decay_notifications (owner_id, territory_id, threshold, sent_at)
		VALUES ($1, $2, $3, $4);
	`
	if _, err := s.pool.Exec(ctx, query, ownerID, territoryID, threshold, sentAt); err != nil {
		return fmt.Errorf("failed to record decay notification: %w", err)
	}
	return nil
}

// GetCurrentSeason returns the active calendar month season or creates it if not present.
func (s *PostgresStore) GetCurrentSeason(ctx context.Context, now time.Time) (*Season, error) {
	now = now.UTC()
	seasonID := fmt.Sprintf("season_%d_%02d", now.Year(), now.Month())
	seasonName := fmt.Sprintf("%s %d", now.Month().String(), now.Year())
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, time.UTC)

	query := `
		INSERT INTO seasons (id, name, starts_at, ends_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
		RETURNING id, name, starts_at, ends_at, created_at;
	`
	var season Season
	err := s.pool.QueryRow(ctx, query, seasonID, seasonName, start, end, now).Scan(
		&season.ID, &season.Name, &season.StartsAt, &season.EndsAt, &season.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get current season: %w", err)
	}
	return &season, nil
}

// GetSeasonStandingByUser returns runner standing for the given season.
func (s *PostgresStore) GetSeasonStandingByUser(ctx context.Context, seasonID, userID string) (*SeasonUserStanding, error) {
	query := `
		WITH ranked AS (
			SELECT
				season_id,
				user_id,
				faction,
				total_area_sqm,
				total_distance_m,
				xp,
				updated_at,
				DENSE_RANK() OVER (ORDER BY total_area_sqm DESC) as season_rank
			FROM season_standings
			WHERE season_id = $1
		)
		SELECT r.season_id, r.user_id, COALESCE(u.username, 'Runner'), r.faction, r.season_rank, r.total_area_sqm, r.total_distance_m, r.xp, r.updated_at
		FROM ranked r
		LEFT JOIN users u ON u.id = r.user_id
		WHERE r.user_id = $2;
	`
	var st SeasonUserStanding
	err := s.pool.QueryRow(ctx, query, seasonID, userID).Scan(
		&st.SeasonID, &st.UserID, &st.Username, &st.Faction, &st.SeasonRank,
		&st.TotalAreaSqm, &st.TotalDistanceM, &st.XP, &st.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get user season standing: %w", err)
	}
	return &st, nil
}

// GetSeasonFactionStandings returns faction aggregated standings for a season.
func (s *PostgresStore) GetSeasonFactionStandings(ctx context.Context, seasonID string) ([]SeasonFactionStanding, error) {
	query := `
		SELECT
			faction,
			COALESCE(SUM(total_area_sqm), 0) as total_area_sqm,
			COALESCE(SUM(total_distance_m), 0) as total_distance_m,
			COUNT(DISTINCT user_id) as runner_count
		FROM season_standings
		WHERE season_id = $1 AND faction != ''
		GROUP BY faction
		ORDER BY total_area_sqm DESC;
	`
	rows, err := s.pool.Query(ctx, query, seasonID)
	if err != nil {
		return nil, fmt.Errorf("failed to get season faction standings: %w", err)
	}
	defer rows.Close()

	var standings []SeasonFactionStanding
	for rows.Next() {
		var f SeasonFactionStanding
		if err := rows.Scan(&f.Faction, &f.TotalAreaSqm, &f.TotalDistanceM, &f.RunnerCount); err != nil {
			return nil, err
		}
		standings = append(standings, f)
	}
	if standings == nil {
		standings = []SeasonFactionStanding{}
	}
	return standings, nil
}

// RecordSeasonProgress increments a runner's season standing metrics.
func (s *PostgresStore) RecordSeasonProgress(ctx context.Context, seasonID, userID, faction string, areaSqm, distanceM float64, xp int) error {
	query := `
		INSERT INTO season_standings (season_id, user_id, faction, total_area_sqm, total_distance_m, xp, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
		ON CONFLICT (season_id, user_id) DO UPDATE SET
			total_area_sqm = season_standings.total_area_sqm + EXCLUDED.total_area_sqm,
			total_distance_m = season_standings.total_distance_m + EXCLUDED.total_distance_m,
			xp = season_standings.xp + EXCLUDED.xp,
			faction = CASE WHEN EXCLUDED.faction != '' THEN EXCLUDED.faction ELSE season_standings.faction END,
			updated_at = NOW();
	`
	_, err := s.pool.Exec(ctx, query, seasonID, userID, faction, areaSqm, distanceM, xp)
	return err
}

// CreateCrew creates a new crew and assigns creator as leader.
func (s *PostgresStore) CreateCrew(ctx context.Context, creatorID, name, joinCode string) (*Crew, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Check if user is already in a crew
	var existingCrewID string
	err = tx.QueryRow(ctx, `SELECT crew_id FROM crew_memberships WHERE user_id = $1`, creatorID).Scan(&existingCrewID)
	if err == nil {
		return nil, errors.New("User is already a member of a crew")
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	crewID := "crew_" + uuid.NewString()[:8]
	var c Crew
	insertCrewQuery := `
		INSERT INTO crews (id, name, join_code, creator_id, created_at)
		VALUES ($1, $2, $3, $4, NOW())
		RETURNING id, name, join_code, creator_id, created_at;
	`
	if err := tx.QueryRow(ctx, insertCrewQuery, crewID, name, joinCode, creatorID).Scan(
		&c.ID, &c.Name, &c.JoinCode, &c.CreatorID, &c.CreatedAt,
	); err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return nil, errors.New("Crew name is already taken")
		}
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO crew_memberships (crew_id, user_id, role, joined_at)
		VALUES ($1, $2, 'leader', NOW());
	`, crewID, creatorID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &c, nil
}

// JoinCrew adds a runner to a crew by joinCode. Enforces 10-runner limit and 1-crew-per-user limit.
func (s *PostgresStore) JoinCrew(ctx context.Context, userID, joinCode string) (*Crew, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var existingCrew string
	err = tx.QueryRow(ctx, `SELECT crew_id FROM crew_memberships WHERE user_id = $1`, userID).Scan(&existingCrew)
	if err == nil {
		return nil, errors.New("You are already in a crew")
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	var c Crew
	err = tx.QueryRow(ctx, `SELECT id, name, join_code, creator_id, created_at FROM crews WHERE join_code = $1 FOR UPDATE`, joinCode).Scan(
		&c.ID, &c.Name, &c.JoinCode, &c.CreatorID, &c.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("Invalid join code")
		}
		return nil, err
	}

	var count int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM crew_memberships WHERE crew_id = $1`, c.ID).Scan(&count); err != nil {
		return nil, err
	}
	if count >= 10 {
		return nil, errors.New("Crew is at maximum capacity (10 runners)")
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO crew_memberships (crew_id, user_id, role, joined_at)
		VALUES ($1, $2, 'member', NOW());
	`, c.ID, userID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &c, nil
}

// GetCrewByUserID retrieves the crew the user belongs to, or nil if none.
func (s *PostgresStore) GetCrewByUserID(ctx context.Context, userID string) (*Crew, string, error) {
	query := `
		SELECT c.id, c.name, c.join_code, c.creator_id, c.created_at, cm.role
		FROM crew_memberships cm
		JOIN crews c ON c.id = cm.crew_id
		WHERE cm.user_id = $1;
	`
	var c Crew
	var role string
	err := s.pool.QueryRow(ctx, query, userID).Scan(
		&c.ID, &c.Name, &c.JoinCode, &c.CreatorID, &c.CreatedAt, &role,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, "", nil
		}
		return nil, "", fmt.Errorf("failed to get crew by user: %w", err)
	}
	return &c, role, nil
}

// GetCrewMembers returns all members of a crew along with their weekly contributions.
func (s *PostgresStore) GetCrewMembers(ctx context.Context, crewID string, weekStart time.Time) ([]CrewMember, error) {
	weekEnd := weekStart.AddDate(0, 0, 7)
	query := `
		SELECT
			cm.crew_id,
			cm.user_id,
			COALESCE(u.username, 'Runner') as username,
			cm.role,
			cm.joined_at,
			COALESCE(SUM(r.distance_meters), 0) as weekly_distance_m,
			COALESCE(SUM(r.area_claimed), 0) as weekly_area_sqm
		FROM crew_memberships cm
		LEFT JOIN users u ON u.id = cm.user_id
		LEFT JOIN runs r ON r.user_id = cm.user_id AND r.created_at >= $2 AND r.created_at < $3
		WHERE cm.crew_id = $1
		GROUP BY cm.crew_id, cm.user_id, u.username, cm.role, cm.joined_at
		ORDER BY CASE WHEN cm.role = 'leader' THEN 0 ELSE 1 END, weekly_distance_m DESC;
	`
	rows, err := s.pool.Query(ctx, query, crewID, weekStart, weekEnd)
	if err != nil {
		return nil, fmt.Errorf("failed to get crew members: %w", err)
	}
	defer rows.Close()

	var members []CrewMember
	for rows.Next() {
		var m CrewMember
		if err := rows.Scan(
			&m.CrewID, &m.UserID, &m.Username, &m.Role, &m.JoinedAt,
			&m.WeeklyDistanceM, &m.WeeklyAreaSqm,
		); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	if members == nil {
		members = []CrewMember{}
	}
	return members, nil
}

// SetCrewGoal sets the active weekly goal for a crew.
func (s *PostgresStore) SetCrewGoal(ctx context.Context, crewID, goalType string, targetValue float64, weekStart time.Time, createdBy string) (*CrewGoal, error) {
	goalID := "goal_" + uuid.NewString()[:8]
	query := `
		INSERT INTO crew_goals (id, crew_id, goal_type, target_value, week_start, created_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
		ON CONFLICT (crew_id, week_start) DO UPDATE SET
			goal_type = EXCLUDED.goal_type,
			target_value = EXCLUDED.target_value,
			created_by = EXCLUDED.created_by,
			created_at = NOW()
		RETURNING id, crew_id, goal_type, target_value, week_start, created_by, created_at;
	`
	var g CrewGoal
	err := s.pool.QueryRow(ctx, query, goalID, crewID, goalType, targetValue, weekStart, createdBy).Scan(
		&g.ID, &g.CrewID, &g.GoalType, &g.TargetValue, &g.WeekStart, &g.CreatedBy, &g.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to set crew goal: %w", err)
	}
	return &g, nil
}

// GetActiveCrewGoal returns the active goal for a crew for the given weekStart, with calculated progress.
func (s *PostgresStore) GetActiveCrewGoal(ctx context.Context, crewID string, weekStart time.Time) (*CrewGoal, error) {
	weekEnd := weekStart.AddDate(0, 0, 7)
	query := `
		SELECT id, crew_id, goal_type, target_value, week_start, created_by, created_at
		FROM crew_goals
		WHERE crew_id = $1 AND week_start = $2;
	`
	var g CrewGoal
	err := s.pool.QueryRow(ctx, query, crewID, weekStart).Scan(
		&g.ID, &g.CrewID, &g.GoalType, &g.TargetValue, &g.WeekStart, &g.CreatedBy, &g.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get active crew goal: %w", err)
	}

	progressQuery := `
		SELECT
			COALESCE(SUM(CASE WHEN $3 = 'area' THEN r.area_claimed ELSE r.distance_meters END), 0)
		FROM runs r
		JOIN crew_memberships cm ON cm.user_id = r.user_id
		WHERE cm.crew_id = $1 AND r.created_at >= $2 AND r.created_at < $4;
	`
	var currentVal float64
	if err := s.pool.QueryRow(ctx, progressQuery, crewID, weekStart, g.GoalType, weekEnd).Scan(&currentVal); err != nil {
		return nil, fmt.Errorf("failed to calculate crew goal progress: %w", err)
	}
	g.CurrentValue = currentVal
	if g.TargetValue > 0 {
		g.ProgressPercent = math.Min(100.0, (currentVal/g.TargetValue)*100.0)
	}
	return &g, nil
}
