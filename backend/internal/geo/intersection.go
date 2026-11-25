package geo

import "math"

const intersectionEpsilon = 1e-9

// ccw computes the 2D cross product of vector (b - a) and vector (c - a).
func ccw(a, b, c LatLng) float64 {
	return (b.Longitude-a.Longitude)*(c.Latitude-a.Latitude) -
		(b.Latitude-a.Latitude)*(c.Longitude-a.Longitude)
}

// DoSegmentsIntersect checks if line segments (p1->p2) and (p3->p4) properly cross each other or overlap collinearly.
func DoSegmentsIntersect(p1, p2, p3, p4 LatLng) bool {
	d1 := ccw(p3, p4, p1)
	d2 := ccw(p3, p4, p2)
	d3 := ccw(p1, p2, p3)
	d4 := ccw(p1, p2, p4)

	if ((d1 > intersectionEpsilon && d2 < -intersectionEpsilon) || (d1 < -intersectionEpsilon && d2 > intersectionEpsilon)) &&
		((d3 > intersectionEpsilon && d4 < -intersectionEpsilon) || (d3 < -intersectionEpsilon && d4 > intersectionEpsilon)) {
		return true
	}

	// Collinear overlap check
	if math.Abs(d1) <= intersectionEpsilon && math.Abs(d2) <= intersectionEpsilon &&
		math.Abs(d3) <= intersectionEpsilon && math.Abs(d4) <= intersectionEpsilon {
		dx := p2.Longitude - p1.Longitude
		dy := p2.Latitude - p1.Latitude
		lenSq := dx*dx + dy*dy
		if lenSq > 1e-18 {
			t3 := ((p3.Longitude-p1.Longitude)*dx + (p3.Latitude-p1.Latitude)*dy) / lenSq
			t4 := ((p4.Longitude-p1.Longitude)*dx + (p4.Latitude-p1.Latitude)*dy) / lenSq
			minT := math.Min(t3, t4)
			maxT := math.Max(t3, t4)
			overlapStart := math.Max(0.0, minT)
			overlapEnd := math.Min(1.0, maxT)
			if overlapEnd-overlapStart > 1e-6 {
				return true
			}
		}
	}

	return false
}

// ComputeIntersectionPoint calculates the 2D intersection point between segments (p1->p2) and (p3->p4).
// Returns (intersection, t, ok) where t is the fractional distance along segment (p1->p2).
func ComputeIntersectionPoint(p1, p2, p3, p4 LatLng) (*LatLng, float64, bool) {
	x1, y1 := p1.Longitude, p1.Latitude
	x2, y2 := p2.Longitude, p2.Latitude
	x3, y3 := p3.Longitude, p3.Latitude
	x4, y4 := p4.Longitude, p4.Latitude

	denom := (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4)
	if math.Abs(denom) < 1e-12 {
		return nil, 0, false
	}
	t := ((x1-x3)*(y3-y4) - (y1-y3)*(x3-x4)) / denom
	u := ((x1-x3)*(y1-y2) - (y1-y3)*(x1-x2)) / denom

	if t > intersectionEpsilon && t < 1.0-intersectionEpsilon &&
		u > intersectionEpsilon && u < 1.0-intersectionEpsilon {
		intLng := x1 + t*(x2-x1)
		intLat := y1 + t*(y2-y1)
		return &LatLng{Latitude: intLat, Longitude: intLng}, t, true
	}
	return nil, 0, false
}

// HasSelfIntersection validates whether a closed or open polygon path contains interior self-intersections or foldback spurs.
func HasSelfIntersection(polygon []LatLng) bool {
	n := len(polygon)
	if n < 3 {
		return false
	}

	// 1. Check for 180-degree foldbacks (out-and-back spurs) on adjacent segments
	for i := 0; i < n-2; i++ {
		p1 := polygon[i]
		p2 := polygon[i+1]
		p3 := polygon[i+2]
		dx1 := p2.Longitude - p1.Longitude
		dy1 := p2.Latitude - p1.Latitude
		dx2 := p3.Longitude - p2.Longitude
		dy2 := p3.Latitude - p2.Latitude
		cross := dx1*dy2 - dy1*dx2
		dot := dx1*dx2 + dy1*dy2
		if math.Abs(cross) < 1e-12 && dot < -1e-12 {
			return true // 180-degree foldback spur
		}
	}

	// 2. Check for intersections and collinear overlaps between non-adjacent segments
	for i := 0; i < n-1; i++ {
		p1 := polygon[i]
		p2 := polygon[i+1]
		for j := i + 2; j < n-1; j++ {
			// Ignore shared start-end vertex in a closed ring
			if i == 0 && j == n-2 {
				continue
			}
			p3 := polygon[j]
			p4 := polygon[j+1]
			if DoSegmentsIntersect(p1, p2, p3, p4) {
				return true
			}
		}
	}
	return false
}
