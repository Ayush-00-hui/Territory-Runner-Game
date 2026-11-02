package anticheat

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

//go:embed model.json
var embeddedModelJSON []byte

type modelConfigJSON struct {
	ModelType        string    `json:"model_type"`
	Means            []float64 `json:"means"`
	Stds             []float64 `json:"stds"`
	FeatureWeights   []float64 `json:"feature_weights"`
	AnomalyThreshold float64   `json:"anomaly_threshold"`
	HardRules        struct {
		MaxHumanSpeedKmh float64 `json:"max_human_speed_kmh"`
		MaxTeleportSpeed float64 `json:"max_teleport_speed_kmh"`
		MaxAcceleration  float64 `json:"max_acceleration_ms2"`
	} `json:"hard_rules"`
}

// SanitizeStd floors a standard deviation at a sane minimum:
// max(std, 0.05*|mean|, feature-specific epsilon).
// For stop_frequency (index 4) the minimum epsilon is 0.05; never 0.0001.
func SanitizeStd(featureIndex int, rawStd, mean float64) float64 {
	floor := 0.05 * math.Abs(mean)
	minEps := 0.01
	if featureIndex == 4 { // stop_frequency
		minEps = 0.05
	}
	if floor < minEps {
		floor = minEps
	}
	if rawStd < floor {
		return floor
	}
	return rawStd
}

// MotionWindow represents an on-device aggregated 10-second motion sensor analysis window.
type MotionWindow struct {
	StartTime         time.Time `json:"start_time"`
	DurationSeconds   float64   `json:"duration_seconds"`
	CadenceSPM        float64   `json:"cadence_spm"`
	MotionEnergy      float64   `json:"motion_energy"`
	CadenceConfidence float64   `json:"cadence_confidence"`
}

// Verification Status constants
const (
	VerificationStatusVerifiedHuman    = "verified_human"
	VerificationStatusUnverifiedMotion = "unverified_motion"
	VerificationStatusRejected         = "rejected"
)

// MotionSanityReport captures the server-side audit of client-supplied motion windows.
type MotionSanityReport struct {
	Valid            bool     `json:"valid"`
	WindowCount      int      `json:"window_count"`
	TotalDurationSec float64  `json:"total_duration_sec"`
	Issues           []string `json:"issues,omitempty"`
}

// Result captures the evaluation of GPS anomaly detection and spoofing mitigation.
type Result struct {
	IsAnomaly          bool               `json:"is_anomaly"`
	VerificationStatus string             `json:"verification_status"`
	Score              float64            `json:"score"`
	Reasons            []string           `json:"reasons"`
	Features           map[string]float64 `json:"features,omitempty"`
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
	EnableMLTier2    bool
	Means            [5]float64
	Stds             [5]float64
	Weights          [5]float64
}

// DefaultConfig loads calibrated baseline statistics and thresholds dynamically
// from embedded model.json (synced from assets/models/gps_anomaly_detector.json).
func DefaultConfig() Config {
	var m modelConfigJSON
	if err := json.Unmarshal(embeddedModelJSON, &m); err != nil {
		panic(fmt.Sprintf("anticheat: failed to parse embedded model.json: %v", err))
	}

	cfg := Config{
		AnomalyThreshold: m.AnomalyThreshold,
		MaxHumanSpeedKmh: m.HardRules.MaxHumanSpeedKmh,
		MaxTeleportSpeed: m.HardRules.MaxTeleportSpeed,
		// Tier 2 ML cadence model is disabled by default until the threshold of real team traces
		// (min 30 validated traces) is met, preventing false positives from leaked synthetic cadence.
		EnableMLTier2: false,
	}
	if cfg.MaxHumanSpeedKmh <= 0 {
		cfg.MaxHumanSpeedKmh = 25.0
	}
	if cfg.MaxTeleportSpeed <= 0 {
		cfg.MaxTeleportSpeed = 35.0
	}
	if cfg.AnomalyThreshold <= 0 {
		cfg.AnomalyThreshold = 1.8
	}

	for i := 0; i < 5 && i < len(m.Means); i++ {
		cfg.Means[i] = m.Means[i]
	}
	for i := 0; i < 5 && i < len(m.FeatureWeights); i++ {
		cfg.Weights[i] = m.FeatureWeights[i]
	}
	for i := 0; i < 5 && i < len(m.Stds); i++ {
		cfg.Stds[i] = SanitizeStd(i, m.Stds[i], cfg.Means[i])
	}

	return cfg
}

// Detector implements GPS anomaly detection and spoofing mitigation.
type Detector struct {
	cfg        Config
	mlEnsemble *MLEnsemble
}

var mlFallbackLogOnce sync.Once

// ResetMLFallbackLogOnce resets the logging guard (used in testing).
func ResetMLFallbackLogOnce() {
	mlFallbackLogOnce = sync.Once{}
}

// NewDetector creates an anomaly detector instance.
// If the ML ensemble fails to load or fails its cryptographic checksum check,
// the detector safely falls back to deterministic Tier 1 physical rules without crashing and logs a warning once.
func NewDetector(cfg ...Config) *Detector {
	c := DefaultConfig()
	if len(cfg) > 0 {
		c = cfg[0]
	}
	ensemble, err := NewDefaultMLEnsemble()
	if err != nil {
		mlFallbackLogOnce.Do(func() {
			log.Printf("[anticheat] WARNING: ML Tier 2 model failed to load or checksum failed: %v. Falling back to deterministic Tier 1 physical rules safely.", err)
		})
		ensemble = nil
	}
	return &Detector{cfg: c, mlEnsemble: ensemble}
}

// NewDetectorWithEnsemble creates a detector instance with an explicitly supplied ML ensemble (can be nil).
func NewDetectorWithEnsemble(ensemble *MLEnsemble, cfg ...Config) *Detector {
	c := DefaultConfig()
	if len(cfg) > 0 {
		c = cfg[0]
	}
	return &Detector{cfg: c, mlEnsemble: ensemble}
}

// Config returns a copy of the detector's active configuration.
func (d *Detector) Config() Config {
	return d.cfg
}

// MLEnsemble returns the active verified LightGBM ensemble if loaded.
func (d *Detector) MLEnsemble() *MLEnsemble {
	return d.mlEnsemble
}

// ScoreFeatureVector computes the normalized weighted Z-score for a 5-element feature vector,
// capping each per-feature |z| at 6.0 so no single feature can dominate the score.
func (d *Detector) ScoreFeatureVector(fVector [5]float64) float64 {
	var weightedScore float64
	for i := 0; i < 5; i++ {
		z := math.Abs((fVector[i] - d.cfg.Means[i]) / d.cfg.Stds[i])
		if z > 6.0 {
			z = 6.0
		}
		weightedScore += z * d.cfg.Weights[i]
	}
	return weightedScore / 7.5
}

// EvaluateTrack evaluates a sequence of GPS breadcrumbs for potential spoofing or physics violations assuming running.
func (d *Detector) EvaluateTrack(points []geo.TrackPoint) Result {
	return d.EvaluateTrackWithMetrics(points, "running", 0, 0)
}

// EvaluateTrackWithActivity evaluates GPS points against activity-specific speed and kinematics limits.
func (d *Detector) EvaluateTrackWithActivity(points []geo.TrackPoint, activityType string) Result {
	return d.EvaluateTrackWithMetrics(points, activityType, 0, 0)
}

// EvaluateTrackWithMetrics evaluates GPS points against activity-specific limits and cross-checks declared metrics (backward compatible).
func (d *Detector) EvaluateTrackWithMetrics(points []geo.TrackPoint, activityType string, declaredDuration int, declaredDistance float64) Result {
	return d.EvaluateTrackWithMotion(points, activityType, declaredDuration, declaredDistance, nil)
}

// SanityCheckMotionWindows inspects client-provided accelerometer windows for physical plausibility.
// It detects:
// 1. Duration Inflation: Total motion window duration exceeding run duration by > 15% (+15s grace for window rounding).
// 2. Individual Window Duration: Non-positive or excessive duration (< 2s or > 30s).
// 3. Sensor Bounds Violations: Cadence < 0 or > 300 SPM, Motion Energy < 0 or > 50.0, Confidence not in [0, 1].
// 4. Bot / Static Injector Patterns: Exactly identical cadence & motion energy repeated identically across >= 5 windows.
// 5. Non-monotonic window timestamps (when StartTime is provided).
func SanityCheckMotionWindows(windows []MotionWindow, runDurationSec float64) MotionSanityReport {
	report := MotionSanityReport{
		Valid:       true,
		WindowCount: len(windows),
	}
	if len(windows) == 0 {
		return report
	}

	var totalWinSec float64
	var prevStartTime time.Time
	identicalCadenceCount := 1
	identicalEnergyCount := 1

	for i, w := range windows {
		winDur := w.DurationSeconds
		if winDur <= 0 {
			winDur = 10.0
		}
		if winDur < 2.0 || winDur > 30.0 {
			report.Valid = false
			report.Issues = append(report.Issues, fmt.Sprintf("window %d: duration %.1fs out of plausible range [2s, 30s]", i, winDur))
		}
		totalWinSec += winDur

		// Value bounds
		if w.CadenceSPM < 0.0 || w.CadenceSPM > 300.0 {
			report.Valid = false
			report.Issues = append(report.Issues, fmt.Sprintf("window %d: cadence %.1f SPM out of physical human bounds [0, 300]", i, w.CadenceSPM))
		}
		if w.MotionEnergy < 0.0 || w.MotionEnergy > 50.0 {
			report.Valid = false
			report.Issues = append(report.Issues, fmt.Sprintf("window %d: motion energy %.3f out of physical bounds [0, 50]", i, w.MotionEnergy))
		}
		if w.CadenceConfidence < 0.0 || w.CadenceConfidence > 1.0 {
			report.Valid = false
			report.Issues = append(report.Issues, fmt.Sprintf("window %d: cadence confidence %.2f out of bounds [0, 1]", i, w.CadenceConfidence))
		}

		// Timestamp monotonicity
		if !w.StartTime.IsZero() {
			if !prevStartTime.IsZero() && w.StartTime.Before(prevStartTime) {
				report.Valid = false
				report.Issues = append(report.Issues, fmt.Sprintf("window %d: non-monotonic start time (%v before %v)", i, w.StartTime, prevStartTime))
			}
			prevStartTime = w.StartTime
		}

		// Check for static/frozen values (bot/injector check)
		if i > 0 {
			prevW := windows[i-1]
			if math.Abs(w.CadenceSPM-prevW.CadenceSPM) < 1e-6 {
				identicalCadenceCount++
			}
			if math.Abs(w.MotionEnergy-prevW.MotionEnergy) < 1e-6 {
				identicalEnergyCount++
			}
		}
	}

	report.TotalDurationSec = totalWinSec

	// Duration inflation check: if runDurationSec is known (> 0)
	if runDurationSec > 0 {
		maxAllowedMotionDuration := runDurationSec*1.15 + 15.0
		if totalWinSec > maxAllowedMotionDuration {
			report.Valid = false
			report.Issues = append(report.Issues, fmt.Sprintf("total motion duration (%.1fs) exceeds run duration (%.1fs) by > 15%%", totalWinSec, runDurationSec))
		}
	}

	// Repeated identical values: e.g. >= 5 windows with exact same cadence and energy
	if len(windows) >= 5 && identicalCadenceCount == len(windows) && identicalEnergyCount == len(windows) && windows[0].CadenceSPM > 0 {
		report.Valid = false
		report.Issues = append(report.Issues, fmt.Sprintf("bot/synthetic injector signature: %d consecutive windows with bit-for-bit identical cadence (%.2f SPM) and motion energy", len(windows), windows[0].CadenceSPM))
	}

	return report
}

// EvaluateTrackWithMotion evaluates GPS points, declared metrics, and optional accelerometer cadence/motion windows.
func (d *Detector) EvaluateTrackWithMotion(points []geo.TrackPoint, activityType string, declaredDuration int, declaredDistance float64, motionWindows []MotionWindow) Result {
	if len(points) == 0 {
		return Result{
			IsAnomaly:          false,
			VerificationStatus: VerificationStatusUnverifiedMotion,
			Score:              0.0,
			Reasons:            []string{"Empty GPS data"},
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

	// 1. OS Mock Location Indicator (Immediate critical flag)
	for _, pt := range points {
		if pt.IsMocked {
			return Result{
				IsAnomaly:          true,
				VerificationStatus: VerificationStatusRejected,
				Score:              99.0,
				Reasons:            []string{"Mock location provider detected"},
				Features:           map[string]float64{"is_mocked": 1.0},
			}
		}
	}

	// 2. Zero / Missing Timestamps Check
	hasZeroTimestamp := false
	for _, pt := range points {
		if pt.Timestamp.IsZero() {
			hasZeroTimestamp = true
			break
		}
	}
	if hasZeroTimestamp {
		if maxScore < 55.0 {
			maxScore = 55.0
		}
		reasons = append(reasons, "Missing or zero GPS timestamp detected in track points")
	}

	// 3. Sparse Sampling Rule (median dt > 5s)
	if len(points) >= 2 && !hasZeroTimestamp {
		dts := make([]float64, 0, len(points)-1)
		for i := 1; i < len(points); i++ {
			dt := math.Abs(points[i].Timestamp.Sub(points[i-1].Timestamp).Seconds())
			dts = append(dts, dt)
		}
		sort.Float64s(dts)
		var medianDt float64
		mid := len(dts) / 2
		if len(dts)%2 == 1 {
			medianDt = dts[mid]
		} else {
			medianDt = (dts[mid-1] + dts[mid]) / 2.0
		}
		if medianDt > 5.0 {
			ruleScore := 55.0 + (medianDt - 5.0)
			if ruleScore > maxScore {
				maxScore = ruleScore
			}
			reasons = append(reasons, fmt.Sprintf("Sparse GPS sampling detected: median interval %.1fs exceeds 5.0s ceiling", medianDt))
		}
	}

	// 4. Consecutive Segments Kinematics & Speed Evaluation
	// Stop trusting client-reported speed: compute segment speed from haversine distance / dt using server-parsed timestamps.
	for i := 0; i < len(points); i++ {
		pt := points[i]

		// Instantaneous speed check on reported speed (for single-point or standalone violation)
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

		if i > 0 && !hasZeroTimestamp {
			prev := points[i-1]
			dt := math.Abs(pt.Timestamp.Sub(prev.Timestamp).Seconds())
			distMeters := geo.HaversineDistanceMeters(prev.ToLatLng(), pt.ToLatLng())

			if dt == 0 && distMeters > 0 {
				ruleScore := 55.0
				if ruleScore > maxScore {
					maxScore = ruleScore
				}
				reasons = append(reasons, fmt.Sprintf("Position teleportation jump detected: %.1fm displacement in 0.0s", distMeters))
			} else if dt > 0 {
				computedSpeedMps := distMeters / dt
				computedSpeedKmh := computedSpeedMps * 3.6

				// Apply speed-ceiling rule to ALL consecutive points, not just dt <= 3s
				if dt <= 3.0 {
					// Teleportation jumps
					if computedSpeedKmh > limits.MaxTeleportSpeed || (distMeters > 50.0 && dt <= 1.0) {
						ruleScore := 55.0
						if ruleScore > maxScore {
							maxScore = ruleScore
						}
						reasons = append(reasons, fmt.Sprintf("Position teleportation jump detected: %.1fm in %.1fs (%.1f km/h)", distMeters, dt, computedSpeedKmh))
					} else if computedSpeedKmh > limits.MaxInstantSpeedKmh {
						ruleScore := 55.0 + (computedSpeedKmh - limits.MaxInstantSpeedKmh)
						if ruleScore > maxScore {
							maxScore = ruleScore
						}
						if activityType == "running" {
							reasons = append(reasons, fmt.Sprintf("Computed segment speed %.1f km/h exceeds human running ceiling (%.1f km/h); cycling or vehicle suspected", computedSpeedKmh, limits.MaxInstantSpeedKmh))
						} else {
							reasons = append(reasons, fmt.Sprintf("Computed segment speed %.1f km/h exceeds %s ceiling (%.1f km/h)", computedSpeedKmh, activityType, limits.MaxInstantSpeedKmh))
						}
					}
					// Biomechanical acceleration ceiling check
					if dt > 0.2 {
						dv := math.Abs(pt.Speed - prev.Speed)
						accel := dv / dt
						maxAccelLimit := 8.0
						if activityType == "cycling" {
							maxAccelLimit = 12.0
						}
						if accel > maxAccelLimit {
							ruleScore := 45.0 + (accel - maxAccelLimit)
							if ruleScore > maxScore {
								maxScore = ruleScore
							}
							reasons = append(reasons, fmt.Sprintf("Biomechanical acceleration limit exceeded: %.2f m/s² (max %.1f m/s² for %s)", accel, maxAccelLimit, activityType))
						}
					}
				} else {
					// For dt > 3s, compute average segment speed and flag if it exceeds activity endurance ceiling
					if computedSpeedKmh > limits.MaxAverageSpeedKmh {
						ruleScore := 55.0 + (computedSpeedKmh - limits.MaxAverageSpeedKmh)
						if ruleScore > maxScore {
							maxScore = ruleScore
						}
						if activityType == "running" {
							reasons = append(reasons, fmt.Sprintf("Segment average speed %.1f km/h over %.1fs exceeds human running endurance ceiling (%.1f km/h); cycling or vehicle suspected", computedSpeedKmh, dt, limits.MaxAverageSpeedKmh))
						} else {
							reasons = append(reasons, fmt.Sprintf("Segment average speed %.1f km/h over %.1fs exceeds %s endurance ceiling (%.1f km/h)", computedSpeedKmh, dt, activityType, limits.MaxAverageSpeedKmh))
						}
					}
				}

				// Cross-check reported speed vs computed segment speed: flag large mismatch (> 15 km/h)
				reportedKmh := pt.Speed * 3.6
				if pt.Speed > 0 && math.Abs(computedSpeedKmh-reportedKmh) > 15.0 {
					ruleScore := 55.0 + (math.Abs(computedSpeedKmh-reportedKmh) - 15.0)
					if ruleScore > maxScore {
						maxScore = ruleScore
					}
					reasons = append(reasons, fmt.Sprintf("Speed mismatch: reported %.1f km/h vs computed %.1f km/h (>15 km/h difference)", reportedKmh, computedSpeedKmh))
				}
			}
		}
	}

	// 5. Identical-step GPS replay detection
	if len(points) >= 4 {
		identicalSteps := 0
		for i := 1; i < len(points); i++ {
			p1 := points[i-1]
			p2 := points[i]
			if p1.Latitude == p2.Latitude && p1.Longitude == p2.Longitude {
				identicalSteps++
			}
		}
		if identicalSteps >= len(points)/2 {
			reasons = append(reasons, "Excessive frozen/replay identical GPS breadcrumbs detected")
			if maxScore < 5.0 {
				maxScore = 5.0
			}
		}
	}

	// 6. Cross-check declared duration and distance against GPS track (flag if > 10% mismatch)
	if declaredDuration > 0 && len(points) >= 2 && !hasZeroTimestamp {
		firstTs := points[0].Timestamp
		lastTs := points[len(points)-1].Timestamp
		computedDur := math.Abs(lastTs.Sub(firstTs).Seconds())
		if computedDur > 0 {
			diff := math.Abs(float64(declaredDuration) - computedDur)
			if diff/computedDur > 0.10 {
				if maxScore < 25.0 {
					maxScore = 25.0
				}
				reasons = append(reasons, fmt.Sprintf("Duration mismatch: declared %ds vs GPS span %.1fs (>10%% difference)", declaredDuration, computedDur))
			}
		}
	}

	if declaredDistance > 0 && len(points) >= 2 {
		var summedDist float64
		for i := 1; i < len(points); i++ {
			summedDist += geo.HaversineDistanceMeters(points[i-1].ToLatLng(), points[i].ToLatLng())
		}
		if summedDist > 0 {
			diff := math.Abs(declaredDistance - summedDist)
			if diff/summedDist > 0.10 {
				if maxScore < 25.0 {
					maxScore = 25.0
				}
				reasons = append(reasons, fmt.Sprintf("Distance mismatch: declared %.1fm vs GPS path %.1fm (>10%% difference)", declaredDistance, summedDist))
			}
		}
	}

	features := d.extractFeatures(points)

	// 7. Sustained average speed ceiling check
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
			Features:  features,
		}
	}

	// 8. Calibrated Multi-Feature Weighted Z-Score Scoring (Running Baseline)
	if activityType == "running" && !hasZeroTimestamp {
		fVector := [5]float64{
			features["avg_speed"],
			features["max_accel"],
			features["heading_rate"],
			features["sinuosity"],
			features["stop_freq"],
		}

		normalizedScore := d.ScoreFeatureVector(fVector)

		if normalizedScore > maxScore {
			maxScore = normalizedScore
		}

		if normalizedScore > d.cfg.AnomalyThreshold {
			reasons = append(reasons, fmt.Sprintf("Unnatural movement pattern (Z-Score: %.2f > %.2f)", normalizedScore, d.cfg.AnomalyThreshold))
		}
	}

	// 9. Accelerometer Cadence & Motion Energy Validation
	runDurationSec := float64(declaredDuration)
	if runDurationSec <= 0 && len(points) >= 2 && !hasZeroTimestamp {
		runDurationSec = math.Abs(points[len(points)-1].Timestamp.Sub(points[0].Timestamp).Seconds())
	}

	motionWindowsValid := false
	if len(motionWindows) > 0 {
		sanity := SanityCheckMotionWindows(motionWindows, runDurationSec)
		if !sanity.Valid {
			features["motion_sanity_valid"] = 0.0
			for _, issue := range sanity.Issues {
				reasons = append(reasons, fmt.Sprintf("Implausible motion data: %s", issue))
			}
		} else {
			features["motion_sanity_valid"] = 1.0
			motionWindowsValid = true
			var sumCadence, sumEnergy, sumConfidence float64
			for _, w := range motionWindows {
				sumCadence += w.CadenceSPM
				sumEnergy += w.MotionEnergy
				sumConfidence += w.CadenceConfidence
			}
			numW := float64(len(motionWindows))
			features["cadence_spm"] = sumCadence / numW
			features["motion_energy"] = sumEnergy / numW
			features["cadence_confidence"] = sumConfidence / numW

			// Rule: GPS speed > 6 km/h with near-zero cadence (< 35 SPM) and low motion energy (< 0.25) for > 30s => strong vehicle signal.
			// Handle cycling separately: pedalling cadence is lower and coasting on bike is normal, but highway cruising lacks road vibration.
			sustainedVehicleSec := 0.0
			sustainedVehicleSpeed := 0.0

			for _, w := range motionWindows {
				winDuration := w.DurationSeconds
				if winDuration <= 0 {
					winDuration = 10.0
				}

				// Estimate GPS speed corresponding to this window
				gpsSpeedKmh := 0.0
				if len(points) >= 2 && !w.StartTime.IsZero() {
					wEnd := w.StartTime.Add(time.Duration(winDuration * float64(time.Second)))
					var winPts []geo.TrackPoint
					for _, pt := range points {
						if !pt.Timestamp.IsZero() && (pt.Timestamp.Equal(w.StartTime) || pt.Timestamp.After(w.StartTime)) && (pt.Timestamp.Equal(wEnd) || pt.Timestamp.Before(wEnd)) {
							winPts = append(winPts, pt)
						}
					}
					if len(winPts) >= 2 {
						var dMeters float64
						for j := 1; j < len(winPts); j++ {
							dMeters += geo.HaversineDistanceMeters(winPts[j-1].ToLatLng(), winPts[j].ToLatLng())
						}
						dtSec := math.Abs(winPts[len(winPts)-1].Timestamp.Sub(winPts[0].Timestamp).Seconds())
						if dtSec > 0 {
							gpsSpeedKmh = (dMeters / dtSec) * 3.6
						}
					}
				}

				// Fallback: If point timestamps don't align with window timestamps, use overall run speed or avg_speed feature
				if gpsSpeedKmh == 0.0 {
					if declaredDuration > 0 && declaredDistance > 0 {
						gpsSpeedKmh = (declaredDistance / float64(declaredDuration)) * 3.6
					} else if s, ok := features["avg_speed"]; ok {
						gpsSpeedKmh = s
					}
				}

				if activityType == "cycling" {
					// Cycling: Coasting is permitted at normal cycling speeds (6-25 km/h).
					// Only flag if moving at high vehicle cruising speed (> 25 km/h) with zero cadence (< 15 RPM)
					// AND almost zero vibration (< 0.05 m^2/s^4) for > 60s, or speed > 45 km/h.
					if gpsSpeedKmh > 25.0 && w.CadenceSPM < 15.0 && w.MotionEnergy < 0.05 {
						sustainedVehicleSec += winDuration
						sustainedVehicleSpeed = math.Max(sustainedVehicleSpeed, gpsSpeedKmh)
					} else {
						sustainedVehicleSec = 0.0
					}

					if sustainedVehicleSec >= 60.0 {
						ruleScore := 75.0 + (sustainedVehicleSpeed - 25.0)
						if ruleScore > maxScore {
							maxScore = ruleScore
						}
						reasons = append(reasons, fmt.Sprintf("Strong vehicle signal in cycling mode: GPS speed %.1f km/h with zero pedaling cadence (< 15 rpm) and zero road vibration (energy %.3f) sustained for %.0fs", sustainedVehicleSpeed, w.MotionEnergy, sustainedVehicleSec))
						break
					}
				} else {
					// Running & Walking: Human locomotion at > 6 km/h physically requires cadence (>= 35 spm) and motion energy (>= 0.25 m^2/s^4).
					if gpsSpeedKmh > 6.0 && w.CadenceSPM < 35.0 && w.MotionEnergy < 0.25 {
						sustainedVehicleSec += winDuration
						sustainedVehicleSpeed = math.Max(sustainedVehicleSpeed, gpsSpeedKmh)
					} else {
						sustainedVehicleSec = 0.0
					}

					if sustainedVehicleSec >= 30.0 {
						ruleScore := 75.0 + (sustainedVehicleSpeed - 6.0)
						if ruleScore > maxScore {
							maxScore = ruleScore
						}
						reasons = append(reasons, fmt.Sprintf("Strong vehicle signal: GPS speed > 6 km/h (%.1f km/h) with near-zero cadence (%.1f spm) and low motion energy (%.3f) sustained for %.0fs", sustainedVehicleSpeed, w.CadenceSPM, w.MotionEnergy, sustainedVehicleSec))
						break
					}
				}
			}
		}
	} else {
		features["motion_sanity_valid"] = 0.0
		features["has_motion_windows"] = 0.0
	}

	// 10. Tier 2: Production LightGBM Machine Learning Ensemble Model
	// Only evaluated if:
	// - Tier 1 hard physics rules did not already trigger a high-severity rejection (score >= 50.0)
	// - ML Tier 2 is enabled by feature flag
	// - Motion windows are present and passed server-side sanity checks
	if d.cfg.EnableMLTier2 && d.mlEnsemble != nil && len(points) >= 3 && motionWindowsValid {
		if maxScore < 50.0 {
			f25 := Extract25Features(points, motionWindows)
			isMLAnomaly, mlProb := d.mlEnsemble.Predict(f25)
			features["ml_anomaly_prob"] = mlProb

			if isMLAnomaly {
				mlScore := 55.0 + (mlProb * 35.0)
				if mlScore > maxScore {
					maxScore = mlScore
				}
				reasons = append(reasons, fmt.Sprintf("Tier 2 ML Anomaly Detector: vehicular/unnatural kinematics detected (probability: %.3f, model_version: %s)", mlProb, d.mlEnsemble.meta.ModelVersion))
			}
		}
	}

	isAnomaly := maxScore > d.cfg.AnomalyThreshold
	var verificationStatus string
	if isAnomaly {
		if maxScore >= 50.0 {
			verificationStatus = VerificationStatusRejected
		} else {
			verificationStatus = VerificationStatusUnverifiedMotion
		}
	} else if len(motionWindows) == 0 || !motionWindowsValid {
		// Runs without motion windows or with implausible motion data are never marked verified_human
		verificationStatus = VerificationStatusUnverifiedMotion
	} else {
		verificationStatus = VerificationStatusVerifiedHuman
	}

	return Result{
		IsAnomaly:          isAnomaly,
		VerificationStatus: verificationStatus,
		Score:              maxScore,
		Reasons:            reasons,
		Features:           features,
	}
}

func (d *Detector) extractFeatures(window []geo.TrackPoint) map[string]float64 {
	n := len(window)
	if n == 0 {
		return map[string]float64{}
	}

	var sumSpeed float64
	speeds := make([]float64, n)
	var totalPath float64
	for i, p := range window {
		spd := p.Speed * 3.6
		if i > 0 {
			dist := geo.HaversineDistanceMeters(window[i-1].ToLatLng(), p.ToLatLng())
			totalPath += dist
			if spd == 0 {
				dt := math.Abs(p.Timestamp.Sub(window[i-1].Timestamp).Seconds())
				if dt > 0 {
					spd = (dist / dt) * 3.6
				}
			}
		}
		speeds[i] = spd
		sumSpeed += spd
	}
	avgSpeed := sumSpeed / float64(n)

	// Max acceleration
	var maxAccel float64
	for i := 0; i < n-1; i++ {
		dt := math.Abs(window[i+1].Timestamp.Sub(window[i].Timestamp).Seconds())
		if dt > 0 && !window[i].Timestamp.IsZero() && !window[i+1].Timestamp.IsZero() {
			dv := math.Abs((speeds[i+1] - speeds[i]) / 3.6)
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
	headingRate := 0.0
	if n > 1 {
		headingRate = totalHeadingDelta / float64(n-1)
	}

	// Sinuosity (direct distance / total path)
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
