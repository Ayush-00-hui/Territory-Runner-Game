package anticheat_test

import (
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGenuineJoggingTracePasses(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := make([]geo.TrackPoint, 10)
	for i := 0; i < 10; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.00003),
			Longitude: -122.4194 + (float64(i) * 0.00003),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.7, // ~9.7 km/h (typical jogging pace)
			Heading:   45.0 + float64(i%3),
			IsMocked:  false,
		}
	}

	result := detector.EvaluateTrack(points)
	assert.False(t, result.IsAnomaly, "Genuine human jog must not be flagged")
	assert.Less(t, result.Score, 3.0)
}

func TestMockLocationFlaggedImmediately(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     2.0,
			Heading:   0.0,
			IsMocked:  true,
		},
	}

	result := detector.EvaluateTrack(points)
	assert.True(t, result.IsAnomaly)
	assert.Equal(t, 99.0, result.Score)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "Mock location provider detected")
}

func TestVehicleSpeedExceedsHumanCeiling(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     16.6, // ~60 km/h (Car driving)
			Heading:   90.0,
			IsMocked:  false,
		},
	}

	result := detector.EvaluateTrack(points)
	assert.True(t, result.IsAnomaly)
	assert.Greater(t, result.Score, 3.0)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "exceeds human running ceiling")
}

func TestTeleportationJumpDetected(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     2.0,
			Heading:   0.0,
		},
		{
			Latitude:  37.7849, // ~1.1km jump in 1 second
			Longitude: -122.4194,
			Timestamp: now.Add(1 * time.Second),
			Speed:     2.0,
			Heading:   0.0,
		},
	}

	result := detector.EvaluateTrack(points)
	assert.True(t, result.IsAnomaly)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "Position teleportation jump detected")
}

func TestRunning_RejectsCyclingSpeeds(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Cycling pace: 28 km/h (~7.8 m/s)
	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     7.8, // 28.08 km/h
			Heading:   0.0,
		},
		{
			Latitude:  37.7750,
			Longitude: -122.4194,
			Timestamp: now.Add(1 * time.Second),
			Speed:     7.8,
			Heading:   0.0,
		},
		{
			Latitude:  37.7751,
			Longitude: -122.4194,
			Timestamp: now.Add(2 * time.Second),
			Speed:     7.8,
			Heading:   0.0,
		},
	}

	result := detector.EvaluateTrackWithActivity(points, "running")
	assert.True(t, result.IsAnomaly, "Cycling speed must be flagged when activity is running")
	assert.GreaterOrEqual(t, result.Score, 50.0, "Speed exceeding running ceiling must score >= 50 for rejection")
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "exceeds human running ceiling")
}

func TestCycling_AcceptsCyclingSpeeds(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Cycling pace: 28 km/h (~7.8 m/s)
	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     7.8,
			Heading:   45.0,
		},
		{
			Latitude:  37.7750,
			Longitude: -122.4194,
			Timestamp: now.Add(1 * time.Second),
			Speed:     7.8,
			Heading:   45.0,
		},
		{
			Latitude:  37.7751,
			Longitude: -122.4194,
			Timestamp: now.Add(2 * time.Second),
			Speed:     7.8,
			Heading:   45.0,
		},
	}

	result := detector.EvaluateTrackWithActivity(points, "cycling")
	assert.False(t, result.IsAnomaly, "Normal cycling speed must not be flagged when activity is cycling")
	assert.Less(t, result.Score, 3.0)
}

func TestCycling_RejectsMotorizedVehicleSpeeds(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Highway car speed: 72 km/h (20 m/s)
	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     20.0,
			Heading:   90.0,
		},
	}

	result := detector.EvaluateTrackWithActivity(points, "cycling")
	assert.True(t, result.IsAnomaly, "Highway vehicle speed must be flagged even under cycling")
	assert.GreaterOrEqual(t, result.Score, 50.0)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "exceeds cycling ceiling")
}

func TestWalking_RejectsRunningSpeeds(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Running speed: ~14 km/h (3.9 m/s)
	points := []geo.TrackPoint{
		{
			Latitude:  37.7749,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     3.9,
			Heading:   0.0,
		},
	}

	result := detector.EvaluateTrackWithActivity(points, "walking")
	assert.True(t, result.IsAnomaly, "Running speed must be flagged when activity is walking")
	assert.GreaterOrEqual(t, result.Score, 50.0)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "exceeds walking ceiling")
}

func TestRunning_RejectsSuperhumanAverageSpeed(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Average speed 23.4 km/h (6.5 m/s) over multiple points
	points := make([]geo.TrackPoint, 5)
	for i := 0; i < 5; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.00005),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     6.5,
			Heading:   0.0,
		}
	}

	result := detector.EvaluateTrackWithActivity(points, "running")
	assert.True(t, result.IsAnomaly, "Average speed exceeding 22 km/h must be flagged for running")
	assert.GreaterOrEqual(t, result.Score, 50.0)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "exceeds running endurance ceiling")
}

func TestBiomechanicalAccelerationCeiling(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Speed burst from 0.0 m/s to 6.0 m/s in 0.5s (accel = 12.0 m/s²)
	// Speed 6.0 m/s = 21.6 km/h is below running ceiling (25.0 km/h),
	// but acceleration 12.0 m/s² exceeds running acceleration limit (8.0 m/s²)
	runningPoints := []geo.TrackPoint{
		{
			Latitude:  37.774900,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     0.0,
		},
		{
			Latitude:  37.774913, // ~1.5m displacement (avg speed 3.0 m/s = 10.8 km/h)
			Longitude: -122.4194,
			Timestamp: now.Add(500 * time.Millisecond),
			Speed:     6.0, // dv = 6.0 m/s in 0.5s = 12.0 m/s²
		},
	}

	result := detector.EvaluateTrackWithActivity(runningPoints, "running")
	assert.True(t, result.IsAnomaly)
	require.NotEmpty(t, result.Reasons)
	assert.Contains(t, result.Reasons[0], "Biomechanical acceleration limit exceeded")

	// Same 12 m/s² burst is acceptable for cycling (limit 12.0 m/s²)
	cyclingResult := detector.EvaluateTrackWithActivity(runningPoints, "cycling")
	assert.False(t, cyclingResult.IsAnomaly)

	// Extreme vehicle burst (dv = 9 m/s in 0.5s = 18 m/s² > 12 m/s² for cycling)
	// Speed reaches 11.0 m/s = 39.6 km/h, well below 50.0 km/h cycling ceiling
	extremePoints := []geo.TrackPoint{
		{
			Latitude:  37.774900,
			Longitude: -122.4194,
			Timestamp: now,
			Speed:     2.0,
		},
		{
			Latitude:  37.774929, // ~3.2m displacement (avg speed 6.4 m/s = 23 km/h)
			Longitude: -122.4194,
			Timestamp: now.Add(500 * time.Millisecond),
			Speed:     11.0, // dv = 9.0 m/s in 0.5s = 18.0 m/s²
		},
	}
	extremeCyclingResult := detector.EvaluateTrackWithActivity(extremePoints, "cycling")
	assert.True(t, extremeCyclingResult.IsAnomaly)
	require.NotEmpty(t, extremeCyclingResult.Reasons)
	assert.Contains(t, extremeCyclingResult.Reasons[0], "Biomechanical acceleration limit exceeded")
}

func TestDetectorTableDriven(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	tests := []struct {
		name              string
		activityType      string
		declaredDuration  int
		declaredDistance  float64
		points            []geo.TrackPoint
		expectedAnomaly   bool
		expectedReasonSub string
		minScore          float64
		maxScore          float64
	}{
		{
			name:             "car sampled every 5s with speed=2",
			activityType:     "running",
			declaredDuration: 20,
			declaredDistance: 320.0,
			// Car moving at ~58 km/h (~16 m/s): ~80m per 5s segment, but client claims Speed=2.0 m/s
			points: []geo.TrackPoint{
				{Latitude: 37.77490, Longitude: -122.41940, Timestamp: now, Speed: 2.0},
				{Latitude: 37.77562, Longitude: -122.41940, Timestamp: now.Add(5 * time.Second), Speed: 2.0},
				{Latitude: 37.77634, Longitude: -122.41940, Timestamp: now.Add(10 * time.Second), Speed: 2.0},
				{Latitude: 37.77706, Longitude: -122.41940, Timestamp: now.Add(15 * time.Second), Speed: 2.0},
				{Latitude: 37.77778, Longitude: -122.41940, Timestamp: now.Add(20 * time.Second), Speed: 2.0},
			},
			expectedAnomaly:   true,
			expectedReasonSub: "endurance ceiling",
			minScore:          50.0,
			maxScore:          150.0,
		},
		{
			name:             "zero timestamps detected",
			activityType:     "running",
			declaredDuration: 40,
			declaredDistance: 100.0,
			// Points without timestamps
			points: []geo.TrackPoint{
				{Latitude: 37.77490, Longitude: -122.41940, Speed: 2.5},
				{Latitude: 37.77500, Longitude: -122.41940, Speed: 2.5},
				{Latitude: 37.77510, Longitude: -122.41940, Speed: 2.5},
			},
			expectedAnomaly:   true,
			expectedReasonSub: "Missing or zero GPS timestamp",
			minScore:          50.0,
			maxScore:          100.0,
		},
		{
			name:             "duration mismatch (>10% difference)",
			activityType:     "running",
			declaredDuration: 60, // declared 60s vs GPS span 6s
			declaredDistance: 15.6,
			points: []geo.TrackPoint{
				{Latitude: 37.77490, Longitude: -122.41940, Timestamp: now, Speed: 2.6},
				{Latitude: 37.77497, Longitude: -122.41940, Timestamp: now.Add(3 * time.Second), Speed: 2.6},
				{Latitude: 37.77504, Longitude: -122.41940, Timestamp: now.Add(6 * time.Second), Speed: 2.6},
			},
			expectedAnomaly:   true,
			expectedReasonSub: "Duration mismatch",
			minScore:          20.0,
			maxScore:          49.9, // Flagged review score (< 50)
		},
		{
			name:             "distance mismatch (>10% difference)",
			activityType:     "running",
			declaredDuration: 6,
			declaredDistance: 150.0, // declared 150m vs actual ~15.6m
			points: []geo.TrackPoint{
				{Latitude: 37.77490, Longitude: -122.41940, Timestamp: now, Speed: 2.6},
				{Latitude: 37.77497, Longitude: -122.41940, Timestamp: now.Add(3 * time.Second), Speed: 2.6},
				{Latitude: 37.77504, Longitude: -122.41940, Timestamp: now.Add(6 * time.Second), Speed: 2.6},
			},
			expectedAnomaly:   true,
			expectedReasonSub: "Distance mismatch",
			minScore:          20.0,
			maxScore:          49.9, // Flagged review score (< 50)
		},
		{
			name:             "sparse sampling detected (median dt > 5s)",
			activityType:     "running",
			declaredDuration: 24,
			declaredDistance: 60.0,
			// Sampled every 8s
			points: []geo.TrackPoint{
				{Latitude: 37.77490, Longitude: -122.41940, Timestamp: now, Speed: 2.5},
				{Latitude: 37.77505, Longitude: -122.41940, Timestamp: now.Add(8 * time.Second), Speed: 2.5},
				{Latitude: 37.77520, Longitude: -122.41940, Timestamp: now.Add(16 * time.Second), Speed: 2.5},
				{Latitude: 37.77535, Longitude: -122.41940, Timestamp: now.Add(24 * time.Second), Speed: 2.5},
			},
			expectedAnomaly:   true,
			expectedReasonSub: "Sparse GPS sampling detected",
			minScore:          50.0,
			maxScore:          100.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := detector.EvaluateTrackWithMetrics(tt.points, tt.activityType, tt.declaredDuration, tt.declaredDistance)
			assert.Equal(t, tt.expectedAnomaly, res.IsAnomaly)
			assert.GreaterOrEqual(t, res.Score, tt.minScore)
			if tt.maxScore > 0 {
				assert.LessOrEqual(t, res.Score, tt.maxScore)
			}
			foundReason := false
			for _, r := range res.Reasons {
				if strings.Contains(r, tt.expectedReasonSub) {
					foundReason = true
					break
				}
			}
			assert.True(t, foundReason, "Expected reason containing %q, got: %v", tt.expectedReasonSub, res.Reasons)
		})
	}
}

func TestCrossLanguageAnomalyParity(t *testing.T) {
	detector := anticheat.NewDetector()

	candidates := []string{
		filepath.Join("..", "..", "..", "test_fixtures", "anomaly_vectors.json"),
		filepath.Join("test_fixtures", "anomaly_vectors.json"),
		"c:/Users/AYUSH/Desktop/territory_runner/test_fixtures/anomaly_vectors.json",
	}
	var data []byte
	var err error
	for _, p := range candidates {
		data, err = os.ReadFile(p)
		if err == nil {
			break
		}
	}
	require.NoError(t, err, "failed to locate test_fixtures/anomaly_vectors.json")

	var fixture struct {
		ModelType string `json:"model_type"`
		TestCases []struct {
			Name          string     `json:"name"`
			Features      [5]float64 `json:"features"`
			ExpectedScore float64    `json:"expected_score"`
		} `json:"test_cases"`
	}
	require.NoError(t, json.Unmarshal(data, &fixture))
	assert.Equal(t, "WeightedZScoreDetector", fixture.ModelType)

	for _, tc := range fixture.TestCases {
		t.Run(tc.Name, func(t *testing.T) {
			actualScore := detector.ScoreFeatureVector(tc.Features)
			assert.InDelta(t, tc.ExpectedScore, actualScore, 1e-6, "Parity mismatch for vector %s", tc.Name)
		})
	}
}

func TestRegression_GenuineRunWithTwoStoppedSamplesNotFlagged(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 25-point trajectory at typical jogging speed (~9.7 km/h = 2.7 m/s)
	// Points 10 and 11 represent temporary stops (e.g. stopped at a pedestrian crossing)
	points := make([]geo.TrackPoint, 25)
	curLat := 37.77490
	curLng := -122.41940
	latStep := 0.000024 // ~2.7m displacement per second

	for i := 0; i < 25; i++ {
		ts := now.Add(time.Duration(i) * time.Second)
		if i == 10 || i == 11 {
			// Stopped sample: 0 speed, no coordinate progression
			points[i] = geo.TrackPoint{
				Latitude:  curLat,
				Longitude: curLng,
				Timestamp: ts,
				Speed:     0.0,
				Heading:   45.0,
			}
		} else {
			if i > 0 && i != 12 {
				curLat += latStep
			}
			points[i] = geo.TrackPoint{
				Latitude:  curLat,
				Longitude: curLng,
				Timestamp: ts,
				Speed:     2.7,
				Heading:   45.0,
			}
		}
	}

	result := detector.EvaluateTrack(points)
	assert.False(t, result.IsAnomaly, "A genuine 25-point run window containing 2 stopped samples must NOT be flagged")
	assert.Less(t, result.Score, detector.Config().AnomalyThreshold, "Score must remain strictly below calibrated threshold")
	assert.Empty(t, result.Reasons, "No anomaly reasons should be raised for genuine run with minor pauses")
}

func TestEvaluateTrackWithMotion_GenuineCadencePasses(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 35-point trajectory at ~9.7 km/h (~2.7 m/s)
	points := make([]geo.TrackPoint, 35)
	for i := 0; i < 35; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000017),
			Longitude: -122.4194 + (float64(i) * 0.000021),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.7,
			Heading:   45.0 + float64(i%3),
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}

	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        162.0,
			MotionEnergy:      1.45,
			CadenceConfidence: 0.88,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        165.0,
			MotionEnergy:      1.52,
			CadenceConfidence: 0.90,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        160.0,
			MotionEnergy:      1.38,
			CadenceConfidence: 0.85,
		},
	}

	result := detector.EvaluateTrackWithMotion(points, "running", 35, sumDist, windows)
	assert.False(t, result.IsAnomaly, "Genuine run with realistic cadence should pass, got reasons: %v", result.Reasons)
	assert.InDelta(t, 162.33, result.Features["cadence_spm"], 0.1)
	assert.InDelta(t, 1.45, result.Features["motion_energy"], 0.1)
	assert.InDelta(t, 0.87, result.Features["cadence_confidence"], 0.1)
}

func TestEvaluateTrackWithMotion_VehicleRunningSpoofFlagged(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 40-point trajectory at ~14.4 km/h (4.0 m/s) - plausible running speed on GPS,
	// but near-zero cadence and low motion energy for 40s (e.g. driving in car, riding scooter)
	points := make([]geo.TrackPoint, 40)
	for i := 0; i < 40; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000036),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     4.0,
			Heading:   0.0,
		}
	}

	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.04,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        10.0,
			MotionEnergy:      0.08,
			CadenceConfidence: 0.1,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.03,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(30 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        5.0,
			MotionEnergy:      0.06,
			CadenceConfidence: 0.05,
		},
	}

	result := detector.EvaluateTrackWithMotion(points, "running", 40, 160.0, windows)
	assert.True(t, result.IsAnomaly, "GPS speed > 6 km/h with near-zero cadence for > 30s must be flagged as vehicle")
	assert.GreaterOrEqual(t, result.Score, 75.0)

	foundVehicleReason := false
	for _, r := range result.Reasons {
		if strings.Contains(r, "Strong vehicle signal") {
			foundVehicleReason = true
			break
		}
	}
	assert.True(t, foundVehicleReason, "Expected vehicle reason in %v", result.Reasons)
}

func TestEvaluateTrackWithMotion_CyclingCoastingNotFlagged(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 40-point cycling trajectory at ~18 km/h (5.0 m/s)
	// Cyclist coasting downhill: cadence is 0, but road vibration motion energy is ~0.18 m^2/s^4
	points := make([]geo.TrackPoint, 40)
	for i := 0; i < 40; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000045),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     5.0,
			Heading:   0.0,
		}
	}

	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.18,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.22,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.16,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(30 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.19,
			CadenceConfidence: 0.0,
		},
	}

	result := detector.EvaluateTrackWithMotion(points, "cycling", 40, 200.0, windows)
	assert.False(t, result.IsAnomaly, "Cycling coasting (0 cadence with bicycle vibration) must NOT be flagged as vehicle")
}

func TestEvaluateTrackWithMotion_CyclingHighwayVehicleFlagged(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 70-point trajectory at ~36 km/h (10.0 m/s) declared as cycling
	// Smooth highway car driving: 0 cadence and almost zero road vibration (< 0.05) sustained > 60s
	points := make([]geo.TrackPoint, 70)
	for i := 0; i < 70; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.00009),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     10.0,
			Heading:   0.0,
		}
	}

	windows := make([]anticheat.MotionWindow, 7)
	for i := 0; i < 7; i++ {
		windows[i] = anticheat.MotionWindow{
			StartTime:         now.Add(time.Duration(i*10) * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.02,
			CadenceConfidence: 0.0,
		}
	}

	result := detector.EvaluateTrackWithMotion(points, "cycling", 70, 700.0, windows)
	assert.True(t, result.IsAnomaly, "Vehicle driving declared as cycling must be flagged after sustained stillness at high speed")
	assert.GreaterOrEqual(t, result.Score, 75.0)

	foundVehicleReason := false
	for _, r := range result.Reasons {
		if strings.Contains(r, "Strong vehicle signal in cycling mode") {
			foundVehicleReason = true
			break
		}
	}
	assert.True(t, foundVehicleReason, "Expected cycling vehicle reason in %v", result.Reasons)
}

func TestEvaluateTrackWithMotion_NilWindowsBackwardCompatibility(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := make([]geo.TrackPoint, 10)
	for i := 0; i < 10; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.00003),
			Longitude: -122.4194 + (float64(i) * 0.00003),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.7,
			Heading:   45.0,
		}
	}

	result1 := detector.EvaluateTrackWithMetrics(points, "running", 10, 30.0)
	result2 := detector.EvaluateTrackWithMotion(points, "running", 10, 30.0, nil)

	assert.Equal(t, result1.IsAnomaly, result2.IsAnomaly)
	assert.Equal(t, result1.Score, result2.Score)
	assert.Equal(t, result1.Reasons, result2.Reasons)
}

func TestMLEnsemble_CryptographicIntegrityCheck(t *testing.T) {
	ensemble, err := anticheat.NewDefaultMLEnsemble()
	require.NoError(t, err, "MLEnsemble must verify SHA256 and ModelVersion")
	require.NotNil(t, ensemble)
	assert.True(t, ensemble.IsVerified())
	assert.Equal(t, "3.0.0", ensemble.Metadata().ModelVersion)
	assert.NotEmpty(t, ensemble.SHA256())
	assert.Equal(t, ensemble.Metadata().SHA256Trees, ensemble.SHA256())
}

func TestCrossLanguageParity_200FixedWindows_GoVsPython(t *testing.T) {
	ensemble, err := anticheat.NewDefaultMLEnsemble()
	require.NoError(t, err)

	var data []byte
	candidates := []string{
		"../../../test_fixtures/parity_200_windows.json",
		"../../test_fixtures/parity_200_windows.json",
		"../test_fixtures/parity_200_windows.json",
		"test_fixtures/parity_200_windows.json",
	}
	for _, p := range candidates {
		if abs, err := filepath.Abs(p); err == nil {
			if b, err := os.ReadFile(abs); err == nil {
				data = b
				break
			}
		}
	}
	require.NotEmpty(t, data, "test_fixtures/parity_200_windows.json must exist")

	var fixture struct {
		ModelVersion string `json:"model_version"`
		SHA256       string `json:"sha256"`
		TotalWindows int    `json:"total_windows"`
		TestCases    []struct {
			ID                  string    `json:"id"`
			Features            []float64 `json:"features"`
			ExpectedProbability float64   `json:"expected_probability"`
			ExpectedIsAnomaly   bool      `json:"expected_is_anomaly"`
		} `json:"test_cases"`
	}
	require.NoError(t, json.Unmarshal(data, &fixture))
	assert.Equal(t, 200, len(fixture.TestCases), "Expected 200 parity test cases")
	assert.Equal(t, "3.0.0", fixture.ModelVersion)

	start := time.Now()
	var maxDiff float64
	mismatchDecisions := 0

	for _, tc := range fixture.TestCases {
		actualProb := ensemble.PredictProbability(tc.Features)
		diff := math.Abs(actualProb - tc.ExpectedProbability)
		if diff > maxDiff {
			maxDiff = diff
		}
		assert.InDelta(t, tc.ExpectedProbability, actualProb, 1e-4, "Window %s parity mismatch", tc.ID)
		actualAnomaly := actualProb >= 0.50
		if actualAnomaly != tc.ExpectedIsAnomaly {
			mismatchDecisions++
		}
	}
	elapsed := time.Since(start)
	avgLatencyUs := float64(elapsed.Microseconds()) / float64(len(fixture.TestCases))

	t.Logf("Go vs Python Parity: Max Diff = %.2e, Decision Mismatches = %d / %d, Avg Latency = %.3f us/window",
		maxDiff, mismatchDecisions, len(fixture.TestCases), avgLatencyUs)
	assert.Equal(t, 0, mismatchDecisions, "Zero decision mismatches across all 200 parity windows")
	assert.Less(t, maxDiff, 1e-4, "Max floating-point deviation must be strictly < 1e-4")
}

func TestFeatureFlag_FallbackToRulesOnly(t *testing.T) {
	// Configure detector with EnableMLTier2 = false
	cfg := anticheat.DefaultConfig()
	cfg.EnableMLTier2 = false
	detector := anticheat.NewDetector(cfg)
	assert.False(t, detector.Config().EnableMLTier2, "ML Tier 2 should be disabled")

	now := time.Now().UTC()
	// Trajectory where Tier 1 passes (speed within normal range) but ML would be queried
	points := make([]geo.TrackPoint, 15)
	for i := 0; i < 15; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000015),
			Longitude: -122.4194 + (float64(i) * 0.000018),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.5,
			Heading:   45.0,
		}
	}

	res := detector.EvaluateTrackWithMotion(points, "running", 15, 35.0, nil)
	assert.False(t, res.IsAnomaly)
	assert.NotContains(t, res.Features, "ml_anomaly_prob", "ML Tier 2 feature should not be populated when feature-flagged off")
}

func TestSanityCheckMotionWindows_Valid(t *testing.T) {
	now := time.Now().UTC()
	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        162.0,
			MotionEnergy:      1.42,
			CadenceConfidence: 0.88,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        165.5,
			MotionEnergy:      1.48,
			CadenceConfidence: 0.91,
		},
	}

	report := anticheat.SanityCheckMotionWindows(windows, 20.0)
	assert.True(t, report.Valid)
	assert.Empty(t, report.Issues)
	assert.Equal(t, 2, report.WindowCount)
	assert.Equal(t, 20.0, report.TotalDurationSec)
}

func TestSanityCheckMotionWindows_DurationInflation(t *testing.T) {
	now := time.Now().UTC()
	// 5 windows of 10s = 50s total motion duration for a 15s run (300% inflation)
	windows := make([]anticheat.MotionWindow, 5)
	for i := 0; i < 5; i++ {
		windows[i] = anticheat.MotionWindow{
			StartTime:         now.Add(time.Duration(i*10) * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        160.0 + float64(i),
			MotionEnergy:      1.2 + float64(i)*0.1,
			CadenceConfidence: 0.85,
		}
	}

	report := anticheat.SanityCheckMotionWindows(windows, 15.0)
	assert.False(t, report.Valid)
	assert.NotEmpty(t, report.Issues)
	assert.Contains(t, report.Issues[0], "exceeds run duration")
}

func TestSanityCheckMotionWindows_ImpossibleBounds(t *testing.T) {
	now := time.Now().UTC()
	// Test cadence > 300 SPM, negative energy, confidence > 1
	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        350.0, // impossible
			MotionEnergy:      -2.0,  // impossible
			CadenceConfidence: 1.5,   // out of [0, 1]
		},
	}

	report := anticheat.SanityCheckMotionWindows(windows, 10.0)
	assert.False(t, report.Valid)
	assert.GreaterOrEqual(t, len(report.Issues), 3)
}

func TestSanityCheckMotionWindows_BotIdenticalValues(t *testing.T) {
	now := time.Now().UTC()
	// 6 windows with bit-for-bit identical cadence and energy
	windows := make([]anticheat.MotionWindow, 6)
	for i := 0; i < 6; i++ {
		windows[i] = anticheat.MotionWindow{
			StartTime:         now.Add(time.Duration(i*10) * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        165.000000,
			MotionEnergy:      1.450000,
			CadenceConfidence: 0.90,
		}
	}

	report := anticheat.SanityCheckMotionWindows(windows, 60.0)
	assert.False(t, report.Valid)
	assert.NotEmpty(t, report.Issues)
	assert.Contains(t, report.Issues[0], "bot/synthetic injector signature")
}

func TestEvaluateTrackWithMotion_MissingWindowsTreatedAsUnverifiedMotion(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// 20-point genuine run trajectory at ~10 km/h (2.8 m/s)
	points := make([]geo.TrackPoint, 20)
	for i := 0; i < 20; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000025),
			Longitude: -122.4194 + (float64(i) * 0.000025),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.8,
			Heading:   45.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	// Submit WITHOUT motion windows (nil)
	res := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, nil)

	// Physical rules must pass
	assert.False(t, res.IsAnomaly)
	assert.Less(t, res.Score, detector.Config().AnomalyThreshold)

	// MUST be treated as unverified_motion, NEVER as verified_human
	assert.Equal(t, anticheat.VerificationStatusUnverifiedMotion, res.VerificationStatus,
		"Runs without motion windows must be treated as unverified_motion, never as verified_human")
	assert.Equal(t, 0.0, res.Features["has_motion_windows"])
	assert.Equal(t, 0.0, res.Features["motion_sanity_valid"])
}

func TestEvaluateTrackWithMotion_ImplausibleMotionDowngradedToUnverifiedMotion(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := make([]geo.TrackPoint, 20)
	for i := 0; i < 20; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000025),
			Longitude: -122.4194 + (float64(i) * 0.000025),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.8,
			Heading:   45.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	// Client sends implausible motion window (cadence 400 SPM)
	badWindows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        400.0,
			MotionEnergy:      1.4,
			CadenceConfidence: 0.85,
		},
	}

	res := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, badWindows)

	// Kinematics pass physical rules, but motion was flagged
	assert.False(t, res.IsAnomaly)
	assert.Equal(t, anticheat.VerificationStatusUnverifiedMotion, res.VerificationStatus)
	assert.Equal(t, 0.0, res.Features["motion_sanity_valid"])

	foundSanityIssue := false
	for _, r := range res.Reasons {
		if strings.Contains(r, "Implausible motion telemetry") {
			foundSanityIssue = true
			break
		}
	}
	assert.True(t, foundSanityIssue, "Expected sanity issue reason in %v", res.Reasons)
}

func TestEvaluateTrackWithMotion_ValidMotionProducesVerifiedHuman(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	points := make([]geo.TrackPoint, 20)
	for i := 0; i < 20; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000025),
			Longitude: -122.4194 + (float64(i) * 0.000025),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.8,
			Heading:   45.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	validWindows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        164.0,
			MotionEnergy:      1.42,
			CadenceConfidence: 0.89,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        167.5,
			MotionEnergy:      1.46,
			CadenceConfidence: 0.92,
		},
	}

	res := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, validWindows)

	assert.False(t, res.IsAnomaly)
	assert.Equal(t, anticheat.VerificationStatusVerifiedHuman, res.VerificationStatus,
		"Run with physical GPS and valid human cadence should be marked verified_human")
	assert.Equal(t, 1.0, res.Features["motion_sanity_valid"])
}

func TestMLEnsemble_ChecksumFailureFallback_LogsOnceAndUsesRules(t *testing.T) {
	// 1. Verify NewMLEnsembleFromBytes rejects corrupted metadata or mismatched SHA256
	corruptedMeta := []byte(`{"model_name":"lgbm","sha256_trees":"badhash123","model_version":"3.0.0"}`)
	dummyTrees := []byte(`{"model_version":"3.0.0","trees":[]}`)
	_, err := anticheat.NewMLEnsembleFromBytes(corruptedMeta, dummyTrees)
	assert.Error(t, err)
	assert.ErrorIs(t, err, anticheat.ErrModelIntegrityFailed)

	// 2. Verify that when ML ensemble is nil (fallback mode), detector evaluates rules without crashing
	detector := anticheat.NewDetectorWithEnsemble(nil)
	assert.Nil(t, detector.MLEnsemble())

	now := time.Now().UTC()
	points := make([]geo.TrackPoint, 15)
	for i := 0; i < 15; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000015),
			Longitude: -122.4194 + (float64(i) * 0.000018),
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.5,
			Heading:   45.0,
		}
	}
	res := detector.EvaluateTrackWithMotion(points, "running", 15, 35.0, nil)
	assert.False(t, res.IsAnomaly)
	assert.Equal(t, anticheat.VerificationStatusUnverifiedMotion, res.VerificationStatus)
	assert.NotContains(t, res.Features, "ml_anomaly_prob", "Nil ML ensemble should not populate ml_anomaly_prob")
}

func TestEdgeCase_LowSpeedWalker(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Walker moving at 3.2 km/h (~0.89 m/s) over 30 seconds
	points := make([]geo.TrackPoint, 30)
	for i := 0; i < 30; i++ {
		// ~0.89m per second displacement (0.000008 deg lat ~ 0.89m)
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000008),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     0.89,
			Heading:   0.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	// Legitimate walking cadence: 104 SPM, moderate energy
	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        102.0,
			MotionEnergy:      0.85,
			CadenceConfidence: 0.82,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        104.0,
			MotionEnergy:      0.88,
			CadenceConfidence: 0.85,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        106.0,
			MotionEnergy:      0.84,
			CadenceConfidence: 0.83,
		},
	}

	res := detector.EvaluateTrackWithMotion(points, "walking", durSec, sumDist, windows)
	assert.False(t, res.IsAnomaly, "Legitimate low-speed walker must not be flagged as anomaly")
	assert.Equal(t, anticheat.VerificationStatusVerifiedHuman, res.VerificationStatus)
	assert.Less(t, res.Score, detector.Config().AnomalyThreshold)
}

func TestEdgeCase_LowSpeedRunner(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Slow jogger at 6.8 km/h (~1.89 m/s) over 30 seconds
	points := make([]geo.TrackPoint, 30)
	for i := 0; i < 30; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000017),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     1.89,
			Heading:   0.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	// Running cadence: 145 SPM, energy: 2.1
	windows := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        144.0,
			MotionEnergy:      2.1,
			CadenceConfidence: 0.88,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        146.0,
			MotionEnergy:      2.2,
			CadenceConfidence: 0.90,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        145.0,
			MotionEnergy:      2.0,
			CadenceConfidence: 0.89,
		},
	}

	res := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, windows)
	assert.False(t, res.IsAnomaly, "Legitimate slow jogger must not be flagged as anomaly")
	assert.Equal(t, anticheat.VerificationStatusVerifiedHuman, res.VerificationStatus)
}

func TestEdgeCase_PhoneInBag_Running(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Runner at 10.0 km/h (~2.78 m/s) over 30 seconds
	points := make([]geo.TrackPoint, 30)
	for i := 0; i < 30; i++ {
		points[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000025),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.78,
			Heading:   0.0,
		}
	}

	var sumDist float64
	for i := 1; i < len(points); i++ {
		sumDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
	}
	durSec := int(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())

	// Sub-case A: Phone in backpack bouncing with motion energy (0.85 m^2/s^4) but step detector
	// fails to register distinct step peaks (Cadence = 0 SPM, confidence = 0.0).
	// Because MotionEnergy >= 0.25, the vehicle stillness heuristic is NOT triggered.
	windowsBagBounce := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.85,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.90,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.82,
			CadenceConfidence: 0.0,
		},
	}

	resA := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, windowsBagBounce)
	assert.False(t, resA.IsAnomaly, "Phone bouncing in backpack with energy >= 0.25 must NOT trigger vehicle stillness flag")
	assert.Equal(t, anticheat.VerificationStatusVerifiedHuman, resA.VerificationStatus)

	// Sub-case B: Phone in bag with no motion windows at all (nil)
	resB := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, nil)
	assert.False(t, resB.IsAnomaly, "Phone without motion windows must pass physical GPS rules")
	assert.Equal(t, anticheat.VerificationStatusUnverifiedMotion, resB.VerificationStatus,
		"Phone without motion windows must be marked unverified_motion")

	// Sub-case C: Phone cushioned so heavily in bag that MotionEnergy < 0.25 at 10 km/h for >30s.
	// This is a known false positive edge case: it triggers the vehicle stillness rule.
	windowsCushioned := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.10, // damped
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.12,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.09,
			CadenceConfidence: 0.0,
		},
	}
	resC := detector.EvaluateTrackWithMotion(points, "running", durSec, sumDist, windowsCushioned)
	assert.True(t, resC.IsAnomaly, "Heavily cushioned phone at 10 km/h with energy < 0.25 triggers vehicle stillness rule (known FP boundary)")
	assert.Equal(t, anticheat.VerificationStatusRejected, resC.VerificationStatus)
	assert.Contains(t, resC.Reasons[0], "Strong vehicle signal")
}

func TestEdgeCase_StrollerOrCart(t *testing.T) {
	detector := anticheat.NewDetector()
	now := time.Now().UTC()

	// Sub-case A: Normal walking pushing stroller at 4.5 km/h (~1.25 m/s) over 30 seconds.
	// Phone rests in stroller tray (Cadence = 0 SPM, Energy = 0.08 m^2/s^4).
	// Because GPS speed is <= 6.0 km/h, the vehicle stillness rule does NOT trigger.
	pointsStrollerWalk := make([]geo.TrackPoint, 30)
	for i := 0; i < 30; i++ {
		pointsStrollerWalk[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000011),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     1.25, // 4.5 km/h
			Heading:   0.0,
		}
	}

	var distWalk float64
	for i := 1; i < len(pointsStrollerWalk); i++ {
		distWalk += geo.HaversineDistanceMeters(pointsStrollerWalk[i-1].ToLatLng(), pointsStrollerWalk[i].ToLatLng())
	}
	durWalk := int(pointsStrollerWalk[len(pointsStrollerWalk)-1].Timestamp.Sub(pointsStrollerWalk[0].Timestamp).Seconds())

	windowsStroller := []anticheat.MotionWindow{
		{
			StartTime:         now,
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.08,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(10 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.07,
			CadenceConfidence: 0.0,
		},
		{
			StartTime:         now.Add(20 * time.Second),
			DurationSeconds:   10.0,
			CadenceSPM:        0.0,
			MotionEnergy:      0.09,
			CadenceConfidence: 0.0,
		},
	}

	resWalk := detector.EvaluateTrackWithMotion(pointsStrollerWalk, "walking", durWalk, distWalk, windowsStroller)
	assert.False(t, resWalk.IsAnomaly, "Pushing stroller at walking speed (4.5 km/h <= 6.0 km/h) must NOT trigger vehicle detection")
	assert.Equal(t, anticheat.VerificationStatusVerifiedHuman, resWalk.VerificationStatus)

	// Sub-case B: Jogging with stroller at 7.5 km/h (~2.08 m/s) on smooth surface with phone in cup holder
	// (GPS speed > 6.0 km/h, Cadence = 0 SPM, Energy < 0.25).
	// This triggers the vehicle heuristic after 30s.
	pointsStrollerJog := make([]geo.TrackPoint, 30)
	for i := 0; i < 30; i++ {
		pointsStrollerJog[i] = geo.TrackPoint{
			Latitude:  37.7749 + (float64(i) * 0.000019),
			Longitude: -122.4194,
			Timestamp: now.Add(time.Duration(i) * time.Second),
			Speed:     2.08, // 7.5 km/h
			Heading:   0.0,
		}
	}
	var distJog float64
	for i := 1; i < len(pointsStrollerJog); i++ {
		distJog += geo.HaversineDistanceMeters(pointsStrollerJog[i-1].ToLatLng(), pointsStrollerJog[i].ToLatLng())
	}
	durJog := int(pointsStrollerJog[len(pointsStrollerJog)-1].Timestamp.Sub(pointsStrollerJog[0].Timestamp).Seconds())

	resJog := detector.EvaluateTrackWithMotion(pointsStrollerJog, "running", durJog, distJog, windowsStroller)
	assert.True(t, resJog.IsAnomaly, "Jogging with stroller at 7.5 km/h with zero cadence and low vibration triggers vehicle rule (>6 km/h boundary)")
	assert.Equal(t, anticheat.VerificationStatusRejected, resJog.VerificationStatus)
	assert.Contains(t, resJog.Reasons[0], "Strong vehicle signal")
}
