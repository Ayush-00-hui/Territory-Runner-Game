package anticheat_test

import (
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
