package coach_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/coach"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCoachFallbackWhenNoKey(t *testing.T) {
	svc := coach.NewService("")
	run := coach.RunContext{
		RunID:           "run_123",
		DistanceKm:      3.5,
		DurationSeconds: 1200,
		HexesClaimed:    4,
		CurrentPace:     "5'42\"/km",
	}

	insight := svc.GenerateInsight(context.Background(), run)
	assert.NotEmpty(t, insight.Summary)
	assert.Contains(t, insight.Summary, "3.50 km")
	assert.NotEmpty(t, insight.Tip)
	assert.Equal(t, "encouraging", insight.MoodTag)
}

func TestCoachFallbackCelebratoryMood(t *testing.T) {
	svc := coach.NewService("")
	run := coach.RunContext{
		RunID:           "run_big",
		DistanceKm:      8.0,
		DurationSeconds: 2400,
		HexesClaimed:    12,
	}

	insight := svc.GenerateInsight(context.Background(), run)
	assert.Equal(t, "celebratory", insight.MoodTag)
	assert.Contains(t, insight.Summary, "claimed 12 new territories")
}

func TestCoachGeminiSuccess(t *testing.T) {
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		// API key must be sent via x-goog-api-key header, NOT URL query!
		assert.Equal(t, "test-gemini-key", r.Header.Get("x-goog-api-key"))
		assert.NotContains(t, r.URL.RawQuery, "key=")
		assert.Contains(t, r.URL.Path, "/v1beta/models/gemini-2.5-flash:generateContent")

		resp := map[string]interface{}{
			"candidates": []map[string]interface{}{
				{
					"content": map[string]interface{}{
						"parts": []map[string]interface{}{
							{
								"text": "```json\n{\"summary\":\"Phenomenal territory run through downtown.\",\"tip\":\"Increase recovery hydration and target the north area next.\",\"moodTag\":\"celebratory\"}\n```",
							},
						},
					},
				},
			},
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer mockServer.Close()

	svc := coach.NewService(
		"test-gemini-key",
		coach.WithBaseURL(mockServer.URL),
		coach.WithHTTPClient(mockServer.Client()),
	)

	run := coach.RunContext{
		RunID:           "run_gemini_01",
		DistanceKm:      4.2,
		DurationSeconds: 1500,
		HexesClaimed:    6,
		CurrentPace:     "5'57\"/km",
	}

	insight := svc.GenerateInsight(context.Background(), run)
	require.NotEmpty(t, insight.Summary)
	assert.Equal(t, "Phenomenal territory run through downtown.", insight.Summary)
	assert.Equal(t, "Increase recovery hydration and target the north area next.", insight.Tip)
	assert.Equal(t, "celebratory", insight.MoodTag)
}

func TestCoachGeminiResilientFallbackOnError(t *testing.T) {
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Server error from Gemini (e.g. 503 or quota limit)
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte(`{"error":{"code":503,"message":"Resource exhausted"}}`))
	}))
	defer mockServer.Close()

	svc := coach.NewService(
		"test-gemini-key",
		coach.WithBaseURL(mockServer.URL),
		coach.WithHTTPClient(mockServer.Client()),
	)

	run := coach.RunContext{
		RunID:           "run_failover",
		DistanceKm:      2.5,
		DurationSeconds: 900,
		HexesClaimed:    2,
	}

	// Must not fail; gracefully falls back to deterministic heuristic
	insight := svc.GenerateInsight(context.Background(), run)
	assert.NotEmpty(t, insight.Summary)
	assert.Contains(t, insight.Summary, "2.50 km")
	assert.NotEmpty(t, insight.Tip)
}

func TestCoachCustomModel(t *testing.T) {
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Contains(t, r.URL.Path, "/v1beta/models/gemini-custom-flash:generateContent")
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"candidates": []map[string]interface{}{
				{
					"content": map[string]interface{}{
						"parts": []map[string]interface{}{
							{
								"text": `{"summary":"Great job!","tip":"Pace well.","moodTag":"analytical"}`,
							},
						},
					},
				},
			},
		})
	}))
	defer mockServer.Close()

	svc := coach.NewService(
		"test-key",
		coach.WithBaseURL(mockServer.URL),
		coach.WithHTTPClient(mockServer.Client()),
		coach.WithModel("gemini-custom-flash"),
	)

	insight := svc.GenerateInsight(context.Background(), coach.RunContext{
		DistanceKm:      5.0,
		DurationSeconds: 1500,
	})
	assert.Equal(t, "Great job!", insight.Summary)
	assert.Equal(t, "analytical", insight.MoodTag)
}

func TestRunContext_JSONAliases(t *testing.T) {
	// 1. Unmarshal legacy hexes_claimed
	var r1 coach.RunContext
	err := json.Unmarshal([]byte(`{"run_id":"r1","distance_km":3.0,"duration_seconds":900,"hexes_claimed":7}`), &r1)
	require.NoError(t, err)
	assert.Equal(t, 7, r1.TerritoriesClaimed)
	assert.Equal(t, 7, r1.HexesClaimed)
	assert.Equal(t, 7, r1.ZonesClaimed)

	// 2. Unmarshal modern territories_claimed
	var r2 coach.RunContext
	err = json.Unmarshal([]byte(`{"run_id":"r2","distance_km":4.0,"duration_seconds":1200,"territories_claimed":9}`), &r2)
	require.NoError(t, err)
	assert.Equal(t, 9, r2.TerritoriesClaimed)
	assert.Equal(t, 9, r2.HexesClaimed)

	// 3. Unmarshal zones_claimed
	var r3 coach.RunContext
	err = json.Unmarshal([]byte(`{"run_id":"r3","distance_km":5.0,"duration_seconds":1500,"zones_claimed":11}`), &r3)
	require.NoError(t, err)
	assert.Equal(t, 11, r3.TerritoriesClaimed)
	assert.Equal(t, 11, r3.HexesClaimed)
}
