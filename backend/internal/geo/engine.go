package geo

import (
	"errors"
	"fmt"
	"math"
	"time"
)

var (
	// ErrLoopSelfIntersecting is returned when a loop crosses itself.
	ErrLoopSelfIntersecting = errors.New("Loop crossed itself — try again")
	// ErrLoopPerimeterTooSmall is returned when a closed loop perimeter is below threshold.
	ErrLoopPerimeterTooSmall = errors.New("Loop perimeter below minimum threshold (40.0m)")
	// ErrLoopTooFewPoints is returned when candidate path has fewer than minimum vertices.
	ErrLoopTooFewPoints = errors.New("Loop vertices below minimum threshold (4 points)")
	// ErrLoopAreaTooLarge is returned when a loop exceeds maximum single human capture area.
	ErrLoopAreaTooLarge = errors.New("Loop area exceeds maximum allowable single run threshold (5000000 m²)")
)

// Config encapsulates the geometric constraints of the enclosure engine.
type Config struct {
	MinClosureDistanceMeters    float64
	MinPointsRequired           int
	MinLoopDistanceMeters       float64
	MaxLoopAreaSqM              float64
	MinStationaryDistanceMeters float64
	MaxSpeedKmhOutlier          float64
}

// DefaultConfig returns the calibrated threshold parameters matching the Flutter client.
func DefaultConfig() Config {
	return Config{
		MinClosureDistanceMeters:    35.0,
		MinPointsRequired:           4,
		MinLoopDistanceMeters:       40.0,
		MaxLoopAreaSqM:              5000000.0,
		MinStationaryDistanceMeters: 1.8,
		MaxSpeedKmhOutlier:          35.0,
	}
}

// Engine implements server-side GPS breadcrumb tracking and sovereign loop enclosure.
type Engine struct {
	cfg        Config
	path       []LatLng
	timestamps []time.Time
}

// NewEngine creates an enclosure engine with the provided or default configuration.
func NewEngine(cfg ...Config) *Engine {
	c := DefaultConfig()
	if len(cfg) > 0 {
		c = cfg[0]
	}
	return &Engine{
		cfg:        c,
		path:       make([]LatLng, 0),
		timestamps: make([]time.Time, 0),
	}
}

// Clear resets the internal breadcrumbs.
func (e *Engine) Clear() {
	e.path = e.path[:0]
	e.timestamps = e.timestamps[:0]
}

// AddPoint ingests a new breadcrumb, performs noise/jitter filtering, and checks for loop closure.
func (e *Engine) AddPoint(tp TrackPoint) (*EnclosedLoop, error) {
	pos := tp.ToLatLng()
	now := tp.Timestamp
	if now.IsZero() {
		now = time.Now().UTC()
	}

	if len(e.path) > 0 {
		lastPoint := e.path[len(e.path)-1]
		distFromLast := HaversineDistanceMeters(lastPoint, pos)

		// Filter out stationary jitter (< 1.8m)
		if distFromLast < e.cfg.MinStationaryDistanceMeters {
			return nil, nil
		}

		// Discard satellite multipath outlier jumps (> 35 km/h)
		if len(e.timestamps) > 0 {
			dtSec := math.Abs(now.Sub(e.timestamps[len(e.timestamps)-1]).Seconds())
			if dtSec >= 0.5 && dtSec <= 5.0 {
				speedKmh := (distFromLast / dtSec) * 3.6
				if speedKmh > e.cfg.MaxSpeedKmhOutlier {
					return nil, nil
				}
			}
		}
	}

	e.path = append(e.path, pos)
	e.timestamps = append(e.timestamps, now)

	if len(e.path) < e.cfg.MinPointsRequired {
		return nil, nil
	}

	currentIndex := len(e.path) - 1
	currentPos := e.path[currentIndex]

	// Scan backwards from the earliest points to find closure
	for i := 0; i <= currentIndex-e.cfg.MinPointsRequired; i++ {
		candidatePoint := e.path[i]
		dist := HaversineDistanceMeters(currentPos, candidatePoint)

		if dist <= e.cfg.MinClosureDistanceMeters {
			loopPoints := append([]LatLng(nil), e.path[i:currentIndex+1]...)
			loop, err := e.ValidateLoop(loopPoints, now)
			if err != nil {
				if errors.Is(err, ErrLoopSelfIntersecting) {
					return nil, err
				}
				continue
			}

			// Retain current position as origin for next loop
			e.path = []LatLng{pos}
			e.timestamps = []time.Time{now}

			return loop, nil
		}
	}

	return nil, nil
}

// ProcessTrack processes an entire GPS sequence and extracts all valid enclosed loops.
func (e *Engine) ProcessTrack(points []TrackPoint) ([]EnclosedLoop, error) {
	e.Clear()
	var loops []EnclosedLoop

	for _, pt := range points {
		loop, err := e.AddPoint(pt)
		if err != nil {
			return nil, err
		}
		if loop != nil {
			loops = append(loops, *loop)
		}
	}

	return loops, nil
}

// ValidateLoop verifies that a closed loop satisfies all geometrical integrity rules.
func (e *Engine) ValidateLoop(points []LatLng, closedAt time.Time) (*EnclosedLoop, error) {
	if len(points) < e.cfg.MinPointsRequired {
		return nil, ErrLoopTooFewPoints
	}

	loopLength := CalculatePathDistanceMeters(points)
	if loopLength < e.cfg.MinLoopDistanceMeters {
		return nil, ErrLoopPerimeterTooSmall
	}

	// Check self-intersection (strict CCW interior crossings)
	if HasSelfIntersection(points) {
		return nil, ErrLoopSelfIntersecting
	}

	areaSqM := ComputeGeodesicShoelaceArea(points)
	if areaSqM > e.cfg.MaxLoopAreaSqM {
		return nil, fmt.Errorf("%w: %.1f m² > %.1f m²", ErrLoopAreaTooLarge, areaSqM, e.cfg.MaxLoopAreaSqM)
	}

	if closedAt.IsZero() {
		closedAt = time.Now().UTC()
	}

	return &EnclosedLoop{
		Polygon:            points,
		AreaSqMeters:       areaSqM,
		AreaSqKm:           areaSqM / 1000000.0,
		LoopDistanceMeters: loopLength,
		ClosedAt:           closedAt,
	}, nil
}
