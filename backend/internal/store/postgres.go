package store

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
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

// GetRunsByUser retrieves recent runs for a user.
func (s *PostgresStore) GetRunsByUser(ctx context.Context, userID string, limit int) ([]Run, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT id, user_id, idempotency_key, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
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
			&r.ID, &r.UserID, &r.IdempotencyKey, &r.DurationSeconds, &r.DistanceMeters,
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
		SELECT id, user_id, idempotency_key, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
		FROM runs
		WHERE idempotency_key = $1;
	`
	var r Run
	err := s.pool.QueryRow(ctx, query, key).Scan(
		&r.ID, &r.UserID, &r.IdempotencyKey, &r.DurationSeconds, &r.DistanceMeters,
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
		SELECT t.id, t.owner_id, u.username, ST_AsGeoJSON(t.geom), t.area_sqm, COALESCE(t.strength, 100.0), COALESCE(t.last_defended_at, t.updated_at), t.updated_at
		FROM territories t
		JOIN users u ON t.owner_id = u.id
		WHERE ST_Intersects(t.geom, ST_MakeEnvelope($1, $2, $3, $4, 4326));
	`
	rows, err := s.pool.Query(ctx, query, minLng, minLat, maxLng, maxLat)
	if err != nil {
		return nil, fmt.Errorf("bbox query failed: %w", err)
	}
	defer rows.Close()

	var list []Territory
	for rows.Next() {
		var t Territory
		if err := rows.Scan(&t.ID, &t.OwnerID, &t.Username, &t.GeoJSON, &t.AreaSqm, &t.Strength, &t.LastDefendedAt, &t.UpdatedAt); err != nil {
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
		SELECT id, user_id, idempotency_key, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, status, created_at
		FROM runs WHERE idempotency_key = $1;
	`, run.IdempotencyKey).Scan(
		&existing.ID, &existing.UserID, &existing.IdempotencyKey, &existing.DurationSeconds,
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

		xpAwarded := int(math.Max(100, math.Round(existing.AreaClaimed/20.0)))
		return &CaptureResult{
			RunID:              existing.ID,
			IdempotencyKey:     existing.IdempotencyKey,
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
			INSERT INTO territories (id, owner_id, geom, area_sqm, strength, last_defended_at, updated_at)
			VALUES ($1, $2, ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_PolygonFromText($3, 4326)), 3)), ST_Area(ST_MakeValid(ST_PolygonFromText($3, 4326))::geography), 100.0, NOW(), NOW())
			ON CONFLICT (id) DO UPDATE SET
				geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Union(territories.geom, ST_MakeValid(ST_PolygonFromText($3, 4326)))), 3)),
				area_sqm = ST_Area(ST_MakeValid(ST_Union(territories.geom, ST_MakeValid(ST_PolygonFromText($3, 4326))))::geography),
				strength = 100.0,
				last_defended_at = NOW(),
				updated_at = NOW()
			RETURNING ST_AsGeoJSON(geom), area_sqm;
		`
		if err := tx.QueryRow(ctx, unionQuery, territoryID, run.UserID, polyWKT).Scan(&territoryGeoJSON, &playerTotalArea); err != nil {
			return nil, fmt.Errorf("failed to union owner territory: %w", err)
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

		xpAwarded = int(math.Max(100, math.Round(areaClaimed/20.0)))
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

	insertRunQuery := `
		INSERT INTO runs (id, user_id, idempotency_key, duration_seconds, distance_meters, area_claimed, anomaly_score, anomaly_reasons, path, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CASE WHEN $9::text IS NOT NULL THEN ST_GeomFromText($9, 4326) ELSE NULL END, $10, NOW());
	`
	anomalyReasons := run.AnomalyReasons
	if anomalyReasons == nil {
		anomalyReasons = []string{}
	}
	status := run.Status
	if status == "" {
		status = "accepted"
	}

	if _, err := tx.Exec(ctx, insertRunQuery,
		run.ID, run.UserID, run.IdempotencyKey, run.DurationSeconds, run.DistanceMeters,
		areaClaimed, run.AnomalyScore, anomalyReasons, pathWKT, status,
	); err != nil {
		return nil, fmt.Errorf("failed to insert run: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit capture transaction: %w", err)
	}

	return &CaptureResult{
		RunID:              run.ID,
		IdempotencyKey:     run.IdempotencyKey,
		Status:             run.Status,
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

// GetLeaderboard fetches the top users ranked by claimed surface area.
func (s *PostgresStore) GetLeaderboard(ctx context.Context, limit int) ([]LeaderboardEntry, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT id, username, faction, total_area_sqm, level, total_runs
		FROM users
		ORDER BY total_area_sqm DESC
		LIMIT $1;
	`
	rows, err := s.pool.Query(ctx, query, limit)
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

// ApplyTerritoryDecay updates all territories by decaying strength based on elapsed days since last_defended_at.
func (s *PostgresStore) ApplyTerritoryDecay(ctx context.Context, decayPerDay float64) error {
	if decayPerDay <= 0 {
		decayPerDay = 15.0
	}
	query := `
		UPDATE territories
		SET
			strength = GREATEST(0.0, LEAST(100.0, strength - (EXTRACT(EPOCH FROM (NOW() - last_defended_at)) / 86400.0 * $1))),
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
		SELECT t.id, t.owner_id, u.username, ST_AsGeoJSON(t.geom), t.area_sqm, COALESCE(t.strength, 100.0), COALESCE(t.last_defended_at, t.updated_at), t.updated_at
		FROM territories t
		JOIN users u ON t.owner_id = u.id
		WHERE t.id = $1;
	`
	var t Territory
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&t.ID, &t.OwnerID, &t.Username, &t.GeoJSON, &t.AreaSqm, &t.Strength, &t.LastDefendedAt, &t.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error querying territory by id: %w", err)
	}
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

// GetWeeklyStandings returns aggregated runner stats for runs submitted since weekStart.
func (s *PostgresStore) GetWeeklyStandings(ctx context.Context, weekStart time.Time) ([]WeeklyParticipant, error) {
	query := `
		SELECT r.user_id, u.username, u.faction, COALESCE(SUM(r.area_claimed), 0.0) AS weekly_area, COUNT(r.id) AS weekly_runs
		FROM runs r
		JOIN users u ON u.id = r.user_id
		WHERE r.created_at >= $1
		  AND r.status = 'accepted'
		GROUP BY r.user_id, u.username, u.faction
		ORDER BY weekly_area DESC, weekly_runs DESC;
	`
	rows, err := s.pool.Query(ctx, query, weekStart)
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
