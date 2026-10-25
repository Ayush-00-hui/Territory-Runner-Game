package coach

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

// CoachInsight represents the structured coaching feedback for a completed run.
type CoachInsight struct {
	Summary string `json:"summary"`
	Tip     string `json:"tip"`
	MoodTag string `json:"mood_tag"`
}

// RunContext holds the run metrics and runner profile statistics required for coaching.
type RunContext struct {
	RunID              string  `json:"run_id"`
	DistanceKm         float64 `json:"distance_km"`
	DurationSeconds    int     `json:"duration_seconds"`
	TerritoriesClaimed int     `json:"territories_claimed"`
	HexesClaimed       int     `json:"hexes_claimed,omitempty"` // Deprecated JSON alias for backward compatibility
	ZonesClaimed       int     `json:"zones_claimed,omitempty"` // Alias for TerritoriesClaimed
	CurrentPace        string  `json:"current_pace,omitempty"`
	Level              int     `json:"level,omitempty"`
	StreakDays         int     `json:"streak_days,omitempty"`
	TotalDistanceKm    float64 `json:"total_distance_km,omitempty"`
}

// Normalize ensures canonical territories and backward-compatibility aliases stay synchronized.
func (r *RunContext) Normalize() {
	if r.TerritoriesClaimed == 0 {
		if r.ZonesClaimed != 0 {
			r.TerritoriesClaimed = r.ZonesClaimed
		} else if r.HexesClaimed != 0 {
			r.TerritoriesClaimed = r.HexesClaimed
		}
	}
	r.HexesClaimed = r.TerritoriesClaimed
	r.ZonesClaimed = r.TerritoriesClaimed
}

// UnmarshalJSON unmarshals RunContext supporting territories_claimed, zones_claimed, and legacy hexes_claimed.
func (r *RunContext) UnmarshalJSON(data []byte) error {
	type Alias RunContext
	aux := &struct {
		*Alias
	}{
		Alias: (*Alias)(r),
	}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}
	r.Normalize()
	return nil
}

// Service manages post-run coaching insights via Gemini LLM or resilient heuristic fallback.
type Service struct {
	apiKey     string
	model      string
	baseURL    string // default https://generativelanguage.googleapis.com
	httpClient *http.Client
	logger     *slog.Logger
}

// Option configures Service parameters.
type Option func(*Service)

// WithModel sets the Gemini model name.
func WithModel(model string) Option {
	return func(s *Service) {
		if model != "" {
			s.model = model
		}
	}
}

// WithHTTPClient overrides the HTTP client for testing.
func WithHTTPClient(client *http.Client) Option {
	return func(s *Service) {
		s.httpClient = client
	}
}

// WithBaseURL overrides the Gemini API base URL for testing.
func WithBaseURL(url string) Option {
	return func(s *Service) {
		s.baseURL = url
	}
}

// WithLogger sets the structured logger.
func WithLogger(l *slog.Logger) Option {
	return func(s *Service) {
		s.logger = l
	}
}

// NewService creates a new LLM Coach service.
func NewService(apiKey string, opts ...Option) *Service {
	s := &Service{
		apiKey:  apiKey,
		model:   "gemini-2.5-flash",
		baseURL: "https://generativelanguage.googleapis.com",
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger: slog.Default(),
	}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

// GenerateInsight generates tactical coaching advice, delegating to Gemini if configured
// or falling back to on-device equivalent heuristics.
func (s *Service) GenerateInsight(ctx context.Context, run RunContext) CoachInsight {
	if s.apiKey == "" {
		s.logger.Info("Gemini API key not configured; using smart coaching heuristic")
		return s.GenerateFallback(run)
	}

	insight, err := s.callGemini(ctx, run)
	if err != nil {
		s.logger.Warn("Gemini coaching request failed; falling back to heuristic", "error", err)
		return s.GenerateFallback(run)
	}

	return insight
}

// GenerateFallback produces deterministic, high-quality athletic coaching feedback.
func (s *Service) GenerateFallback(run RunContext) CoachInsight {
	paceStr := run.CurrentPace
	if paceStr == "" {
		if run.DistanceKm > 0 && run.DurationSeconds > 0 {
			pace := (float64(run.DurationSeconds) / 60.0) / run.DistanceKm
			pMin := int(pace)
			pSec := int((pace - float64(pMin)) * 60)
			paceStr = fmt.Sprintf("%d'%02d\"/km", pMin, pSec)
		} else {
			paceStr = "6'15\"/km"
		}
	}

	run.Normalize()
	durationMin := float64(run.DurationSeconds) / 60.0
	mood := "encouraging"
	if run.TerritoriesClaimed > 5 {
		mood = "celebratory"
	} else if run.DistanceKm > 5.0 {
		mood = "analytical"
	}

	return CoachInsight{
		Summary: fmt.Sprintf("Strong run. You logged %.2f km in %.1f min and claimed %d new territories/zones.",
			run.DistanceKm, durationMin, run.TerritoriesClaimed),
		Tip: fmt.Sprintf("Pace recorded at %s. Keep your cadence consistent around 170 SPM for optimal energy conservation during multi-zone loops.",
			paceStr),
		MoodTag: mood,
	}
}

// geminiRequest is the payload format expected by the Gemini REST API.
type geminiRequest struct {
	Contents         []geminiContent         `json:"contents"`
	GenerationConfig *geminiGenerationConfig `json:"generationConfig,omitempty"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiGenerationConfig struct {
	ResponseMIMEType string  `json:"responseMimeType,omitempty"`
	Temperature      float64 `json:"temperature,omitempty"`
}

type geminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func (s *Service) callGemini(ctx context.Context, run RunContext) (CoachInsight, error) {
	prompt := fmt.Sprintf(`You are the AI Running & Territory Coach in "Territory Runner".
Analyze this completed run session data:
{
  "distanceKm": %.2f,
  "durationSeconds": %d,
  "durationFormatted": "%.1f min",
  "averagePace": "%s",
  "territoriesClaimedThisRun": %d,
  "runnerLevel": %d,
  "currentStreakDays": %d,
  "totalDistanceLifetimeKm": %.2f
}

Provide a motivational coaching response in STRICT JSON matching this schema:
{
  "summary": "1-2 sentences highlighting performance, distance, and territory expansion achievements.",
  "tip": "1 athletic advice for recovery or pacing on their next route.",
  "moodTag": "celebratory" | "encouraging" | "analytical"
}
Do NOT include markdown wrapping or extra text. Output raw JSON only.`,
		run.DistanceKm,
		run.DurationSeconds,
		float64(run.DurationSeconds)/60.0,
		run.CurrentPace,
		run.TerritoriesClaimed,
		run.Level,
		run.StreakDays,
		run.TotalDistanceKm,
	)

	reqPayload := geminiRequest{
		Contents: []geminiContent{
			{Parts: []geminiPart{{Text: prompt}}},
		},
		GenerationConfig: &geminiGenerationConfig{
			ResponseMIMEType: "application/json",
			Temperature:      0.4,
		},
	}

	bodyBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return CoachInsight{}, fmt.Errorf("failed to marshal Gemini request: %w", err)
	}

	endpoint := fmt.Sprintf("%s/v1beta/models/%s:generateContent", s.baseURL, s.model)

	callCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(callCtx, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return CoachInsight{}, fmt.Errorf("failed to create http request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("x-goog-api-key", s.apiKey)

	resp, err := s.httpClient.Do(httpReq)
	if err != nil {
		return CoachInsight{}, fmt.Errorf("gemini network error: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return CoachInsight{}, fmt.Errorf("failed to read gemini response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return CoachInsight{}, fmt.Errorf("gemini returned status %d: %s", resp.StatusCode, string(respBytes))
	}

	var geminiResp geminiResponse
	if err := json.Unmarshal(respBytes, &geminiResp); err != nil {
		return CoachInsight{}, fmt.Errorf("failed to unmarshal gemini response: %w", err)
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return CoachInsight{}, fmt.Errorf("empty candidates in gemini response")
	}

	rawText := strings.TrimSpace(geminiResp.Candidates[0].Content.Parts[0].Text)
	// Strip markdown fencing if present
	if strings.HasPrefix(rawText, "```json") {
		rawText = strings.TrimPrefix(rawText, "```json")
	} else if strings.HasPrefix(rawText, "```") {
		rawText = strings.TrimPrefix(rawText, "```")
	}
	if strings.HasSuffix(rawText, "```") {
		rawText = strings.TrimSuffix(rawText, "```")
	}
	rawText = strings.TrimSpace(rawText)

	var parsed struct {
		Summary string `json:"summary"`
		Tip     string `json:"tip"`
		MoodTag string `json:"moodTag"`
		Mood_   string `json:"mood_tag"`
	}

	if err := json.Unmarshal([]byte(rawText), &parsed); err != nil {
		return CoachInsight{}, fmt.Errorf("failed to parse coach JSON from gemini: %w (raw: %s)", err, rawText)
	}

	mood := parsed.MoodTag
	if mood == "" {
		mood = parsed.Mood_
	}
	if mood == "" {
		mood = "encouraging"
	}

	if parsed.Summary == "" || parsed.Tip == "" {
		return CoachInsight{}, fmt.Errorf("missing summary or tip in gemini output")
	}

	return CoachInsight{
		Summary: parsed.Summary,
		Tip:     parsed.Tip,
		MoodTag: strings.ToLower(mood),
	}, nil
}
