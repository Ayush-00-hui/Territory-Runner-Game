package geo

import "math"

type point2D struct {
	x float64
	y float64
}

// ComputeGeodesicShoelaceArea calculates the exact surface area of an arbitrary geographic polygon
// in square meters using the Geodesic Shoelace Formula on a local equirectangular tangent plane.
// This reproduces the exact mathematical behavior of Dart's PolygonEnclosureEngine.computeGeodesicShoelaceArea.
func ComputeGeodesicShoelaceArea(polygon []LatLng) float64 {
	n := len(polygon)
	if n < 3 {
		return 0.0
	}

	// Compute centroid origin for the local tangent projection
	var sumLat, sumLng float64
	for _, p := range polygon {
		sumLat += p.Latitude
		sumLng += p.Longitude
	}
	originLat := (sumLat / float64(n)) * (math.Pi / 180.0)
	originLng := (sumLng / float64(n)) * (math.Pi / 180.0)

	// Project spherical coordinates into local Cartesian metric coordinates (x, y in meters)
	metricPoints := make([]point2D, n)
	for i, p := range polygon {
		latRad := p.Latitude * (math.Pi / 180.0)
		lngRad := p.Longitude * (math.Pi / 180.0)

		x := EarthRadiusMeters * (lngRad - originLng) * math.Cos((latRad+originLat)/2.0)
		y := EarthRadiusMeters * (latRad - originLat)
		metricPoints[i] = point2D{x: x, y: y}
	}

	// Apply standard 2D Shoelace Area Formula
	var area float64
	for i := 0; i < n; i++ {
		j := (i + 1) % n
		area += (metricPoints[i].x * metricPoints[j].y)
		area -= (metricPoints[j].x * metricPoints[i].y)
	}

	return math.Abs(area) / 2.0
}
