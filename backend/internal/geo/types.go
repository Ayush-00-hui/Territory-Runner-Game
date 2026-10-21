package geo

import "time"

// LatLng represents a WGS84 geographic coordinate pair.
type LatLng struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// TrackPoint represents a single GPS breadcrumb recorded during a run.
type TrackPoint struct {
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Timestamp time.Time `json:"timestamp"`
	Altitude  float64   `json:"altitude,omitempty"`
	Speed     float64   `json:"speed,omitempty"`
	Heading   float64   `json:"heading,omitempty"`
	IsMocked  bool      `json:"is_mocked,omitempty"`
}

// ToLatLng converts TrackPoint to LatLng.
func (tp TrackPoint) ToLatLng() LatLng {
	return LatLng{Latitude: tp.Latitude, Longitude: tp.Longitude}
}

// EnclosedLoop represents a verified closed sovereign loop ready for territory ingestion.
type EnclosedLoop struct {
	Polygon            []LatLng  `json:"polygon"`
	AreaSqMeters       float64   `json:"area_sq_meters"`
	AreaSqKm           float64   `json:"area_sq_km"`
	LoopDistanceMeters float64   `json:"loop_distance_meters"`
	ClosedAt           time.Time `json:"closed_at"`
}
