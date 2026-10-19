package geo_test

import (
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEncodeGeohash(t *testing.T) {
	// San Francisco: 37.7749, -122.4194 -> starts with "9q8yy"
	hash := geo.GeohashPrecision6(37.7749, -122.4194)
	require.Equal(t, 6, len(hash))
	assert.True(t, hash[:5] == "9q8yy", "expected prefix 9q8yy, got %s", hash)

	// Neighbors should return 8 distinct cells
	neighbors := geo.GeohashNeighbors(hash)
	assert.Equal(t, 8, len(neighbors))
	for _, n := range neighbors {
		assert.Equal(t, 6, len(n))
		assert.NotEqual(t, hash, n)
	}
}

func TestSnapToGrid(t *testing.T) {
	lat, lng := 37.77491234, -122.41941234
	snappedLat, snappedLng := geo.SnapToGrid(lat, lng, 25.0)

	// Difference between original and snapped should be within 25m (~0.00025 deg)
	p1 := geo.LatLng{Latitude: lat, Longitude: lng}
	p2 := geo.LatLng{Latitude: snappedLat, Longitude: snappedLng}
	dist := geo.HaversineDistanceMeters(p1, p2)

	assert.True(t, dist <= 25.0, "snapped distance %f should be <= 25m", dist)

	// Two nearby points within same ~25m box should snap to the exact same coordinates
	lat2, lng2 := 37.77491300, -122.41941250
	snappedLat2, snappedLng2 := geo.SnapToGrid(lat2, lng2, 25.0)
	assert.Equal(t, snappedLat, snappedLat2)
	assert.Equal(t, snappedLng, snappedLng2)
}
