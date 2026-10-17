package anticheat

import (
	"fmt"
	"math"
	"strings"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

// Result captures the evaluation of GPS anomaly detection and spoofing mitigation.
type Result struct {
	IsAnomaly bool               `json:"is_anomaly"`
	Score     float64            `json:"score"`
	Reasons   []string           `json:"reasons"`
	Features  map[string]float64 `json:"features,omitempty"`
}

// ActivityLimits defines realistic human kinematics ceilings for a specific exercise activity.
type ActivityLimits struct {
	MaxInstantSpeedKmh float64
	MaxAverageSpeedKmh float64
	MaxTeleportSpeed   float64
}

// DefaultActivityLimits maps each supported activity type to its calibrated limits.
var DefaultActivityLimits = map[string]ActivityLimits{
	"running": {
		MaxInstantSpeedKmh: 25.0, // Human sprinting/distance ceiling
		MaxAverageSpeedKmh: 22.0, // World record marathon pace is ~20.9 km/h
		MaxTeleportSpeed:   35.0,
	},
	"walking": {
		MaxInstantSpeedKmh: 10.0, // Walking pace ceiling (jogging starts > 9-10 km/h)
		MaxAverageSpeedKmh: 8.5,
		MaxTeleportSpeed:   15.0,
	},
	"cycling": {
		MaxInstantSpeedKmh: 50.0, // Urban/road cycling ceiling
		MaxAverageSpeedKmh: 40.0, // Peloton average ceiling
		MaxTeleportSpeed:   65.0,
	},
}

// Config stores calibrated statistical baselines and deterministic thresholds.
type Config struct {
	MaxHumanSpeedKmh float64
	MaxTeleportSpeed float64
	AnomalyThreshold float64
	Means            [5]float64
	Stds             [5]float64
	Weights          [5]float64
}

// DefaultConfig returns calibrated baseline statistics matching assets/models/gps_anomaly_detector.json.
// Design Note: We honestly name this a Multi-Feature Weighted Z-Score Detector rather than
// claiming a full Mahalanobis distance, because the baseline model provides 1D standard deviations
// rather than an empirical non-diagonal covariance matrix.
func DefaultConfig() Config {
	return Config{
		MaxHumanSpeedKmh: 25.0,
		MaxTeleportSpeed: 35.0,
		AnomalyThreshold: 3.0,
		Means:            [5]float64{9.85, 1.42, 6.35, 0.88, 0.05},
		Stds:             [5]float64{2.15, 0.68, 2.80, 0.09, 0.04},
		Weights:          [5]float64{2.5, 2.0, 1.2, 1.0, 0.8},
	}
}

// Detector implements GPS anomaly detection and spoofing mitigation.
type Detector struct {
	cfg Config
}

// NewDetector creates an anomaly detector instance.
func NewDetector(cfg ...Config) *Detector {
	c := DefaultConfig()
	if len(cfg) > 0 {
		c = cfg[0]
	}
	return &Detector{cfg: c}
}

// EvaluateTrack evaluates a sequence of GPS breadcrumbs for potential spoofing or physics violations assuming running.
func (d *Detector) EvaluateTrack(points []geo.TrackPoint) Result {
	return d.EvaluateTrackWithActivity(points, "running")
}

// EvaluateTrackWithActivity evaluates GPS points against activity-specific speed and kinematics limits.
func (d *Detector) EvaluateTrackWithActivity(points []geo.TrackPoint, activityType string) Result {
	if len(points) == 0 {
		return Result{
			IsAnomaly: false,
			Score:     0.0,
			Reasons:   []string{"Empty GPS telemetry"},
		}
	}

	activityType = strings.ToLower(strings.TrimSpace(activityType))
	if activityType == "" {
		activityType = "running"
	}
	limits, ok := DefaultActivityLimits[activityType]
	if !ok {
		limits = DefaultActivityLimits["running"]
	}

	var reasons []string
	maxScore := 0.0

	// --- Tier 1: Deterministic Physics & OS Indicators ---
	for i, pt := range points {
		// Rule 1: OS Mock Location Indicator
		if pt.IsMocked {
			return Result{
				IsAnomaly: true,
				Score:     99.0,
				Reasons:   []string{"Mock location provider detected"},
				Features:  map[string]float64{"is_mocked": 1.0},
			}
		}

		// Rule 2: Instantaneous speed ceiling
		instantKmh := pt.Speed * 3.6
		if instantKmh > limits.MaxInstantSpeedKmh {
			ruleScore := 55.0 + (instantKmh - limits.MaxInstantSpeedKmh)
			if ruleScore > maxScore {
				maxScore = ruleScore
			}
			if activityType == "running" {
				reasons = append(reasons, fmt.Sprintf("Instantaneous speed %.1f km/h exceeds human running ceiling (%.1f km/h); cycling or vehicle suspected", instantKmh, limits.MaxInstantSpeedKmh))
			} else {
				reasons = append(reasons, fmt.Sprintf("Instantaneous speed %.1f km/h exceeds %s ceiling (%.1f km/h)", instantKmh, activityType, limits.MaxInstantSpeedKmh))
			}
		}

		// Rule 3: Teleport jumps against previous coordinate
		if i > 0 {
			prev := points[i-1]
			dt := math.Abs(pt.Timestamp.Sub(prev.Timestamp).Seconds())
			if dt > 0 && dt <= 3.0 {
				distMeters := geo.HaversineDistanceMeters(prev.ToLatLng(), pt.ToLatLng())
				stepSpeedKmh := (distMeters / dt) * 3.6
				if stepSpeedKmh > limits.MaxTeleportSpeed || (distMeters > 50.0 && dt <= 1.0) {
					ruleScore := 55.0
					if ruleScore > maxScore {
						maxScore = ruleScore
					}
					reasons = append(reasons, fmt.Sprintf("Position teleportation jump detected: %.1fm in %.1fs (%.1f km/h)", distMeters, dt, stepSpeedKmh))
				}
			}
		}
	}

	// Rule 4: Identical-step GPS replay detection
	if len(points) >= 4 {
		identicalSteps := 0
		for i := 1; i < len(points); i++ {
			p1 := points[i-1]
			p2 := points[i]
			if p1.Latitude == p2.Latitude && p1.Longitude == p2.Longitude {
				identicalSteps++
			}
		}
		if identicalSteps > len(points)/2 {
			reasons = append(reasons, "Excessive frozen/replay identical GPS breadcrumbs detected")
			if maxScore < 5.0 {
				maxScore = 5.0
			}
		}
	}

	features := d.extractFeatures(points)

	// Rule 5: Sustained average speed ceiling check
	if avgSpeed, ok := features["avg_speed"]; ok && len(points) >= 3 {
		if avgSpeed > limits.MaxAverageSpeedKmh {
			ruleScore := 55.0 + (avgSpeed - limits.MaxAverageSpeedKmh)
			if ruleScore > maxScore {
				maxScore = ruleScore
			}
			reasons = append(reasons, fmt.Sprintf("Average speed %.1f km/h exceeds %s endurance ceiling (%.1f km/h); cycling or vehicle suspected", avgSpeed, activityType, limits.MaxAverageSpeedKmh))
		}
	}

	if len(points) < 3 {
		isAnomaly := maxScore > d.cfg.AnomalyThreshold
		return Result{
			IsAnomaly: isAnomaly,
			Score:     maxScore,
			Reasons:   reasons,
		}
	}

	// --- Tier 2: Calibrated Multi-Feature Weighted Z-Score Scoring (Running Baseline) ---
	if activityType == "running" {
		fVector := [5]float64{
			features["avg_speed"],
			features["max_accel"],
			features["heading_rate"],
			features["sinuosity"],
			features["stop_freq"],
		}

		var weightedScore float64
		for i := 0; i < 5; i++ {
			z := math.Abs((fVector[i] - d.cfg.Means[i]) / d.cfg.Stds[i])
			weightedScore += z * d.cfg.Weights[i]
		}
		normalizedScore := weightedScore / 7.5

		if normalizedScore > maxScore {
			maxScore = normalizedScore
		}

		if normalizedScore > d.cfg.AnomalyThreshold {
			reasons = append(reasons, fmt.Sprintf("Unnatural movement telemetry pattern (Z-Score: %.2f > %.2f)", normalizedScore, d.cfg.AnomalyThreshold))
		}
	}

	isAnomaly := maxScore > d.cfg.AnomalyThreshold
	return Result{
		IsAnomaly: isAnomaly,
		Score:     maxScore,
		Reasons:   reasons,
		Features:  features,
	}
}

func (d *Detector) extractFeatures(window []geo.TrackPoint) map[string]float64 {
	n := len(window)
	var sumSpeed float64
	speeds := make([]float64, n)
	for i, p := range window {
		spd := p.Speed * 3.6
		speeds[i] = spd
		sumSpeed += spd
	}
	avgSpeed := sumSpeed / float64(n)

	// Max acceleration
	var maxAccel float64
	for i := 0; i < n-1; i++ {
		dt := math.Abs(window[i+1].Timestamp.Sub(window[i].Timestamp).Seconds())
		if dt > 0 {
			dv := math.Abs(window[i+1].Speed - window[i].Speed)
			accel := dv / dt
			if accel > maxAccel {
				maxAccel = accel
			}
		}
	}

	// Heading change rate
	var totalHeadingDelta float64
	for i := 0; i < n-1; i++ {
		diff := math.Abs(window[i+1].Heading - window[i].Heading)
		if diff > 180 {
			diff = 360 - diff
		}
		totalHeadingDelta += diff
	}
	headingRate := totalHeadingDelta / float64(n-1)

	// Sinuosity (direct distance / total path)
	var totalPath float64
	for i := 0; i < n-1; i++ {
		totalPath += geo.HaversineDistanceMeters(window[i].ToLatLng(), window[i+1].ToLatLng())
	}
	directDist := geo.HaversineDistanceMeters(window[0].ToLatLng(), window[n-1].ToLatLng())
	sinuosity := directDist / (totalPath + 0.01)
	if sinuosity > 1.0 {
		sinuosity = 1.0
	}

	// Stop frequency
	stops := 0
	for _, spd := range speeds {
		if spd < 1.0 {
			stops++
		}
	}
	stopFreq := float64(stops) / float64(n)

	return map[string]float64{
		"avg_speed":    avgSpeed,
		"max_accel":    maxAccel,
		"heading_rate": headingRate,
		"sinuosity":    sinuosity,
		"stop_freq":    stopFreq,
	}
}
