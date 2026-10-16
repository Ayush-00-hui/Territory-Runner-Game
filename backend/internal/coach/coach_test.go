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
	assert.Contains(t, insight.Summary, "conquered 12 new territory sectors")
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
								"text": "```json\n{\"summary\":\"Phenomenal territory conquest through downtown!\",\"tip\":\"Increase recovery hydration and target the north sector next.\",\"moodTag\":\"celebratory\"}\n```",
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
	assert.Equal(t, "Phenomenal territory conquest through downtown!", insight.Summary)
	assert.Equal(t, "Increase recovery hydration and target the north sector next.", insight.Tip)
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

