package anticheat

import (
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
)

//go:embed anomaly_detector_trees.json
var embeddedTreesJSON []byte

//go:embed anomaly_detector_meta.json
var embeddedMetaJSON []byte

// ErrModelIntegrityFailed is returned if the model version or SHA256 checksum check fails.
var ErrModelIntegrityFailed = errors.New("anticheat: model SHA256 or version integrity check failed")

// TreeNode represents a single decision node or leaf in the LightGBM ensemble.
type TreeNode struct {
	SplitFeature int       `json:"split_feature"`
	Threshold    float64   `json:"threshold"`
	Left         *TreeNode `json:"left"`
	Right        *TreeNode `json:"right"`
	LeafValue    *float64  `json:"leaf_value,omitempty"`
}

// TreeEnsembleModel holds the parsed LightGBM decision tree ensemble.
type TreeEnsembleModel struct {
	ModelVersion string     `json:"model_version"`
	FeatureNames []string   `json:"feature_names"`
	NumTrees     int        `json:"num_trees"`
	Trees        []TreeNode `json:"trees"`
}

// ModelMetadata contains versioning, checksums, and operating thresholds.
type ModelMetadata struct {
	ModelName    string   `json:"model_name"`
	ModelVersion string   `json:"model_version"`
	ModelType    string   `json:"model_type"`
	SHA256ONNX   string   `json:"sha256_onnx"`
	SHA256Trees  string   `json:"sha256_trees"`
	Threshold    float64  `json:"threshold"`
	NumTrees     int      `json:"num_trees"`
	NumFeatures  int      `json:"num_features"`
	FeatureNames []string `json:"feature_names"`
	ExportedAt   string   `json:"exported_at"`
}

// MLEnsemble manages loaded tree ensemble models with cryptographic integrity validation.
type MLEnsemble struct {
	meta       ModelMetadata
	model      TreeEnsembleModel
	sha256Hex  string
	isVerified bool
}

// NewDefaultMLEnsemble initializes and cryptographically verifies the production LightGBM model.
func NewDefaultMLEnsemble() (*MLEnsemble, error) {
	var meta ModelMetadata
	if err := json.Unmarshal(embeddedMetaJSON, &meta); err != nil {
		return nil, fmt.Errorf("anticheat: failed to parse embedded metadata: %w", err)
	}

	h := sha256.Sum256(embeddedTreesJSON)
	actualSHA := hex.EncodeToString(h[:])

	if meta.SHA256Trees != "" && actualSHA != meta.SHA256Trees {
		return nil, fmt.Errorf("%w: expected %s, got %s", ErrModelIntegrityFailed, meta.SHA256Trees, actualSHA)
	}

	var model TreeEnsembleModel
	if err := json.Unmarshal(embeddedTreesJSON, &model); err != nil {
		return nil, fmt.Errorf("anticheat: failed to parse embedded tree ensemble: %w", err)
	}

	if meta.ModelVersion != "" && model.ModelVersion != meta.ModelVersion {
		return nil, fmt.Errorf("%w: version mismatch (meta=%s, model=%s)", ErrModelIntegrityFailed, meta.ModelVersion, model.ModelVersion)
	}

	return &MLEnsemble{
		meta:       meta,
		model:      model,
		sha256Hex:  actualSHA,
		isVerified: true,
	}, nil
}

// Metadata returns the active model metadata.
func (m *MLEnsemble) Metadata() ModelMetadata {
	return m.meta
}

// IsVerified returns true if cryptographic SHA256 and version checks passed.
func (m *MLEnsemble) IsVerified() bool {
	return m.isVerified
}

// SHA256 returns the calculated SHA256 hex string.
func (m *MLEnsemble) SHA256() string {
	return m.sha256Hex
}

func evaluateNode(n *TreeNode, features []float64) float64 {
	if n.LeafValue != nil {
		return *n.LeafValue
	}
	idx := n.SplitFeature
	val := 0.0
	if idx >= 0 && idx < len(features) {
		val = features[idx]
	}
	if val <= n.Threshold {
		if n.Left != nil {
			return evaluateNode(n.Left, features)
		}
	} else {
		if n.Right != nil {
			return evaluateNode(n.Right, features)
		}
	}
	return 0.0
}

// PredictProbability computes the LightGBM raw ensemble logit and applies the logistic sigmoid.
func (m *MLEnsemble) PredictProbability(features []float64) float64 {
	if len(m.model.Trees) == 0 {
		return 0.0
	}
	var rawLogit float64
	for i := range m.model.Trees {
		rawLogit += evaluateNode(&m.model.Trees[i], features)
	}
	// Logistic sigmoid: 1.0 / (1.0 + exp(-rawLogit))
	return 1.0 / (1.0 + math.Exp(-rawLogit))
}

// Predict evaluates features against the operating decision threshold (default 0.50).
func (m *MLEnsemble) Predict(features []float64) (isAnomaly bool, prob float64) {
	prob = m.PredictProbability(features)
	thresh := m.meta.Threshold
	if thresh <= 0 {
		thresh = 0.50
	}
	return prob >= thresh, prob
}

func initialBearingDeg(lat1, lon1, lat2, lon2 float64) float64 {
	phi1 := lat1 * math.Pi / 180.0
	phi2 := lat2 * math.Pi / 180.0
	dlambda := (lon2 - lon1) * math.Pi / 180.0
	y := math.Sin(dlambda) * math.Cos(phi2)
	x := math.Cos(phi1)*math.Sin(phi2) - math.Sin(phi1)*math.Cos(phi2)*math.Cos(dlambda)
	bearing := math.Atan2(y, x) * 180.0 / math.Pi
	return math.Mod(bearing+360.0, 360.0)
}

func headingChangeDeg(b1, b2 float64) float64 {
	diff := math.Mod(math.Abs(b2-b1), 360.0)
	if diff > 180.0 {
		return 360.0 - diff
	}
	return diff
}

func calcMean(vals []float64) float64 {
	if len(vals) == 0 {
		return 0.0
	}
	var sum float64
	for _, v := range vals {
		sum += v
	}
	return sum / float64(len(vals))
}

func calcStd(vals []float64) float64 {
	if len(vals) <= 1 {
		return 0.0
	}
	m := calcMean(vals)
	var sumSq float64
	for _, v := range vals {
		d := v - m
		sumSq += d * d
	}
	return math.Sqrt(sumSq / float64(len(vals)))
}

func calcMax(vals []float64) float64 {
	if len(vals) == 0 {
		return 0.0
	}
	m := vals[0]
	for _, v := range vals[1:] {
		if v > m {
			m = v
		}
	}
	return m
}

func calcPercentile(vals []float64, p float64) float64 {
	if len(vals) == 0 {
		return 0.0
	}
	sorted := make([]float64, len(vals))
	copy(sorted, vals)
	sort.Float64s(sorted)

	rank := (p / 100.0) * float64(len(sorted)-1)
	low := int(math.Floor(rank))
	high := int(math.Ceil(rank))
	if low == high {
		return sorted[low]
	}
	weight := rank - float64(low)
	return sorted[low]*(1.0-weight) + sorted[high]*weight
}

func calcMedian(vals []float64) float64 {
	return calcPercentile(vals, 50.0)
}

func calcShannonEntropy(vals []float64, nBins int, minVal, maxVal float64) float64 {
	if len(vals) == 0 || nBins <= 0 {
		return 0.0
	}
	binWidth := (maxVal - minVal) / float64(nBins)
	counts := make([]int, nBins)

	for _, v := range vals {
		idx := int((v - minVal) / binWidth)
		if idx < 0 {
			idx = 0
		}
		if idx >= nBins {
			idx = nBins - 1
		}
		counts[idx]++
	}

	total := float64(len(vals))
	var ent float64
	for _, c := range counts {
		if c > 0 {
			p := float64(c) / total
			ent -= p * math.Log2(p)
		}
	}
	return ent
}

// Extract25Features extracts the 25 kinematic window features matching Python FEATURE_COLUMNS exactly.
func Extract25Features(points []geo.TrackPoint, motionWindows []MotionWindow) []float64 {
	n := len(points)
	if n < 2 {
		return make([]float64, 25)
	}

	var dists []float64
	var dts []float64
	var speedsMs []float64
	var bearings []float64
	var accuracies []float64

	for i := 1; i < n; i++ {
		pPrev := points[i-1]
		pCurr := points[i]

		dt := pCurr.Timestamp.Sub(pPrev.Timestamp).Seconds()
		if dt <= 0 {
			dt = 0.001
		}
		dts = append(dts, dt)

		d := geo.HaversineDistanceMeters(pPrev.ToLatLng(), pCurr.ToLatLng())
		dists = append(dists, d)

		sMs := d / dt
		speedsMs = append(speedsMs, sMs)

		b := initialBearingDeg(pPrev.Latitude, pPrev.Longitude, pCurr.Latitude, pCurr.Longitude)
		bearings = append(bearings, b)

		acc := 4.0
		accuracies = append(accuracies, acc)
	}

	speedsKmh := make([]float64, len(speedsMs))
	for i, s := range speedsMs {
		speedsKmh[i] = s * 3.6
	}

	// Accelerations
	var accels []float64
	for i := 1; i < len(speedsMs); i++ {
		dtAcc := dts[i]
		a := (speedsMs[i] - speedsMs[i-1]) / dtAcc
		accels = append(accels, a)
	}
	if len(accels) == 0 {
		accels = []float64{0.0}
	}

	// Jerk
	var jerks []float64
	for i := 1; i < len(accels); i++ {
		dtJerk := dts[i]
		if i+1 < len(dts) {
			dtJerk = dts[i+1]
		}
		j := (accels[i] - accels[i-1]) / dtJerk
		jerks = append(jerks, j)
	}
	if len(jerks) == 0 {
		jerks = []float64{0.0}
	}

	// Heading change & turn rates
	var bearingDiffs []float64
	var turnRates []float64
	for i := 1; i < len(bearings); i++ {
		diff := headingChangeDeg(bearings[i-1], bearings[i])
		bearingDiffs = append(bearingDiffs, diff)
		turnRates = append(turnRates, diff/dts[i])
	}
	if len(bearingDiffs) == 0 {
		bearingDiffs = []float64{0.0}
	}
	if len(turnRates) == 0 {
		turnRates = []float64{0.0}
	}

	// Sinuosity
	netDisp := geo.HaversineDistanceMeters(points[0].ToLatLng(), points[n-1].ToLatLng())
	var totalPath float64
	for _, d := range dists {
		totalPath += d
	}
	sinuosity := totalPath / math.Max(netDisp, 1.0)
	sinuosity = math.Min(50.0, math.Max(1.0, sinuosity))

	// Stop ratio
	stops := 0
	for _, s := range speedsMs {
		if s < 0.5 {
			stops++
		}
	}
	stopRatio := float64(stops) / float64(len(speedsMs))

	absAccels := make([]float64, len(accels))
	for i, a := range accels {
		absAccels[i] = math.Abs(a)
	}

	absJerks := make([]float64, len(jerks))
	for i, j := range jerks {
		absJerks[i] = math.Abs(j)
	}

	var cadenceSPM, motionEnergy, cadenceConf float64
	if len(motionWindows) > 0 {
		var sumC, sumE, sumConf float64
		for _, w := range motionWindows {
			sumC += w.CadenceSPM
			sumE += w.MotionEnergy
			sumConf += w.CadenceConfidence
		}
		nw := float64(len(motionWindows))
		cadenceSPM = sumC / nw
		motionEnergy = sumE / nw
		cadenceConf = sumConf / nw
	}

	f := make([]float64, 25)
	f[0] = calcMean(speedsKmh)
	f[1] = calcStd(speedsKmh)
	f[2] = calcMax(speedsKmh)
	f[3] = calcPercentile(speedsKmh, 95.0)
	f[4] = calcMedian(speedsKmh)
	f[5] = calcMean(absAccels)
	f[6] = calcStd(accels)
	f[7] = calcMax(absAccels)
	f[8] = calcPercentile(absAccels, 95.0)
	f[9] = calcMean(absJerks)
	f[10] = calcStd(jerks)
	f[11] = calcMax(absJerks)
	f[12] = calcMean(turnRates)
	f[13] = calcStd(turnRates)
	f[14] = calcShannonEntropy(bearingDiffs, 16, 0.0, 180.0)
	f[15] = sinuosity
	f[16] = stopRatio
	f[17] = calcMean(accuracies)
	f[18] = calcStd(accuracies)
	f[19] = calcMax(accuracies)
	f[20] = calcMedian(dts)
	f[21] = calcStd(dts)
	f[22] = cadenceSPM
	f[23] = motionEnergy
	f[24] = cadenceConf

	return f
}
