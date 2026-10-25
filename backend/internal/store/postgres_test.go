//go:build integration

package store_test

import (
	"context"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func getTestConnStr() string {
	if u := os.Getenv("TEST_DATABASE_URL"); u != "" {
		return u
	}
	if u := os.Getenv("DATABASE_URL"); u != "" {
		return u
	}
	return "postgres://runner:runnerpass@localhost:5432/territory_runner?sslmode=disable"
}

func readMigration(filename string) (string, error) {
	candidates := []string{
		filepath.Join("..", "..", "migrations", filename),
		filepath.Join("migrations", filename),
		filepath.Join("backend", "migrations", filename),
	}
	for _, p := range candidates {
		data, err := os.ReadFile(p)
		if err == nil {
			return string(data), nil
		}
	}
	return "", fmt.Errorf("migration file %s not found", filename)
}

func resetSchema(ctx context.Context, pool *pgxpool.Pool) error {
	downFiles := []string{
		"000011_add_territory_last_decayed_at.down.sql",
		"000010_add_user_settings.down.sql",
		"000009_add_duel_activity_type.down.sql",
		"000008_add_friends_duels_constraints.down.sql",
		"000007_add_activity_type.down.sql",
		"000006_add_privacy_zones.down.sql",
		"000005_add_friends_and_duels.down.sql",
		"000004_add_faction_index.down.sql",
		"000003_add_device_tokens.down.sql",
		"000002_add_territory_strength.down.sql",
		"000001_init_schema.down.sql",
	}

	for _, df := range downFiles {
		if sql, err := readMigration(df); err == nil && sql != "" {
			_, _ = pool.Exec(ctx, sql)
		}
	}
	_, _ = pool.Exec(ctx, "DROP TABLE IF EXISTS duels, friendships, privacy_zones, device_tokens, runs, territories, users CASCADE;")

	upFiles := []string{
		"000001_init_schema.up.sql",
		"000002_add_territory_strength.up.sql",
		"000003_add_device_tokens.up.sql",
		"000004_add_faction_index.up.sql",
		"000005_add_friends_and_duels.up.sql",
		"000006_add_privacy_zones.up.sql",
		"000007_add_activity_type.up.sql",
		"000008_add_friends_duels_constraints.up.sql",
		"000009_add_duel_activity_type.up.sql",
		"000010_add_user_settings.up.sql",
		"000011_add_territory_last_decayed_at.up.sql",
	}

	for _, uf := range upFiles {
		sql, err := readMigration(uf)
		if err != nil {
			return fmt.Errorf("failed reading migration %s: %w", uf, err)
		}
		if _, err := pool.Exec(ctx, sql); err != nil {
			return fmt.Errorf("failed executing migration %s: %w", uf, err)
		}
	}
	return nil
}

func setupTestStore(t *testing.T) (*store.PostgresStore, *pgxpool.Pool) {
	connStr := getTestConnStr()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cfg, err := pgxpool.ParseConfig(connStr)
	if err != nil {
		t.Skipf("Skipping integration test: invalid connection string %q: %v", connStr, err)
	}

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Skipf("Skipping integration test: cannot connect to Postgres at %s: %v", connStr, err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		t.Skipf("Skipping integration test: ping failed at %s: %v", connStr, err)
	}

	if err := resetSchema(ctx, pool); err != nil {
		pool.Close()
		t.Fatalf("failed to reset test schema: %v", err)
	}

	st, err := store.NewPostgresStore(ctx, connStr)
	require.NoError(t, err)

	t.Cleanup(func() {
		st.Close()
		pool.Close()
	})

	return st, pool
}

// 1. Migrations up and down on empty database
func TestMigrations_UpAndDown(t *testing.T) {
	connStr := getTestConnStr()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		t.Skipf("Skipping: cannot connect: %v", err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		t.Skipf("Skipping: ping failed: %v", err)
	}

	up1, err := readMigration("000001_init_schema.up.sql")
	require.NoError(t, err)
	down1, err := readMigration("000001_init_schema.down.sql")
	require.NoError(t, err)
	up2, err := readMigration("000002_add_territory_strength.up.sql")
	require.NoError(t, err)
	down2, err := readMigration("000002_add_territory_strength.down.sql")
	require.NoError(t, err)

	// Clean slate
	_, _ = pool.Exec(ctx, "DROP TABLE IF EXISTS duels, friendships, privacy_zones, device_tokens, runs, territories, users CASCADE;")
	_, _ = pool.Exec(ctx, down2)
	_, _ = pool.Exec(ctx, down1)

	// Apply Up 1
	_, err = pool.Exec(ctx, up1)
	require.NoError(t, err, "000001_init_schema.up should apply cleanly")

	// Verify tables created
	var tableCount int
	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.tables 
		WHERE table_schema = 'public' AND table_name IN ('users', 'territories', 'runs');
	`).Scan(&tableCount)
	require.NoError(t, err)
	assert.Equal(t, 3, tableCount, "all 3 tables must exist after 000001 up")

	// Apply Up 2
	_, err = pool.Exec(ctx, up2)
	require.NoError(t, err, "000002_add_territory_strength.up should apply cleanly")

	// Verify strength and last_defended_at columns exist
	var colCount int
	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.columns 
		WHERE table_name = 'territories' AND column_name IN ('strength', 'last_defended_at');
	`).Scan(&colCount)
	require.NoError(t, err)
	assert.Equal(t, 2, colCount, "strength and last_defended_at columns must exist after 000002 up")

	// Revert Down 2
	_, err = pool.Exec(ctx, down2)
	require.NoError(t, err, "000002 down should apply cleanly")

	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.columns 
		WHERE table_name = 'territories' AND column_name IN ('strength', 'last_defended_at');
	`).Scan(&colCount)
	require.NoError(t, err)
	assert.Equal(t, 0, colCount, "columns must be removed after 000002 down")

	// Revert Down 1
	_, err = pool.Exec(ctx, down1)
	require.NoError(t, err, "000001 down should apply cleanly")

	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.tables 
		WHERE table_schema = 'public' AND table_name IN ('users', 'territories', 'runs');
	`).Scan(&tableCount)
	require.NoError(t, err)
	assert.Equal(t, 0, tableCount, "tables must be dropped after 000001 down")
}

// 2. Migration 000002 applies cleanly on a database with existing rows
func TestMigration_000002_OnExistingRows(t *testing.T) {
	connStr := getTestConnStr()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		t.Skipf("Skipping: cannot connect: %v", err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		t.Skipf("Skipping: ping failed: %v", err)
	}

	up1, err := readMigration("000001_init_schema.up.sql")
	require.NoError(t, err)
	down1, err := readMigration("000001_init_schema.down.sql")
	require.NoError(t, err)
	up2, err := readMigration("000002_add_territory_strength.up.sql")
	require.NoError(t, err)
	down2, err := readMigration("000002_add_territory_strength.down.sql")
	require.NoError(t, err)

	// Clean slate and apply 000001 only
	_, _ = pool.Exec(ctx, "DROP TABLE IF EXISTS duels, friendships, privacy_zones, device_tokens, runs, territories, users CASCADE;")
	_, _ = pool.Exec(ctx, down2)
	_, _ = pool.Exec(ctx, down1)
	_, err = pool.Exec(ctx, up1)
	require.NoError(t, err)

	// Insert existing rows under 000001 schema (no strength / last_defended_at columns)
	_, err = pool.Exec(ctx, `
		INSERT INTO users (id, username, faction, total_area_sqm, xp, level, total_runs)
		VALUES ('existing_user_1', 'LegacyRunner', 'Cyber Vanguard', 5000.0, 250, 2, 3);
	`)
	require.NoError(t, err)

	_, err = pool.Exec(ctx, `
		INSERT INTO territories (id, owner_id, geom, area_sqm, updated_at)
		VALUES (
			'poly_existing_user_1_territory',
			'existing_user_1',
			ST_Multi(ST_GeomFromText('POLYGON((-0.12 51.50, -0.12 51.51, -0.11 51.51, -0.11 51.50, -0.12 51.50))', 4326)),
			5000.0,
			NOW() - INTERVAL '3 days'
		);
	`)
	require.NoError(t, err)

	// Now apply migration 000002 up on database with existing rows
	_, err = pool.Exec(ctx, up2)
	require.NoError(t, err, "migration 000002 must apply cleanly on existing data without error")

	// Verify existing row received DEFAULT values
	var strength float64
	var lastDefendedAt time.Time
	var ownerID string
	var areaSqm float64
	err = pool.QueryRow(ctx, `
		SELECT owner_id, area_sqm, strength, last_defended_at
		FROM territories
		WHERE id = 'poly_existing_user_1_territory';
	`).Scan(&ownerID, &areaSqm, &strength, &lastDefendedAt)
	require.NoError(t, err)

	assert.Equal(t, "existing_user_1", ownerID)
	assert.InDelta(t, 5000.0, areaSqm, 0.1)
	assert.Equal(t, 100.0, strength, "existing territory must default to 100.0 strength")
	assert.False(t, lastDefendedAt.IsZero(), "last_defended_at must be populated with default timestamp")
	assert.WithinDuration(t, time.Now().UTC(), lastDefendedAt, 10*time.Second)

	// Revert 000002 down and clean up
	_, err = pool.Exec(ctx, down2)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, down1)
	require.NoError(t, err)
}

// 2b. Migration 000011: territories.last_decayed_at column up and down
func TestMigration_000011_AddLastDecayedAt(t *testing.T) {
	_, pool := setupTestStore(t)
	ctx := context.Background()

	up11, err := readMigration("000011_add_territory_last_decayed_at.up.sql")
	require.NoError(t, err)
	down11, err := readMigration("000011_add_territory_last_decayed_at.down.sql")
	require.NoError(t, err)

	// Since setupTestStore already runs all migrations up to 11, verify column exists
	var colCount int
	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.columns 
		WHERE table_name = 'territories' AND column_name = 'last_decayed_at';
	`).Scan(&colCount)
	require.NoError(t, err)
	assert.Equal(t, 1, colCount, "last_decayed_at column must exist in territories initially")

	// Revert 000011 down
	_, err = pool.Exec(ctx, down11)
	require.NoError(t, err, "000011 down should apply cleanly")

	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.columns 
		WHERE table_name = 'territories' AND column_name = 'last_decayed_at';
	`).Scan(&colCount)
	require.NoError(t, err)
	assert.Equal(t, 0, colCount, "last_decayed_at column must be removed after down")

	// Re-apply 000011 up so subsequent tests have the column
	_, err = pool.Exec(ctx, up11)
	require.NoError(t, err, "000011 up should re-apply cleanly")

	err = pool.QueryRow(ctx, `
		SELECT count(*) FROM information_schema.columns 
		WHERE table_name = 'territories' AND column_name = 'last_decayed_at';
	`).Scan(&colCount)
	require.NoError(t, err)
	assert.Equal(t, 1, colCount, "last_decayed_at column must exist after re-applying up")
}

// 3. Loop capture with PostGIS ST_PolygonFromText / ST_MakeValid

func TestPostgres_LoopCapture_ST_PolygonFromText_MakeValid(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	u := &store.User{
		ID:           "pg_runner_loop",
		Username:     "LoopRunner",
		Faction:      "Neon Wardens",
		TotalAreaSqm: 0,
		XP:           0,
		Level:        1,
		TotalRuns:    0,
	}
	require.NoError(t, st.UpsertUser(ctx, u))

	// Closed polygon around London Hyde Park
	ring := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1170},
		{Latitude: 51.5000, Longitude: -0.1170},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	loopArea := geo.ComputeGeodesicShoelaceArea(ring)
	require.Greater(t, loopArea, 1000.0)

	loops := []geo.EnclosedLoop{
		{
			Polygon:      ring,
			AreaSqMeters: loopArea,
		},
	}
	run := &store.Run{
		ID:              "run_pg_loop_1",
		UserID:          u.ID,
		IdempotencyKey:  "idem_pg_loop_1",
		DurationSeconds: 600,
		DistanceMeters:  1200.0,
		Status:          "accepted",
	}

	result, err := st.CaptureRunAndMutateTerritories(ctx, run, loops, nil)
	require.NoError(t, err)
	require.NotNil(t, result)

	assert.Equal(t, run.ID, result.RunID)
	assert.True(t, result.LoopDetected)
	assert.InDelta(t, loopArea, result.AreaClaimedSqm, 1.0)
	assert.Greater(t, result.XpAwarded, 0)
	assert.Contains(t, result.TerritoryGeoJSON, "MultiPolygon")

	// Verify in Postgres directly
	var territoryCount int
	var storedArea float64
	var storedStrength float64
	err = pool.QueryRow(ctx, `
		SELECT count(*), COALESCE(MAX(area_sqm), 0), COALESCE(MAX(strength), 0)
		FROM territories
		WHERE owner_id = $1;
	`, u.ID).Scan(&territoryCount, &storedArea, &storedStrength)
	require.NoError(t, err)

	assert.Equal(t, 1, territoryCount)
	assert.InDelta(t, loopArea, storedArea, 100.0) // PostGIS geodesic area vs Haversine
	assert.Equal(t, 100.0, storedStrength)

	// Verify user stats updated
	updatedUser, err := st.GetUser(ctx, u.ID)
	require.NoError(t, err)
	assert.Equal(t, 1, updatedUser.TotalRuns)
	assert.InDelta(t, storedArea, updatedUser.TotalAreaSqm, 1.0)
	assert.Equal(t, int64(result.XpAwarded), updatedUser.XP)
}

// 4. Self-union with own territory (ST_Union)
func TestPostgres_SelfUnionWithOwnTerritory(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	u := &store.User{
		ID:           "pg_runner_union",
		Username:     "UnionRunner",
		Faction:      "Cyber Vanguard",
		TotalAreaSqm: 0,
		XP:           0,
		Level:        1,
	}
	require.NoError(t, st.UpsertUser(ctx, u))

	// Loop A: [0.000, 51.500] to [0.002, 51.502]
	ringA := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	areaA := geo.ComputeGeodesicShoelaceArea(ringA)

	runA := &store.Run{
		ID:              "run_union_a",
		UserID:          u.ID,
		IdempotencyKey:  "idem_union_a",
		DurationSeconds: 400,
		DistanceMeters:  800.0,
		Status:          "accepted",
	}
	resA, err := st.CaptureRunAndMutateTerritories(ctx, runA, []geo.EnclosedLoop{{Polygon: ringA, AreaSqMeters: areaA}}, nil)
	require.NoError(t, err)
	initialArea := resA.PlayerTotalAreaSqm

	// Loop B: Overlaps 50% with Loop A: [0.001, 51.500] to [0.003, 51.502]
	ringB := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1190},
		{Latitude: 51.5020, Longitude: -0.1190},
		{Latitude: 51.5020, Longitude: -0.1170},
		{Latitude: 51.5000, Longitude: -0.1170},
		{Latitude: 51.5000, Longitude: -0.1190},
	}
	areaB := geo.ComputeGeodesicShoelaceArea(ringB)

	runB := &store.Run{
		ID:              "run_union_b",
		UserID:          u.ID,
		IdempotencyKey:  "idem_union_b",
		DurationSeconds: 420,
		DistanceMeters:  820.0,
		Status:          "accepted",
	}
	resB, err := st.CaptureRunAndMutateTerritories(ctx, runB, []geo.EnclosedLoop{{Polygon: ringB, AreaSqMeters: areaB}}, nil)
	require.NoError(t, err)

	// Due to overlap, union area MUST be strictly less than areaA + areaB
	assert.Less(t, resB.PlayerTotalAreaSqm, initialArea+areaB, "union area must eliminate overlapping duplicate area")
	assert.Greater(t, resB.PlayerTotalAreaSqm, initialArea, "union area must grow beyond initial area")

	// Verify only 1 territory record exists in DB for this user (MultiPolygon union)
	var count int
	err = pool.QueryRow(ctx, "SELECT count(*) FROM territories WHERE owner_id = $1;", u.ID).Scan(&count)
	require.NoError(t, err)
	assert.Equal(t, 1, count, "runner should have exactly one fused MultiPolygon territory")
}

// 5. ST_Difference with rival territory (carving and complete overtake)
func TestPostgres_DifferenceWithRivalTerritory(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	alice := &store.User{ID: "rival_alice", Username: "Alice", Faction: "Shadow Syndicate"}
	bob := &store.User{ID: "conqueror_bob", Username: "Bob", Faction: "Neon Wardens"}
	require.NoError(t, st.UpsertUser(ctx, alice))
	require.NoError(t, st.UpsertUser(ctx, bob))

	// Alice claims large territory
	aliceRing := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5040, Longitude: -0.1200},
		{Latitude: 51.5040, Longitude: -0.1160},
		{Latitude: 51.5000, Longitude: -0.1160},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	aliceArea := geo.ComputeGeodesicShoelaceArea(aliceRing)
	runAlice := &store.Run{
		ID:              "run_alice_initial",
		UserID:          alice.ID,
		IdempotencyKey:  "idem_alice_initial",
		DurationSeconds: 900,
		DistanceMeters:  2000.0,
		Status:          "accepted",
	}
	resAlice, err := st.CaptureRunAndMutateTerritories(ctx, runAlice, []geo.EnclosedLoop{{Polygon: aliceRing, AreaSqMeters: aliceArea}}, nil)
	require.NoError(t, err)
	aliceInitialArea := resAlice.PlayerTotalAreaSqm

	// Bob invades and captures a central chunk of Alice's territory
	bobRing := []geo.LatLng{
		{Latitude: 51.5010, Longitude: -0.1190},
		{Latitude: 51.5030, Longitude: -0.1190},
		{Latitude: 51.5030, Longitude: -0.1170},
		{Latitude: 51.5010, Longitude: -0.1170},
		{Latitude: 51.5010, Longitude: -0.1190},
	}
	bobArea := geo.ComputeGeodesicShoelaceArea(bobRing)
	runBob := &store.Run{
		ID:              "run_bob_invasion",
		UserID:          bob.ID,
		IdempotencyKey:  "idem_bob_invasion",
		DurationSeconds: 500,
		DistanceMeters:  1000.0,
		Status:          "accepted",
	}
	resBob, err := st.CaptureRunAndMutateTerritories(ctx, runBob, []geo.EnclosedLoop{{Polygon: bobRing, AreaSqMeters: bobArea}}, nil)
	require.NoError(t, err)

	// Bob's capture result should list Alice as an affected rival
	assert.Contains(t, resBob.RivalsAffected, alice.ID)

	// Query Alice's territory in Postgres: it should be carved and its area reduced
	var aliceNewArea float64
	err = pool.QueryRow(ctx, "SELECT area_sqm FROM territories WHERE owner_id = $1;", alice.ID).Scan(&aliceNewArea)
	require.NoError(t, err)
	assert.Less(t, aliceNewArea, aliceInitialArea, "Alice's area must decrease after being carved by Bob")

	// Test Complete Overtake: Charlie owns a tiny territory that Bob completely encloses
	charlie := &store.User{ID: "victim_charlie", Username: "Charlie", Faction: "Cyber Vanguard"}
	require.NoError(t, st.UpsertUser(ctx, charlie))

	charlieRing := []geo.LatLng{
		{Latitude: 51.5205, Longitude: -0.1305},
		{Latitude: 51.5210, Longitude: -0.1305},
		{Latitude: 51.5210, Longitude: -0.1300},
		{Latitude: 51.5205, Longitude: -0.1300},
		{Latitude: 51.5205, Longitude: -0.1305},
	}
	charlieArea := geo.ComputeGeodesicShoelaceArea(charlieRing)
	runCharlie := &store.Run{
		ID:              "run_charlie",
		UserID:          charlie.ID,
		IdempotencyKey:  "idem_charlie",
		DurationSeconds: 300,
		DistanceMeters:  500.0,
		Status:          "accepted",
	}
	_, err = st.CaptureRunAndMutateTerritories(ctx, runCharlie, []geo.EnclosedLoop{{Polygon: charlieRing, AreaSqMeters: charlieArea}}, nil)
	require.NoError(t, err)

	// Bob captures a giant loop strictly enclosing Charlie's entire territory
	bobGiantRing := []geo.LatLng{
		{Latitude: 51.5200, Longitude: -0.1310},
		{Latitude: 51.5220, Longitude: -0.1310},
		{Latitude: 51.5220, Longitude: -0.1290},
		{Latitude: 51.5200, Longitude: -0.1290},
		{Latitude: 51.5200, Longitude: -0.1310},
	}
	bobGiantArea := geo.ComputeGeodesicShoelaceArea(bobGiantRing)
	runBobSwallow := &store.Run{
		ID:              "run_bob_swallow",
		UserID:          bob.ID,
		IdempotencyKey:  "idem_bob_swallow",
		DurationSeconds: 800,
		DistanceMeters:  1800.0,
		Status:          "accepted",
	}
	resBobSwallow, err := st.CaptureRunAndMutateTerritories(ctx, runBobSwallow, []geo.EnclosedLoop{{Polygon: bobGiantRing, AreaSqMeters: bobGiantArea}}, nil)
	require.NoError(t, err)
	assert.Contains(t, resBobSwallow.RivalsAffected, charlie.ID)

	// Charlie's territory should be completely deleted from the database
	var charlieTerritoryCount int
	err = pool.QueryRow(ctx, "SELECT count(*) FROM territories WHERE owner_id = $1;", charlie.ID).Scan(&charlieTerritoryCount)
	require.NoError(t, err)
	assert.Equal(t, 0, charlieTerritoryCount, "completely overtaken territory must be deleted from territories table")
}

// 6. Multi-loop run capture and summed XP
func TestPostgres_MultiLoopRunCapture_SummedXP(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	u := &store.User{ID: "pg_multi_runner", Username: "MultiRunner", Faction: "Neon Wardens"}
	require.NoError(t, st.UpsertUser(ctx, u))

	// Loop 1
	ring1 := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5010, Longitude: -0.1200},
		{Latitude: 51.5010, Longitude: -0.1190},
		{Latitude: 51.5000, Longitude: -0.1190},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	area1 := geo.ComputeGeodesicShoelaceArea(ring1)

	// Loop 2 (disjoint)
	ring2 := []geo.LatLng{
		{Latitude: 51.5050, Longitude: -0.1250},
		{Latitude: 51.5060, Longitude: -0.1250},
		{Latitude: 51.5060, Longitude: -0.1240},
		{Latitude: 51.5050, Longitude: -0.1240},
		{Latitude: 51.5050, Longitude: -0.1250},
	}
	area2 := geo.ComputeGeodesicShoelaceArea(ring2)

	multiLoops := []geo.EnclosedLoop{
		{Polygon: ring1, AreaSqMeters: area1},
		{Polygon: ring2, AreaSqMeters: area2},
	}
	run := &store.Run{
		ID:              "run_multi_loops_pg",
		UserID:          u.ID,
		IdempotencyKey:  "idem_multi_pg",
		DurationSeconds: 1200,
		DistanceMeters:  2500.0,
		Status:          "accepted",
	}

	result, err := st.CaptureRunAndMutateTerritories(ctx, run, multiLoops, nil)
	require.NoError(t, err)

	expectedSummedArea := area1 + area2
	expectedXP := int(math.Max(100, math.Round(expectedSummedArea/20.0)))

	assert.True(t, result.LoopDetected)
	assert.InDelta(t, expectedSummedArea, result.AreaClaimedSqm, 1.0)
	assert.Equal(t, expectedXP, result.XpAwarded)

	// Verify user stats in Postgres
	userAfter, err := st.GetUser(ctx, u.ID)
	require.NoError(t, err)
	assert.Equal(t, int64(expectedXP), userAfter.XP)
	assert.Equal(t, 1, userAfter.TotalRuns)

	// Verify multi-polygon in DB contains 2 polygons
	var polyCount int
	err = pool.QueryRow(ctx, "SELECT ST_NumGeometries(geom) FROM territories WHERE owner_id = $1;", u.ID).Scan(&polyCount)
	require.NoError(t, err)
	assert.Equal(t, 2, polyCount, "MultiPolygon must contain both disjoint loop polygons")
}

// 7. Idempotency key replay test on real Postgres
func TestPostgres_IdempotencyKeyReplay(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	u := &store.User{ID: "pg_idem_runner", Username: "IdemRunner", Faction: "Cyber Vanguard"}
	require.NoError(t, st.UpsertUser(ctx, u))

	ring := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	area := geo.ComputeGeodesicShoelaceArea(ring)

	run := &store.Run{
		ID:              "run_pg_idem_first",
		UserID:          u.ID,
		IdempotencyKey:  "idem_pg_exact_key_123",
		DurationSeconds: 500,
		DistanceMeters:  1000.0,
		Status:          "accepted",
	}

	// 1st Submission
	res1, err := st.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{{Polygon: ring, AreaSqMeters: area}}, nil)
	require.NoError(t, err)

	userAfter1, err := st.GetUser(ctx, u.ID)
	require.NoError(t, err)
	xp1 := userAfter1.XP
	runs1 := userAfter1.TotalRuns
	area1 := userAfter1.TotalAreaSqm

	// 2nd Submission (Exact Replay with same IdempotencyKey)
	res2, err := st.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{{Polygon: ring, AreaSqMeters: area}}, nil)
	require.NoError(t, err)

	assert.Equal(t, res1.RunID, res2.RunID)
	assert.Equal(t, res1.AreaClaimedSqm, res2.AreaClaimedSqm)
	assert.Equal(t, res1.XpAwarded, res2.XpAwarded)
	assert.Equal(t, "accepted", res2.Status)

	// User stats MUST NOT be double credited
	userAfter2, err := st.GetUser(ctx, u.ID)
	require.NoError(t, err)
	assert.Equal(t, xp1, userAfter2.XP, "XP must not increase on idempotent replay")
	assert.Equal(t, runs1, userAfter2.TotalRuns, "Total runs must not increase on idempotent replay")
	assert.Equal(t, area1, userAfter2.TotalAreaSqm, "Total area must not change on idempotent replay")

	// Runs table must have exactly 1 record with this idempotency key
	var runCount int
	err = pool.QueryRow(ctx, "SELECT count(*) FROM runs WHERE idempotency_key = $1;", run.IdempotencyKey).Scan(&runCount)
	require.NoError(t, err)
	assert.Equal(t, 1, runCount, "runs table must contain exactly 1 entry for idempotency key")
}

// 8. Strength decay and defense update
func TestPostgres_StrengthDecayAndDefenseUpdate(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	u := &store.User{ID: "pg_defense_runner", Username: "DefenseRunner", Faction: "Cyber Vanguard"}
	require.NoError(t, st.UpsertUser(ctx, u))

	ring := []geo.LatLng{
		{Latitude: 51.5000, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1200},
		{Latitude: 51.5020, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1180},
		{Latitude: 51.5000, Longitude: -0.1200},
	}
	area := geo.ComputeGeodesicShoelaceArea(ring)

	run := &store.Run{
		ID:              "run_defense_1",
		UserID:          u.ID,
		IdempotencyKey:  "idem_defense_1",
		DurationSeconds: 400,
		DistanceMeters:  800.0,
		Status:          "accepted",
	}

	// Capture initial territory
	_, err := st.CaptureRunAndMutateTerritories(ctx, run, []geo.EnclosedLoop{{Polygon: ring, AreaSqMeters: area}}, nil)
	require.NoError(t, err)

	territoryID := fmt.Sprintf("poly_%s_territory", u.ID)
	tInitial, err := st.GetTerritoryByID(ctx, territoryID)
	require.NoError(t, err)
	require.NotNil(t, tInitial)
	assert.InDelta(t, 100.0, tInitial.Strength, 0.01, "initial strength must be 100.0")

	// Artificially simulate 5 days since defense, and 2 days since decay
	fiveDaysAgo := time.Now().UTC().Add(-5 * 24 * time.Hour)
	_, err = pool.Exec(ctx, `
		UPDATE territories
		SET last_defended_at = NOW() - INTERVAL '5 days',
		    last_decayed_at = NOW() - INTERVAL '2 days'
		WHERE id = $1;
	`, territoryID)
	require.NoError(t, err)

	// Apply decay at 15.0 pts/day (2 days * 15 = 30 pts decay -> expect 70.0)
	err = st.ApplyTerritoryDecay(ctx, 15.0)
	require.NoError(t, err)

	tDecayed, err := st.GetTerritoryByID(ctx, territoryID)
	require.NoError(t, err)
	require.NotNil(t, tDecayed)
	assert.InDelta(t, 70.0, tDecayed.Strength, 0.5, "after 2 days since last_decayed_at at 15 pts/day, strength should decay to ~70.0")
	assert.WithinDuration(t, time.Now().UTC(), tDecayed.LastDecayedAt, 5*time.Second, "last_decayed_at must be refreshed to now")
	assert.WithinDuration(t, fiveDaysAgo, tDecayed.LastDefendedAt, 1*time.Minute, "last_defended_at must NEVER be updated by decay")

	// Perform defense update (restore fortifications)
	err = st.UpdateTerritoryDefense(ctx, territoryID, 100.0)
	require.NoError(t, err)

	tDefended, err := st.GetTerritoryByID(ctx, territoryID)
	require.NoError(t, err)
	require.NotNil(t, tDefended)
	assert.InDelta(t, 100.0, tDefended.Strength, 0.01, "strength must be restored to 100.0")
	assert.WithinDuration(t, time.Now().UTC(), tDefended.LastDefendedAt, 5*time.Second, "last_defended_at must be refreshed to now")
	assert.WithinDuration(t, time.Now().UTC(), tDefended.LastDecayedAt, 5*time.Second, "last_decayed_at must be refreshed to now")
}

// 9. Leaderboard ordering on Postgres
func TestPostgres_LeaderboardOrdering(t *testing.T) {
	st, _ := setupTestStore(t)
	ctx := context.Background()

	users := []*store.User{
		{ID: "usr_lead_a", Username: "RunnerAlpha", Faction: "Cyber Vanguard", TotalAreaSqm: 50000.0, Level: 3, TotalRuns: 5},
		{ID: "usr_lead_b", Username: "RunnerBravo", Faction: "Neon Wardens", TotalAreaSqm: 120000.0, Level: 7, TotalRuns: 15},
		{ID: "usr_lead_c", Username: "RunnerCharlie", Faction: "Shadow Syndicate", TotalAreaSqm: 85000.0, Level: 5, TotalRuns: 10},
		{ID: "usr_lead_d", Username: "RunnerDelta", Faction: "Cyber Vanguard", TotalAreaSqm: 0.0, Level: 1, TotalRuns: 0},
	}

	for _, u := range users {
		require.NoError(t, st.UpsertUser(ctx, u))
	}

	leaderboard, err := st.GetLeaderboard(ctx, 10, "")
	require.NoError(t, err)
	require.GreaterOrEqual(t, len(leaderboard), 4)

	// Filter down to our test users
	testRanks := make(map[string]store.LeaderboardEntry)
	for _, entry := range leaderboard {
		testRanks[entry.UserID] = entry
	}

	assert.Contains(t, testRanks, "usr_lead_b")
	assert.Contains(t, testRanks, "usr_lead_c")
	assert.Contains(t, testRanks, "usr_lead_a")
	assert.Contains(t, testRanks, "usr_lead_d")

	// Strictly descending order: Bravo (120k) > Charlie (85k) > Alpha (50k) > Delta (0k)
	assert.Greater(t, testRanks["usr_lead_b"].TotalAreaSqm, testRanks["usr_lead_c"].TotalAreaSqm)
	assert.Greater(t, testRanks["usr_lead_c"].TotalAreaSqm, testRanks["usr_lead_a"].TotalAreaSqm)
	assert.Greater(t, testRanks["usr_lead_a"].TotalAreaSqm, testRanks["usr_lead_d"].TotalAreaSqm)

	// Verify ranks in the top list are sequential starting at 1
	for i := 0; i < len(leaderboard)-1; i++ {
		assert.Equal(t, i+1, leaderboard[i].Rank)
		assert.GreaterOrEqual(t, leaderboard[i].TotalAreaSqm, leaderboard[i+1].TotalAreaSqm)
	}
}

// 10. Device Tokens persistence in PostgreSQL
func TestPostgres_DeviceTokensPersistence(t *testing.T) {
	st, _ := setupTestStore(t)
	ctx := context.Background()

	userID := "usr_token_test_1"
	require.NoError(t, st.UpsertUser(ctx, &store.User{ID: userID, Username: "TokenTester", Faction: "Cyber Vanguard"}))

	// Register two device tokens
	require.NoError(t, st.SaveDeviceToken(ctx, userID, "token_pixel_7"))
	require.NoError(t, st.SaveDeviceToken(ctx, userID, "token_ipad_pro"))

	// Idempotent re-registration
	require.NoError(t, st.SaveDeviceToken(ctx, userID, "token_pixel_7"))

	tokens, err := st.GetDeviceTokens(ctx, userID)
	require.NoError(t, err)
	assert.ElementsMatch(t, []string{"token_pixel_7", "token_ipad_pro"}, tokens)
}

// 11. Weekly League query aggregation in PostgreSQL
func TestPostgres_WeeklyLeagueQuery(t *testing.T) {
	st, _ := setupTestStore(t)
	ctx := context.Background()

	now := time.Now().UTC()
	weekStart := now.Add(-12 * time.Hour)
	priorToWeek := now.Add(-10 * 24 * time.Hour) // Outside active week

	u1 := &store.User{ID: "usr_league_gold", Username: "GoldSprinter", Faction: "Cyber Vanguard"}
	u2 := &store.User{ID: "usr_league_silver", Username: "SilverPacer", Faction: "Neon Syndicate"}
	u3 := &store.User{ID: "usr_league_old", Username: "OldTimer", Faction: "Solaris Nomads"}

	require.NoError(t, st.UpsertUser(ctx, u1))
	require.NoError(t, st.UpsertUser(ctx, u2))
	require.NoError(t, st.UpsertUser(ctx, u3))

	// Active week runs
	loop1 := []geo.EnclosedLoop{{
		AreaSqMeters: 12500.0,
		Polygon: []geo.LatLng{
			{Latitude: 51.51, Longitude: -0.11},
			{Latitude: 51.52, Longitude: -0.11},
			{Latitude: 51.52, Longitude: -0.10},
			{Latitude: 51.51, Longitude: -0.10},
			{Latitude: 51.51, Longitude: -0.11},
		},
	}}
	_, err := st.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_league_01",
		UserID:         u1.ID,
		IdempotencyKey: "idem_league_01",
		Status:         "accepted",
		CreatedAt:      now.Add(-2 * time.Hour),
	}, loop1, nil)
	require.NoError(t, err)

	loop2 := []geo.EnclosedLoop{{
		AreaSqMeters: 4500.0,
		Polygon: []geo.LatLng{
			{Latitude: 51.53, Longitude: -0.11},
			{Latitude: 51.54, Longitude: -0.11},
			{Latitude: 51.54, Longitude: -0.10},
			{Latitude: 51.53, Longitude: -0.10},
			{Latitude: 51.53, Longitude: -0.11},
		},
	}}
	_, err = st.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_league_02",
		UserID:         u2.ID,
		IdempotencyKey: "idem_league_02",
		Status:         "accepted",
		CreatedAt:      now.Add(-4 * time.Hour),
	}, loop2, nil)
	require.NoError(t, err)

	// Prior to active week run - should NOT be included in weekly standings
	loopOld := []geo.EnclosedLoop{{
		AreaSqMeters: 50000.0,
		Polygon: []geo.LatLng{
			{Latitude: 51.55, Longitude: -0.11},
			{Latitude: 51.56, Longitude: -0.11},
			{Latitude: 51.56, Longitude: -0.10},
			{Latitude: 51.55, Longitude: -0.10},
			{Latitude: 51.55, Longitude: -0.11},
		},
	}}
	_, err = st.CaptureRunAndMutateTerritories(ctx, &store.Run{
		ID:             "run_league_old",
		UserID:         u3.ID,
		IdempotencyKey: "idem_league_old",
		Status:         "accepted",
		CreatedAt:      priorToWeek,
	}, loopOld, nil)
	require.NoError(t, err)

	standings, err := st.GetWeeklyStandings(ctx, weekStart, "")
	require.NoError(t, err)
	require.Len(t, standings, 2, "Only users with runs in active week should be included")

	// Order: u1 (GoldSprinter) > u2 (SilverPacer)
	assert.Equal(t, u1.ID, standings[0].UserID)
	assert.Equal(t, "GoldSprinter", standings[0].Username)
	assert.Greater(t, standings[0].WeeklyAreaSqm, standings[1].WeeklyAreaSqm)

	assert.Equal(t, u2.ID, standings[1].UserID)
	assert.Equal(t, "SilverPacer", standings[1].Username)
}

func TestPostgres_PrivacyZonesPersistence(t *testing.T) {
	st, pool := setupTestStore(t)
	ctx := context.Background()

	// Ensure migration 000006 is applied
	up6, err := readMigration("000006_add_privacy_zones.up.sql")
	require.NoError(t, err)
	_, err = pool.Exec(ctx, up6)
	require.NoError(t, err)

	user := &store.User{
		ID:       "usr_privacy_tester",
		Username: "PrivacyRunner",
		Faction:  "Cyber Vanguard",
	}
	require.NoError(t, st.UpsertUser(ctx, user))

	// 1. Initial query returns empty list
	zones, err := st.GetPrivacyZones(ctx, user.ID)
	require.NoError(t, err)
	assert.Empty(t, zones)

	// 2. Set 2 privacy zones
	inputZones := []store.PrivacyZone{
		{
			ID:           "zone_home_1",
			Name:         "Home Sanctuary",
			Latitude:     37.7749,
			Longitude:    -122.4194,
			RadiusMeters: 200.0,
			IsEnabled:    true,
		},
		{
			ID:           "zone_office_1",
			Name:         "Office Campus",
			Latitude:     37.7833,
			Longitude:    -122.4167,
			RadiusMeters: 150.0,
			IsEnabled:    false,
		},
	}
	err = st.SetPrivacyZones(ctx, user.ID, inputZones)
	require.NoError(t, err)

	// 3. Retrieve and verify
	retrieved, err := st.GetPrivacyZones(ctx, user.ID)
	require.NoError(t, err)
	require.Len(t, retrieved, 2)
	assert.Equal(t, "zone_home_1", retrieved[0].ID)
	assert.Equal(t, "Home Sanctuary", retrieved[0].Name)
	assert.Equal(t, 200.0, retrieved[0].RadiusMeters)
	assert.True(t, retrieved[0].IsEnabled)
	assert.Equal(t, "zone_office_1", retrieved[1].ID)
	assert.False(t, retrieved[1].IsEnabled)

	// 4. Update (replace with 1 zone)
	updatedZones := []store.PrivacyZone{
		{
			ID:           "zone_new_home",
			Name:         "New Home Base",
			Latitude:     37.7750,
			Longitude:    -122.4190,
			RadiusMeters: 300.0,
			IsEnabled:    true,
		},
	}
	err = st.SetPrivacyZones(ctx, user.ID, updatedZones)
	require.NoError(t, err)

	retrieved2, err := st.GetPrivacyZones(ctx, user.ID)
	require.NoError(t, err)
	require.Len(t, retrieved2, 1)
	assert.Equal(t, "zone_new_home", retrieved2[0].ID)
	assert.Equal(t, "New Home Base", retrieved2[0].Name)

	// 5. Clear all zones
	err = st.SetPrivacyZones(ctx, user.ID, []store.PrivacyZone{})
	require.NoError(t, err)

	retrieved3, err := st.GetPrivacyZones(ctx, user.ID)
	require.NoError(t, err)
	assert.Empty(t, retrieved3)
}
