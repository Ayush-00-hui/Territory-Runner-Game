package geo

import "math"

// EarthRadiusMeters is the standard mean WGS84 earth equatorial radius in meters.
const EarthRadiusMeters = 6378137.0

// HaversineDistanceMeters calculates high-precision geodesic distance between two points on the WGS84 sphere.
func HaversineDistanceMeters(p1, p2 LatLng) float64 {
	dLat := (p2.Latitude - p1.Latitude) * (math.Pi / 180.0)
	dLng := (p2.Longitude - p1.Longitude) * (math.Pi / 180.0)
	lat1 := p1.Latitude * (math.Pi / 180.0)
	lat2 := p2.Latitude * (math.Pi / 180.0)

	a := math.Sin(dLat/2.0)*math.Sin(dLat/2.0) +
		math.Sin(dLng/2.0)*math.Sin(dLng/2.0)*math.Cos(lat1)*math.Cos(lat2)
	c := 2.0 * math.Atan2(math.Sqrt(a), math.Sqrt(1.0-a))
	return EarthRadiusMeters * c
}

// CalculatePathDistanceMeters calculates total linear distance along a sequence of GPS coordinates.
func CalculatePathDistanceMeters(points []LatLng) float64 {
	var total float64
	for i := 0; i < len(points)-1; i++ {
		total += HaversineDistanceMeters(points[i], points[i+1])
	}
	return total
}
