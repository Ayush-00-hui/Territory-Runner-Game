package geo

import (
	"math"
	"strings"
)

const base32Alphabet = "0123456789bcdefghjkmnpqrstuvwxyz"

var base32Lookup = func() [256]int {
	var lookup [256]int
	for i := range lookup {
		lookup[i] = -1
	}
	for i, c := range base32Alphabet {
		lookup[c] = i
	}
	return lookup
}()

// BoundingBox represents a latitude/longitude min-max box.
type BoundingBox struct {
	MinLat float64
	MaxLat float64
	MinLng float64
	MaxLng float64
}

// EncodeGeohash encodes a (lat, lng) point to a geohash string of the given precision.
func EncodeGeohash(lat, lng float64, precision int) string {
	if precision <= 0 {
		return ""
	}
	minLat, maxLat := -90.0, 90.0
	minLng, maxLng := -180.0, 180.0

	var buf strings.Builder
	buf.Grow(precision)

	isLng := true
	ch := 0
	bit := 0

	for buf.Len() < precision {
		if isLng {
			mid := (minLng + maxLng) / 2.0
			if lng >= mid {
				ch |= 1 << (4 - bit)
				minLng = mid
			} else {
				maxLng = mid
			}
		} else {
			mid := (minLat + maxLat) / 2.0
			if lat >= mid {
				ch |= 1 << (4 - bit)
				minLat = mid
			} else {
				maxLat = mid
			}
		}
		isLng = !isLng
		bit++

		if bit == 5 {
			buf.WriteByte(base32Alphabet[ch])
			bit = 0
			ch = 0
		}
	}

	return buf.String()
}

// DecodeGeohashBounds returns the bounding box of a geohash string.
func DecodeGeohashBounds(hash string) BoundingBox {
	minLat, maxLat := -90.0, 90.0
	minLng, maxLng := -180.0, 180.0
	isLng := true

	for i := 0; i < len(hash); i++ {
		charIdx := int(hash[i])
		val := base32Lookup[charIdx]
		if val < 0 {
			continue
		}

		for bit := 4; bit >= 0; bit-- {
			mask := 1 << bit
			if isLng {
				mid := (minLng + maxLng) / 2.0
				if (val & mask) != 0 {
					minLng = mid
				} else {
					maxLng = mid
				}
			} else {
				mid := (minLat + maxLat) / 2.0
				if (val & mask) != 0 {
					minLat = mid
				} else {
					maxLat = mid
				}
			}
			isLng = !isLng
		}
	}

	return BoundingBox{
		MinLat: minLat,
		MaxLat: maxLat,
		MinLng: minLng,
		MaxLng: maxLng,
	}
}

// GeohashPrecision6 returns the standard 6-character geohash (~1.2 km x 0.6 km).
func GeohashPrecision6(lat, lng float64) string {
	return EncodeGeohash(lat, lng, 6)
}

// GeohashNeighbors returns the 8 surrounding neighbor cells for a given geohash.
func GeohashNeighbors(hash string) []string {
	if len(hash) == 0 {
		return nil
	}
	box := DecodeGeohashBounds(hash)
	centerLat := (box.MinLat + box.MaxLat) / 2.0
	centerLng := (box.MinLng + box.MaxLng) / 2.0
	latSpan := box.MaxLat - box.MinLat
	lngSpan := box.MaxLng - box.MinLng

	precision := len(hash)

	// Offsets for 8 compass neighbors: N, S, E, W, NE, NW, SE, SW
	offsets := [][2]float64{
		{latSpan, 0},        // N
		{-latSpan, 0},       // S
		{0, lngSpan},        // E
		{0, -lngSpan},       // W
		{latSpan, lngSpan},   // NE
		{latSpan, -lngSpan},  // NW
		{-latSpan, lngSpan},  // SE
		{-latSpan, -lngSpan}, // SW
	}

	neighbors := make([]string, 0, 8)
	seen := make(map[string]bool, 8)

	for _, offset := range offsets {
		nLat := centerLat + offset[0]
		nLng := centerLng + offset[1]

		// Clamp lat to [-90, 90]
		if nLat > 90.0 {
			nLat = 90.0
		} else if nLat < -90.0 {
			nLat = -90.0
		}

		// Wrap lng to [-180, 180]
		for nLng > 180.0 {
			nLng -= 360.0
		}
		for nLng < -180.0 {
			nLng += 360.0
		}

		neighborHash := EncodeGeohash(nLat, nLng, precision)
		if neighborHash != hash && !seen[neighborHash] {
			seen[neighborHash] = true
			neighbors = append(neighbors, neighborHash)
		}
	}

	return neighbors
}

// SnapToGrid coarsens coordinates to approximately gridMeters resolution (default ~25m).
// Prevents high-resolution tracking and physical triangulation of runners.
func SnapToGrid(lat, lng, gridMeters float64) (float64, float64) {
	if gridMeters <= 0 {
		return lat, lng
	}

	// 1 degree latitude ~= 111,320 meters
	latDegPerMeter := 1.0 / 111320.0
	latStep := gridMeters * latDegPerMeter

	snappedLat := math.Round(lat/latStep) * latStep

	// 1 degree longitude depends on latitude: 111,320 * cos(snappedLat)
	radLat := snappedLat * math.Pi / 180.0
	cosLat := math.Cos(radLat)
	if cosLat < 0.0001 {
		cosLat = 0.0001
	}
	lngDegPerMeter := 1.0 / (111320.0 * cosLat)
	lngStep := gridMeters * lngDegPerMeter

	snappedLng := math.Round(lng/lngStep) * lngStep

	// Round to 6 decimal places to prevent floating point inaccuracies
	snappedLat = math.Round(snappedLat*1e6) / 1e6
	snappedLng = math.Round(snappedLng*1e6) / 1e6

	return snappedLat, snappedLng
}
