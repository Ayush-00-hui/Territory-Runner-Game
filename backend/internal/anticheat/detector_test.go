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
