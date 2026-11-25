package geo

import (
	"math"
)

// PointInPolygon tests if a point lies strictly inside or on the boundary of a polygon using ray casting.
func PointInPolygon(pt LatLng, polygon []LatLng) bool {
	n := len(polygon)
	if n < 3 {
		return false
	}
	inside := false
	j := n - 1
	for i := 0; i < n; i++ {
		xi, yi := polygon[i].Longitude, polygon[i].Latitude
		xj, yj := polygon[j].Longitude, polygon[j].Latitude

		intersect := ((yi > pt.Latitude) != (yj > pt.Latitude)) &&
			(pt.Longitude < (xj-xi)*(pt.Latitude-yi)/(yj-yi)+xi)
		if intersect {
			inside = !inside
		}
		j = i
	}
	return inside
}

// ComputePolygonBoundingBox computes the min/max latitude and longitude of a polygon.
func ComputePolygonBoundingBox(polygon []LatLng) (minLat, minLng, maxLat, maxLng float64) {
	if len(polygon) == 0 {
		return 0, 0, 0, 0
	}
	minLat, maxLat = polygon[0].Latitude, polygon[0].Latitude
	minLng, maxLng = polygon[0].Longitude, polygon[0].Longitude
	for _, p := range polygon[1:] {
		if p.Latitude < minLat {
			minLat = p.Latitude
		}
		if p.Latitude > maxLat {
			maxLat = p.Latitude
		}
		if p.Longitude < minLng {
			minLng = p.Longitude
		}
		if p.Longitude > maxLng {
			maxLng = p.Longitude
		}
	}
	return minLat, minLng, maxLat, maxLng
}

// BBoxesIntersect returns true if two bounding boxes overlap.
func BBoxesIntersect(minLatA, minLngA, maxLatA, maxLngA, minLatB, minLngB, maxLatB, maxLngB float64) bool {
	return !(maxLatA < minLatB || minLatA > maxLatB || maxLngA < minLngB || minLngA > maxLngB)
}

// PolygonsIntersect returns true if two polygons have overlapping surface area or boundaries.
func PolygonsIntersect(polyA, polyB []LatLng) bool {
	minLatA, minLngA, maxLatA, maxLngA := ComputePolygonBoundingBox(polyA)
	minLatB, minLngB, maxLatB, maxLngB := ComputePolygonBoundingBox(polyB)
	if !BBoxesIntersect(minLatA, minLngA, maxLatA, maxLngA, minLatB, minLngB, maxLatB, maxLngB) {
		return false
	}

	// 1. Check if any edge of A intersects any edge of B
	for i := 0; i < len(polyA)-1; i++ {
		for j := 0; j < len(polyB)-1; j++ {
			if DoSegmentsIntersect(polyA[i], polyA[i+1], polyB[j], polyB[j+1]) {
				return true
			}
		}
	}

	// 2. Check if polyA is completely inside polyB
	if PointInPolygon(polyA[0], polyB) {
		return true
	}

	// 3. Check if polyB is completely inside polyA
	if PointInPolygon(polyB[0], polyA) {
		return true
	}

	return false
}

// clipEdge clips a polygon against a directed line edge (p1 -> p2).
func clipEdge(polygon []LatLng, cp1, cp2 LatLng) []LatLng {
	if len(polygon) == 0 {
		return nil
	}
	var output []LatLng
	s := polygon[len(polygon)-1]

	isInside := func(p LatLng) bool {
		// Point is inside if it is to the left of the directed line cp1 -> cp2
		return (cp2.Longitude-cp1.Longitude)*(p.Latitude-cp1.Latitude)-(cp2.Latitude-cp1.Latitude)*(p.Longitude-cp1.Longitude) >= -1e-12
	}

	computeInt := func(s, e LatLng) LatLng {
		dcx, dcy := cp1.Longitude-cp2.Longitude, cp1.Latitude-cp2.Latitude
		dpx, dpy := s.Longitude-e.Longitude, s.Latitude-e.Latitude
		n1 := cp1.Longitude*cp2.Latitude - cp1.Latitude*cp2.Longitude
		n2 := s.Longitude*e.Latitude - s.Latitude*e.Longitude
		denom := dcx*dpy - dcy*dpx
		if math.Abs(denom) < 1e-18 {
			return s
		}
		x := (n1*dpx - n2*dcx) / denom
		y := (n1*dpy - n2*dcy) / denom
		return LatLng{Latitude: y, Longitude: x}
	}

	for _, e := range polygon {
		if isInside(e) {
			if isInside(s) {
				output = append(output, e)
			} else {
				output = append(output, computeInt(s, e), e)
			}
		} else if isInside(s) {
			output = append(output, computeInt(s, e))
		}
		s = e
	}
	return output
}

// SutherlandHodgmanClip clips a subject polygon against a convex clip polygon.
func SutherlandHodgmanClip(subject []LatLng, clip []LatLng) []LatLng {
	output := make([]LatLng, len(subject))
	copy(output, subject)

	nClip := len(clip)
	for i := 0; i < nClip; i++ {
		j := (i + 1) % nClip
		output = clipEdge(output, clip[i], clip[j])
		if len(output) < 3 {
			return nil
		}
	}
	return output
}

// PolygonIntersectionArea computes the overlapping area between two polygons in square meters.
func PolygonIntersectionArea(polyA, polyB []LatLng) float64 {
	if !PolygonsIntersect(polyA, polyB) {
		return 0.0
	}

	areaA := ComputeGeodesicShoelaceArea(polyA)
	areaB := ComputeGeodesicShoelaceArea(polyB)

	// Check containment: A inside B
	allAInB := true
	for _, p := range polyA {
		if !PointInPolygon(p, polyB) {
			allAInB = false
			break
		}
	}
	if allAInB {
		return areaA
	}

	// Check containment: B inside A
	allBInA := true
	for _, p := range polyB {
		if !PointInPolygon(p, polyA) {
			allBInA = false
			break
		}
	}
	if allBInA {
		return areaB
	}

	// Convex / Sutherland-Hodgman clipping
	clipped := SutherlandHodgmanClip(polyA, polyB)
	if len(clipped) >= 3 {
		clippedArea := ComputeGeodesicShoelaceArea(clipped)
		if clippedArea > 0 {
			return math.Min(clippedArea, math.Min(areaA, areaB))
		}
	}

	// Try reverse clipping
	clippedRev := SutherlandHodgmanClip(polyB, polyA)
	if len(clippedRev) >= 3 {
		clippedArea := ComputeGeodesicShoelaceArea(clippedRev)
		if clippedArea > 0 {
			return math.Min(clippedArea, math.Min(areaA, areaB))
		}
	}

	return 0.0
}

// PolygonsTotalArea calculates the combined surface area of a set of polygons, subtracting overlaps.
func PolygonsTotalArea(polygons [][]LatLng) float64 {
	if len(polygons) == 0 {
		return 0.0
	}
	if len(polygons) == 1 {
		return ComputeGeodesicShoelaceArea(polygons[0])
	}

	var totalArea float64
	for i, poly := range polygons {
		area := ComputeGeodesicShoelaceArea(poly)
		// Subtract intersection with all previous polygons
		for j := 0; j < i; j++ {
			overlap := PolygonIntersectionArea(poly, polygons[j])
			area = math.Max(0.0, area-overlap)
		}
		totalArea += area
	}
	return totalArea
}

// CleanGeometry drops polygon components smaller than minAreaSqm (e.g. 2.0 m² slivers).
func CleanGeometry(polygons [][]LatLng, minAreaSqm float64) [][]LatLng {
	var cleaned [][]LatLng
	for _, poly := range polygons {
		if len(poly) >= 3 && ComputeGeodesicShoelaceArea(poly) >= minAreaSqm {
			cleaned = append(cleaned, poly)
		}
	}
	return cleaned
}
