package geo_test

import (
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

func TestIsPointInZone_InsideEdgeAndOutside(t *testing.T) {
	// Center point: San Francisco Ferry Building (37.7955, -122.3937)
	centerLat := 37.7955
	centerLng := -122.3937
	radius := 200.0 // 200 meters

	// 1. Center is definitely inside (distance = 0)
	if !geo.IsPointInZone(centerLat, centerLng, centerLat, centerLng, radius) {
		t.Fatalf("expected center point to be inside zone")
	}

	// 2. Point ~100m away (inside)
	// At lat 37.7955, 1 deg lat ~ 111,000m -> 100m ~ 0.0009 deg
	insideLat := centerLat + 0.0008
	insideLng := centerLng
	dInside := geo.HaversineDistanceMeters(geo.LatLng{Latitude: insideLat, Longitude: insideLng}, geo.LatLng{Latitude: centerLat, Longitude: centerLng})
	if dInside > radius {
		t.Fatalf("test setup error: dInside=%.2f > radius=%.2f", dInside, radius)
	}
	if !geo.IsPointInZone(insideLat, insideLng, centerLat, centerLng, radius) {
		t.Fatalf("expected point at %.1fm to be inside zone (radius %.1fm)", dInside, radius)
	}

	// 3. Point strictly outside (e.g. 500m away)
	outsideLat := centerLat + 0.005
	outsideLng := centerLng
	dOutside := geo.HaversineDistanceMeters(geo.LatLng{Latitude: outsideLat, Longitude: outsideLng}, geo.LatLng{Latitude: centerLat, Longitude: centerLng})
	if dOutside <= radius {
		t.Fatalf("test setup error: dOutside=%.2f <= radius=%.2f", dOutside, radius)
	}
	if geo.IsPointInZone(outsideLat, outsideLng, centerLat, centerLng, radius) {
		t.Fatalf("expected point at %.1fm to be outside zone (radius %.1fm)", dOutside, radius)
	}
}

func TestIsPointInAnyZone_HonorsEnabledFlag(t *testing.T) {
	centerLat := 37.7955
	centerLng := -122.3937

	disabledZone := geo.PrivacyZoneEvaluator{
		Latitude:     centerLat,
		Longitude:    centerLng,
		RadiusMeters: 300.0,
		IsEnabled:    false,
	}

	// Should not be inside since zone is disabled
	if geo.IsPointInAnyZone(centerLat, centerLng, []geo.PrivacyZoneEvaluator{disabledZone}) {
		t.Fatalf("expected disabled zone to not match point")
	}

	enabledZone := disabledZone
	enabledZone.IsEnabled = true
	if !geo.IsPointInAnyZone(centerLat, centerLng, []geo.PrivacyZoneEvaluator{enabledZone}) {
		t.Fatalf("expected enabled zone to match point")
	}
}

func TestMaskPath_TrimsStartAndEndInsidePrivacyZone(t *testing.T) {
	// Zone at (37.7955, -122.3937) with radius 200m
	zone := geo.PrivacyZoneEvaluator{
		Latitude:     37.7955,
		Longitude:    -122.3937,
		RadiusMeters: 200.0,
		IsEnabled:    true,
	}

	// Create a run track:
	// Point 0: at Home (inside zone)
	// Point 1: 50m from Home (inside zone)
	// Point 2: 500m from Home (outside zone)
	// Point 3: 800m from Home (outside zone)
	// Point 4: returning to 80m from Home (inside zone)
	track := []geo.LatLng{
		{Latitude: 37.7955, Longitude: -122.3937}, // inside
		{Latitude: 37.7958, Longitude: -122.3937}, // ~33m away, inside
		{Latitude: 37.8010, Longitude: -122.3937}, // ~610m away, outside
		{Latitude: 37.8030, Longitude: -122.3937}, // ~830m away, outside
		{Latitude: 37.7956, Longitude: -122.3937}, // ~11m away, inside
	}

	masked := geo.MaskPath(track, []geo.PrivacyZoneEvaluator{zone})

	// Exactly points 2 and 3 should remain; points 0, 1, 4 should be stripped
	if len(masked) != 2 {
		t.Fatalf("expected 2 points after masking, got %d", len(masked))
	}
	if masked[0].Latitude != 37.8010 || masked[1].Latitude != 37.8030 {
		t.Fatalf("unexpected masked points: %+v", masked)
	}
}
