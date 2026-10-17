package geo

// PrivacyZoneEvaluator defines the minimal attributes needed to check coordinate exclusion.
type PrivacyZoneEvaluator struct {
	Latitude     float64
	Longitude    float64
	RadiusMeters float64
	IsEnabled    bool
}

// IsPointInZone checks if a coordinate falls strictly within or at the edge of the privacy radius (distance <= radiusMeters).
func IsPointInZone(lat, lng, zoneLat, zoneLng, radiusMeters float64) bool {
	p1 := LatLng{Latitude: lat, Longitude: lng}
	p2 := LatLng{Latitude: zoneLat, Longitude: zoneLng}
	d := HaversineDistanceMeters(p1, p2)
	return d <= radiusMeters
}

// IsPointInAnyZone checks if a coordinate lies within any active (enabled) privacy zone.
func IsPointInAnyZone(lat, lng float64, zones []PrivacyZoneEvaluator) bool {
	for _, z := range zones {
		if !z.IsEnabled {
			continue
		}
		if IsPointInZone(lat, lng, z.Latitude, z.Longitude, z.RadiusMeters) {
			return true
		}
	}
	return false
}

// MaskPath redacts points that fall inside any active privacy zone.
// This ensures that the first/last parts of any path touching sensitive areas
// (home, office, school) are never exposed to rivals, duels, or public views.
func MaskPath(points []LatLng, zones []PrivacyZoneEvaluator) []LatLng {
	if len(points) == 0 || len(zones) == 0 {
		return points
	}
	var hasEnabled bool
	for _, z := range zones {
		if z.IsEnabled {
			hasEnabled = true
			break
		}
	}
	if !hasEnabled {
		return points
	}

	result := make([]LatLng, 0, len(points))
	for _, pt := range points {
		if !IsPointInAnyZone(pt.Latitude, pt.Longitude, zones) {
			result = append(result, pt)
		}
	}
	return result
}
