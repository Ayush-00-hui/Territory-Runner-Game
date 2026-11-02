package anticheat_test

import (
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/anticheat"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/geo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNoBannedJargonInServerMessages(t *testing.T) {
	banned := []string{"telemetry", "cyber", "syndicate", "vanguard", "sovereign", "tactical", "sector"}
	bannedRe := regexp.MustCompile(`(?i)\b(` + strings.Join(banned, "|") + `)\b`)

	// 1. Evaluate detector reasons for empty GPS
	d := anticheat.NewDetector()
	emptyRes := d.EvaluateTrackWithMotion(nil, "running", 0, 0, nil)
	for _, reason := range emptyRes.Reasons {
		assert.False(t, bannedRe.MatchString(reason), "Detector reason contains banned jargon: %q", reason)
	}

	// 2. Evaluate detector reasons for implausible motion
	badWindows := []anticheat.MotionWindow{
		{DurationSeconds: 5, CadenceSPM: 500, MotionEnergy: 10, CadenceConfidence: 0.9},
	}
	motionRes := d.EvaluateTrackWithMotion([]geo.TrackPoint{
		{Latitude: 51.5, Longitude: -0.12},
		{Latitude: 51.501, Longitude: -0.121},
	}, "running", 10, 100, badWindows)
	for _, reason := range motionRes.Reasons {
		assert.False(t, bannedRe.MatchString(reason), "Detector reason contains banned jargon: %q", reason)
	}

	// 3. Scan all Go string literals in backend/internal (excluding tests)
	fset := token.NewFileSet()
	var violations []string

	err := filepath.Walk("..", func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}

		node, parseErr := parser.ParseFile(fset, path, nil, parser.ParseComments)
		if parseErr != nil {
			return parseErr
		}

		// Inspect all basic literals
		for _, lit := range node.Comments {
			_ = lit // Comments checked separately if needed
		}

		// Check string literals in file source
		content, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}

		strRe := regexp.MustCompile(`"([^"\\]|\\.)*"|` + "`" + `[^` + "`" + `]*` + "`")
		matches := strRe.FindAllString(string(content), -1)
		for _, m := range matches {
			if bannedRe.MatchString(m) {
				violations = append(violations, path+": "+m)
			}
		}

		return nil
	})

	require.NoError(t, err)
	assert.Empty(t, violations, "Found banned jargon in backend string literals: %v", violations)
}
