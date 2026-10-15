package geo_test

import (
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fixturePoint struct {
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Timestamp time.Time `json:"timestamp"`
}

type goldenFixture struct {
	Name                     string         `json:"name"`
	Description              string         `json:"description"`
	MinClosureDistanceMeters float64        `json:"min_closure_distance_meters"`
	MinPointsRequired        int            `json:"min_points_required"`
	MinLoopDistanceMeters    float64        `json:"min_loop_distance_meters"`
	MaxLoopAreaSqM           float64        `json:"max_loop_area_sqm"`
	IsValid                  bool           `json:"is_valid"`
	ExpectedAreaSqM          float64        `json:"expected_area_sqm"`
	AreaTolerancePercent     float64        `json:"area_tolerance_percent"`
	ExpectedRejectionReason  string         `json:"expected_rejection_reason"`
	Points                   []fixturePoint `json:"points"`
}

func loadFixture(t *testing.T, filename string) goldenFixture {
	t.Helper()
	// Locate test_fixtures relative to current test or workspace
	candidates := []string{
		filepath.Join("..", "..", "..", "test_fixtures", filename),
		filepath.Join("..", "..", "test_fixtures", filename),
		filepath.Join("..", "test_fixtures", filename),
		filepath.Join("test_fixtures", filename),
	}
	var data []byte
	var err error
	for _, path := range candidates {
		data, err = os.ReadFile(path)
		if err == nil {
			break
		}
	}
	require.NoError(t, err, "failed to read test fixture: %s", filename)

	var f goldenFixture
	err = json.Unmarshal(data, &f)
	require.NoError(t, err, "failed to parse fixture json: %s", filename)
	return f
}

func TestGoldenValidLoop(t *testing.T) {
	fixture := loadFixture(t, "golden_valid_loop.json")
	require.True(t, fixture.IsValid)

	engine := geo.NewEngine(geo.Config{
		MinClosureDistanceMeters:    fixture.MinClosureDistanceMeters,
		MinPointsRequired:           fixture.MinPointsRequired,
		MinLoopDistanceMeters:       fixture.MinLoopDistanceMeters,
		MaxLoopAreaSqM:              fixture.MaxLoopAreaSqM,
		MinStationaryDistanceMeters: 1.8,
		MaxSpeedKmhOutlier:          35.0,
	})

	var enclosed *geo.EnclosedLoop
	for _, p := range fixture.Points {
		loop, err := engine.AddPoint(geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		})
		require.NoError(t, err)
		if loop != nil {
			enclosed = loop
			break
		}
	}

	require.NotNil(t, enclosed, "Golden valid loop should trigger enclosure")
	assert.GreaterOrEqual(t, len(enclosed.Polygon), fixture.MinPointsRequired)

	// Validate area within stated tolerance of 0.5%
	expected := fixture.ExpectedAreaSqM
	delta := math.Abs(enclosed.AreaSqMeters - expected)
	diffPercent := (delta / expected) * 100.0

	assert.LessOrEqual(t, diffPercent, fixture.AreaTolerancePercent,
		"Go area (%.2f m²) must match Dart (%.2f m²) within %.2f%% tolerance (actual diff: %.3f%%)",
		enclosed.AreaSqMeters, expected, fixture.AreaTolerancePercent, diffPercent)
}

func TestGoldenFigure8Rejected(t *testing.T) {
	fixture := loadFixture(t, "golden_figure_8.json")
	require.False(t, fixture.IsValid)

	latLngs := make([]geo.LatLng, len(fixture.Points))
	for i, p := range fixture.Points {
		latLngs[i] = geo.LatLng{Latitude: p.Latitude, Longitude: p.Longitude}
	}

	assert.True(t, geo.HasSelfIntersection(latLngs), "Figure-8 geometry must report self-intersection")

	engine := geo.NewEngine()
	var finalErr error
	for _, p := range fixture.Points {
		_, err := engine.AddPoint(geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		})
		if err != nil {
			finalErr = err
			break
		}
	}

	require.Error(t, finalErr)
	assert.Contains(t, finalErr.Error(), fixture.ExpectedRejectionReason)
}

func TestGoldenTinyLoopRejected(t *testing.T) {
	fixture := loadFixture(t, "golden_tiny_loop.json")
	require.False(t, fixture.IsValid)

	engine := geo.NewEngine(geo.Config{
		MinClosureDistanceMeters:    fixture.MinClosureDistanceMeters,
		MinPointsRequired:           fixture.MinPointsRequired,
		MinLoopDistanceMeters:       fixture.MinLoopDistanceMeters,
		MaxLoopAreaSqM:              fixture.MaxLoopAreaSqM,
		MinStationaryDistanceMeters: 1.8,
		MaxSpeedKmhOutlier:          35.0,
	})

	var enclosed *geo.EnclosedLoop
	for _, p := range fixture.Points {
		loop, _ := engine.AddPoint(geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		})
		if loop != nil {
			enclosed = loop
			break
		}
	}

	assert.Nil(t, enclosed, "Tiny loop with perimeter < 40m must not trigger enclosure")
}

func TestGoldenHugeLoopRejected(t *testing.T) {
	fixture := loadFixture(t, "golden_huge_loop.json")
	require.False(t, fixture.IsValid)

	engine := geo.NewEngine(geo.Config{
		MinClosureDistanceMeters:    fixture.MinClosureDistanceMeters,
		MinPointsRequired:           fixture.MinPointsRequired,
		MinLoopDistanceMeters:       fixture.MinLoopDistanceMeters,
		MaxLoopAreaSqM:              fixture.MaxLoopAreaSqM,
		MinStationaryDistanceMeters: 1.8,
		MaxSpeedKmhOutlier:          35.0,
	})

	latLngs := make([]geo.LatLng, len(fixture.Points))
	for i, p := range fixture.Points {
		latLngs[i] = geo.LatLng{Latitude: p.Latitude, Longitude: p.Longitude}
	}

	_, err := engine.ValidateLoop(latLngs, time.Now())
	require.Error(t, err)
	assert.ErrorIs(t, err, geo.ErrLoopAreaTooLarge)
}

func TestGoldenLassoLoop(t *testing.T) {
	fixture := loadFixture(t, "golden_lasso_loop.json")
	require.True(t, fixture.IsValid)

	engine := geo.NewEngine()
	trackPoints := make([]geo.TrackPoint, len(fixture.Points))
	for i, p := range fixture.Points {
		trackPoints[i] = geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		}
	}

	loops, err := engine.ProcessTrack(trackPoints)
	require.NoError(t, err)
	require.Len(t, loops, 1)

	expected := fixture.ExpectedAreaSqM
	delta := math.Abs(loops[0].AreaSqMeters - expected)
	diffPercent := (delta / expected) * 100.0
	assert.LessOrEqual(t, diffPercent, fixture.AreaTolerancePercent,
		"Lasso area (%.2f m²) must match expected (%.2f m²) within %.2f%% tolerance (actual diff: %.3f%%)",
		loops[0].AreaSqMeters, expected, fixture.AreaTolerancePercent, diffPercent)
}

func TestGoldenLoopWithCrossing(t *testing.T) {
	fixture := loadFixture(t, "golden_loop_with_crossing.json")
	require.True(t, fixture.IsValid)

	engine := geo.NewEngine()
	trackPoints := make([]geo.TrackPoint, len(fixture.Points))
	for i, p := range fixture.Points {
		trackPoints[i] = geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		}
	}

	loops, err := engine.ProcessTrack(trackPoints)
	require.NoError(t, err)
	require.Len(t, loops, 1, "Must retain 1 valid loop despite crossing")

	expected := fixture.ExpectedAreaSqM
	delta := math.Abs(loops[0].AreaSqMeters - expected)
	diffPercent := (delta / expected) * 100.0
	assert.LessOrEqual(t, diffPercent, fixture.AreaTolerancePercent,
		"Loop area (%.2f m²) must match expected (%.2f m²) within %.2f%% tolerance",
		loops[0].AreaSqMeters, expected, fixture.AreaTolerancePercent)
}

func TestGoldenTwoLoops(t *testing.T) {
	fixture := loadFixture(t, "golden_two_loops.json")
	require.True(t, fixture.IsValid)

	engine := geo.NewEngine()
	trackPoints := make([]geo.TrackPoint, len(fixture.Points))
	for i, p := range fixture.Points {
		trackPoints[i] = geo.TrackPoint{
			Latitude:  p.Latitude,
			Longitude: p.Longitude,
			Timestamp: p.Timestamp,
		}
	}

	loops, err := engine.ProcessTrack(trackPoints)
	require.NoError(t, err)
	require.Len(t, loops, 2, "Must detect both valid loops in track sequence")

	totalArea := 0.0
	for _, l := range loops {
		totalArea += l.AreaSqMeters
	}

	expected := fixture.ExpectedAreaSqM
	delta := math.Abs(totalArea - expected)
	diffPercent := (delta / expected) * 100.0
	assert.LessOrEqual(t, diffPercent, fixture.AreaTolerancePercent,
		"Total 2-loop area (%.2f m²) must match expected (%.2f m²) within %.2f%% tolerance",
		totalArea, expected, fixture.AreaTolerancePercent)
}
