package geo

import (
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
)

var (
	// ErrLoopSelfIntersecting is returned when a loop crosses itself.
	ErrLoopSelfIntersecting = errors.New("Loop crossed itself — try again")
	// ErrLoopPerimeterTooSmall is returned when a closed loop perimeter is below threshold.
	ErrLoopPerimeterTooSmall = errors.New("Loop perimeter below minimum threshold")
	// ErrLoopAreaTooSmall is returned when a closed loop area is below minimum threshold.
	ErrLoopAreaTooSmall = errors.New("Loop area below minimum threshold")
	// ErrLoopTooFewPoints is returned when candidate path has fewer than minimum vertices.
	ErrLoopTooFewPoints = errors.New("Loop vertices below minimum threshold (4 points)")
	// ErrLoopAreaTooLarge is returned when a loop exceeds maximum single human capture area.
	ErrLoopAreaTooLarge = errors.New("Loop area exceeds maximum allowable single run threshold (5000000 m²)")
	// ErrSignalGapDetected is returned when a GPS signal gap exceeds the maximum allowed time.
	ErrSignalGapDetected = errors.New("GPS signal interrupted (>15s gap) — path reset to prevent inaccurate enclosure")
)

// Config encapsulates the geometric constraints of the enclosure engine.
type Config struct {
	MinClosureDistanceMeters    float64
	MinPointsRequired           int
	MinLoopDistanceMeters       float64
	MinLoopAreaSqM              float64
	MaxLoopAreaSqM              float64
	MinStationaryDistanceMeters float64
	MaxSpeedKmhOutlier          float64
	MaxSignalGapSeconds         float64
	MaxPauseDisplacementMeters  float64
	MaxPauseDurationSeconds     float64
	ActivityName                string
}

// DefaultConfig returns the calibrated threshold parameters matching the Flutter client for running.
func DefaultConfig() Config {
	return Config{
		MinClosureDistanceMeters:    35.0,
		MinPointsRequired:           4,
		MinLoopDistanceMeters:       60.0,
		MinLoopAreaSqM:              200.0,
		MaxLoopAreaSqM:              5000000.0,
		MinStationaryDistanceMeters: 1.8,
		MaxSpeedKmhOutlier:          35.0,
		MaxSignalGapSeconds:         15.0,
		MaxPauseDisplacementMeters:  50.0,
		MaxPauseDurationSeconds:     600.0,
		ActivityName:                "running",
	}
}

// ConfigForActivity returns kinematics thresholds calibrated specifically to the exercise modality.
func ConfigForActivity(activity string) Config {
	act := strings.ToLower(strings.TrimSpace(activity))
	switch act {
	case "walking":
		return Config{
			MinClosureDistanceMeters:    35.0,
			MinPointsRequired:           4,
			MinLoopDistanceMeters:       40.0,
			MinLoopAreaSqM:              100.0,
			MaxLoopAreaSqM:              5000000.0,
			MinStationaryDistanceMeters: 1.8,
			MaxSpeedKmhOutlier:          15.0,
			MaxSignalGapSeconds:         15.0,
			MaxPauseDisplacementMeters:  50.0,
			MaxPauseDurationSeconds:     600.0,
			ActivityName:                "walking",
		}
	case "cycling":
		return Config{
			MinClosureDistanceMeters:    35.0,
			MinPointsRequired:           4,
			MinLoopDistanceMeters:       150.0,
			MinLoopAreaSqM:              1000.0,
			MaxLoopAreaSqM:              5000000.0,
			MinStationaryDistanceMeters: 1.8,
			MaxSpeedKmhOutlier:          60.0,
			MaxSignalGapSeconds:         15.0,
			MaxPauseDisplacementMeters:  50.0,
			MaxPauseDurationSeconds:     600.0,
			ActivityName:                "cycling",
		}
	case "running":
		fallthrough
	default:
		return Config{
			MinClosureDistanceMeters:    35.0,
			MinPointsRequired:           4,
			MinLoopDistanceMeters:       60.0,
			MinLoopAreaSqM:              200.0,
			MaxLoopAreaSqM:              5000000.0,
			MinStationaryDistanceMeters: 1.8,
			MaxSpeedKmhOutlier:          35.0,
			MaxSignalGapSeconds:         15.0,
			MaxPauseDisplacementMeters:  50.0,
			MaxPauseDurationSeconds:     600.0,
			ActivityName:                "running",
		}
	}
}

// Engine implements server-side GPS breadcrumb tracking and sovereign loop enclosure.
type Engine struct {
	cfg              Config
	path             []LatLng
	timestamps       []time.Time
	lastReceivedPos  *LatLng
	lastReceivedTime *time.Time
	lastInvalidErr   error
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
	e.lastReceivedPos = nil
	e.lastReceivedTime = nil
	e.lastInvalidErr = nil
}

// LastInvalidError returns the most recent rejection error.
func (e *Engine) LastInvalidError() error {
	return e.lastInvalidErr
}

// AddPoint ingests a new breadcrumb, performs noise/jitter filtering, and checks for loop closure.
func (e *Engine) AddPoint(tp TrackPoint) (*EnclosedLoop, error) {
	e.lastInvalidErr = nil
	pos := tp.ToLatLng()
	now := tp.Timestamp
	if now.IsZero() {
		now = time.Now().UTC()
	}

	// 0. GPS Signal Gap Guard: Gaps > MaxSignalGapSeconds (15s) segment the track.
	// Displacement-aware: if gap > 15s but straight-line distance from last path point <= 50m,
	// treat as a pause: keep path, do not reset. Reset if displacement > 50m or gap > 10m (600s).
	if e.cfg.MaxSignalGapSeconds > 0 && len(e.timestamps) > 0 && len(e.path) > 0 {
		gapSec := math.Abs(now.Sub(e.timestamps[len(e.timestamps)-1]).Seconds())
		if gapSec > e.cfg.MaxSignalGapSeconds {
			displacement := HaversineDistanceMeters(e.path[len(e.path)-1], pos)
			maxPauseDur := e.cfg.MaxPauseDurationSeconds
			if maxPauseDur <= 0 {
				maxPauseDur = 600.0
			}
			maxPauseDisp := e.cfg.MaxPauseDisplacementMeters
			if maxPauseDisp <= 0 {
				maxPauseDisp = 50.0
			}
			if gapSec > maxPauseDur || displacement > maxPauseDisp {
				e.lastInvalidErr = ErrSignalGapDetected
				e.path = []LatLng{pos}
				e.timestamps = []time.Time{now}
				e.lastReceivedPos = &pos
				e.lastReceivedTime = &now
				return nil, nil
			}
		}
	}

	// 1. Discard satellite multipath outlier jumps against immediately preceding sample
	if e.lastReceivedPos != nil && e.lastReceivedTime != nil {
		dtSec := math.Abs(now.Sub(*e.lastReceivedTime).Seconds())
		if dtSec >= 0.5 && dtSec <= 5.0 {
			stepDist := HaversineDistanceMeters(*e.lastReceivedPos, pos)
			speedKmh := (stepDist / dtSec) * 3.6
			if speedKmh > e.cfg.MaxSpeedKmhOutlier {
				e.lastReceivedPos = &pos
				e.lastReceivedTime = &now
				return nil, nil
			}
		}
	}
	e.lastReceivedPos = &pos
	e.lastReceivedTime = &now

	if len(e.path) > 0 {
		lastPoint := e.path[len(e.path)-1]
		distFromLast := HaversineDistanceMeters(lastPoint, pos)

		// Filter out stationary jitter (< 1.8m)
		if distFromLast < e.cfg.MinStationaryDistanceMeters {
			return nil, nil
		}
	}

	e.path = append(e.path, pos)
	e.timestamps = append(e.timestamps, now)

	if len(e.path) < e.cfg.MinPointsRequired {
		return nil, nil
	}

	currentIndex := len(e.path) - 1
	currentPos := e.path[currentIndex]

	// --- 1. LASSO CLOSURE CHECK ---
	// If the newest segment properly crosses an earlier segment (not adjacent),
	// close the loop at the intersection point:
	// polygon = [intersection point, path vertices after crossed segment ... current vertex, intersection point]
	if len(e.path) >= 4 {
		pLast1 := e.path[currentIndex-1]
		pLast2 := currentPos

		var bestLassoLoop *EnclosedLoop
		var bestLassoJ int
		var bestLassoIntersection *LatLng
		maxLassoArea := -1.0

		for j := 0; j <= currentIndex-3; j++ {
			pEarly1 := e.path[j]
			pEarly2 := e.path[j+1]

			if DoSegmentsIntersect(pEarly1, pEarly2, pLast1, pLast2) {
				intersection, _, ok := ComputeIntersectionPoint(pEarly1, pEarly2, pLast1, pLast2)
				if ok && intersection != nil {
					lassoPoints := make([]LatLng, 0, (currentIndex-j)+1)
					lassoPoints = append(lassoPoints, *intersection)
					lassoPoints = append(lassoPoints, e.path[j+1:currentIndex]...)
					lassoPoints = append(lassoPoints, *intersection)

					loop, err := e.ValidateLoop(lassoPoints, now)
					if err == nil && loop != nil {
						if loop.AreaSqMeters > maxLassoArea {
							maxLassoArea = loop.AreaSqMeters
							bestLassoLoop = loop
							bestLassoJ = j
							bestLassoIntersection = intersection
						}
					}
				}
			}
		}

		if bestLassoLoop != nil && bestLassoIntersection != nil {
			// Keep the tail before the crossing as the remaining path
			newPath := make([]LatLng, 0, bestLassoJ+2)
			newTimestamps := make([]time.Time, 0, bestLassoJ+2)
			for k := 0; k <= bestLassoJ; k++ {
				newPath = append(newPath, e.path[k])
				newTimestamps = append(newTimestamps, e.timestamps[k])
			}
			newPath = append(newPath, *bestLassoIntersection)

			tEarly1 := e.timestamps[bestLassoJ]
			tEarly2 := e.timestamps[bestLassoJ+1]
			dTotal := HaversineDistanceMeters(e.path[bestLassoJ], e.path[bestLassoJ+1])
			dPart := HaversineDistanceMeters(e.path[bestLassoJ], *bestLassoIntersection)
			fraction := 0.0
			if dTotal > 1e-6 {
				fraction = math.Max(0.0, math.Min(1.0, dPart/dTotal))
			}
			durNano := float64(tEarly2.Sub(tEarly1).Nanoseconds()) * fraction
			newTimestamps = append(newTimestamps, tEarly1.Add(time.Duration(durNano)))

			e.path = newPath
			e.timestamps = newTimestamps
			return bestLassoLoop, nil
		}
	}

	// --- 2. PROXIMITY CLOSURE CHECK ---
	// Scan backwards from earliest points, test ALL candidates, accept best valid loop
	var bestProximityLoop *EnclosedLoop
	maxProximityArea := -1.0
	var candidateErr error

	for i := 0; i <= currentIndex-e.cfg.MinPointsRequired; i++ {
		candidatePoint := e.path[i]
		dist := HaversineDistanceMeters(currentPos, candidatePoint)

		if dist <= e.cfg.MinClosureDistanceMeters {
			loopPoints := append([]LatLng(nil), e.path[i:currentIndex+1]...)
			loop, err := e.ValidateLoop(loopPoints, now)
			if err != nil {
				candidateErr = err
				continue
			}

			if loop.AreaSqMeters > maxProximityArea {
				maxProximityArea = loop.AreaSqMeters
				bestProximityLoop = loop
			}
		}
	}

	if bestProximityLoop != nil {
		// Retain current position as origin for next loop
		e.path = []LatLng{pos}
		e.timestamps = []time.Time{now}
		return bestProximityLoop, nil
	}

	if candidateErr != nil {
		e.lastInvalidErr = candidateErr
		if errors.Is(candidateErr, ErrLoopSelfIntersecting) || errors.Is(candidateErr, ErrLoopAreaTooLarge) {
			return nil, candidateErr
		}
	}

	return nil, nil
}

// ProcessTrack processes an entire GPS sequence and extracts all valid enclosed loops.
// It does NOT abort on a self-intersection; a run is rejected only if it contains zero valid loops.
func (e *Engine) ProcessTrack(points []TrackPoint) ([]EnclosedLoop, error) {
	e.Clear()
	var loops []EnclosedLoop
	var trackErr error

	for _, pt := range points {
		loop, err := e.AddPoint(pt)
		if err != nil {
			trackErr = err
		} else if e.lastInvalidErr != nil {
			trackErr = e.lastInvalidErr
		}
		if loop != nil {
			loops = append(loops, *loop)
		}
	}

	if len(loops) == 0 && trackErr != nil {
		return nil, trackErr
	}

	return loops, nil
}

// ProcessTrackWithActivity processes an entire GPS sequence using the specified activity's kinematics constraints.
func ProcessTrackWithActivity(points []TrackPoint, activity string) ([]EnclosedLoop, error) {
	eng := NewEngine(ConfigForActivity(activity))
	return eng.ProcessTrack(points)
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
	if e.cfg.MinLoopAreaSqM > 0 && areaSqM < e.cfg.MinLoopAreaSqM {
		return nil, fmt.Errorf("%w: %.1f m² < %.1f m²", ErrLoopAreaTooSmall, areaSqM, e.cfg.MinLoopAreaSqM)
	}
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
