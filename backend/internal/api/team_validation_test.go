package api

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/auth"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/config"
	"github.com/Ayush-00-hui/Territory-Runner-Game/backend/internal/store"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestValidateTeamName_Table(t *testing.T) {
	tests := []struct {
		name          string
		input         string
		denyList      []string
		wantErr       bool
		errContains   string
		wantDisplay   string
		wantCanonical string
	}{
		// Valid cases
		{
			name:          "standard valid team",
			input:         "Cyber Vanguard",
			wantDisplay:   "Cyber Vanguard",
			wantCanonical: "cyber vanguard",
		},
		{
			name:          "trim and collapse repeated spaces",
			input:         "   Solaris    Nomads   ",
			wantDisplay:   "Solaris Nomads",
			wantCanonical: "solaris nomads",
		},
		{
			name:          "parity between Team A and team  a",
			input:         "team  a",
			wantDisplay:   "team a",
			wantCanonical: "team a",
		},
		{
			name:          "hyphens and underscores allowed",
			input:         "Iron-Legion_99",
			wantDisplay:   "Iron-Legion_99",
			wantCanonical: "iron-legion_99",
		},
		{
			name:          "min length exactly 3 characters",
			input:         "ABC",
			wantDisplay:   "ABC",
			wantCanonical: "abc",
		},
		{
			name:          "max length exactly 24 characters",
			input:         "123456789012345678901234",
			wantDisplay:   "123456789012345678901234",
			wantCanonical: "123456789012345678901234",
		},
		{
			name:          "multilingual Unicode - Cyrillic",
			input:         "Спартак Москва",
			wantDisplay:   "Спартак Москва",
			wantCanonical: "спартак москва",
		},
		{
			name:          "multilingual Unicode - Greek",
			input:         "Σπάρτη",
			wantDisplay:   "Σπάρτη",
			wantCanonical: "σπάρτη",
		},
		{
			name:          "multilingual Unicode - Japanese Kanji & Katakana",
			input:         "東京ランナー",
			wantDisplay:   "東京ランナー",
			wantCanonical: "東京ランナー",
		},
		{
			name:          "multilingual Unicode - Arabic letters",
			input:         "فريق النصر",
			wantDisplay:   "فريق النصر",
			wantCanonical: "فريق النصر",
		},
		{
			name:          "multilingual Unicode - Hebrew RTL letters",
			input:         "קבוצה מהירה",
			wantDisplay:   "קבוצה מהירה",
			wantCanonical: "קבוצה מהירה",
		},
		{
			name:          "mixed scripts - Latin Digits and Cyrillic",
			input:         "Sparta_123_Москва",
			wantDisplay:   "Sparta_123_Москва",
			wantCanonical: "sparta_123_москва",
		},
		{
			name:          "mixed scripts - Latin Japanese and Digits",
			input:         "Tokyo_走者_01",
			wantDisplay:   "Tokyo_走者_01",
			wantCanonical: "tokyo_走者_01",
		},
		{
			name:          "mixed scripts - Latin and Arabic",
			input:         "Cairo_عداؤون",
			wantDisplay:   "Cairo_عداؤون",
			wantCanonical: "cairo_عداؤون",
		},
		{
			name:          "fullwidth Latin normalized via NFKC",
			input:         "Ｔｅａｍ Ａ",
			wantDisplay:   "Ｔｅａｍ Ａ",
			wantCanonical: "team a",
		},
		{
			name:          "valid team containing reserved word as part of phrase",
			input:         "System Shock",
			wantDisplay:   "System Shock",
			wantCanonical: "system shock",
		},
		{
			name:          "valid team containing staff as part of phrase",
			input:         "Staff of Hermes",
			wantDisplay:   "Staff of Hermes",
			wantCanonical: "staff of hermes",
		},

		// Rejections: Empty and whitespace
		{
			name:        "empty string",
			input:       "",
			wantErr:     true,
			errContains: "Team name cannot be empty",
		},
		{
			name:        "spaces only - single space",
			input:       " ",
			wantErr:     true,
			errContains: "Team name cannot be empty",
		},
		{
			name:        "spaces only - multiple spaces",
			input:       "                    ",
			wantErr:     true,
			errContains: "Team name cannot be empty",
		},
		{
			name:        "spaces only - tabs and spaces",
			input:       "   \t   \t   ",
			wantErr:     true,
			errContains: "Team name cannot contain control characters or newlines",
		},

		// Rejections: Length
		{
			name:        "too short - 1 char",
			input:       "A",
			wantErr:     true,
			errContains: "Team name must be at least 3 characters long",
		},
		{
			name:        "too short - 2 chars",
			input:       "AB",
			wantErr:     true,
			errContains: "Team name must be at least 3 characters long",
		},
		{
			name:        "too short after trim",
			input:       "  AB  ",
			wantErr:     true,
			errContains: "Team name must be at least 3 characters long",
		},
		{
			name:        "too long - 25 characters",
			input:       "1234567890123456789012345",
			wantErr:     true,
			errContains: "Team name cannot exceed 24 characters",
		},
		{
			name:        "too long - 100 characters",
			input:       strings.Repeat("Runners-", 12) + "Team",
			wantErr:     true,
			errContains: "Team name cannot exceed 24 characters",
		},
		{
			name:        "very long input - 1000 characters",
			input:       strings.Repeat("A", 1000),
			wantErr:     true,
			errContains: "Team name cannot exceed 24 characters",
		},

		// Rejections: Control characters & newlines
		{
			name:        "contains newline",
			input:       "Team\nOne",
			wantErr:     true,
			errContains: "Team name cannot contain control characters or newlines",
		},
		{
			name:        "contains carriage return",
			input:       "Team\rTwo",
			wantErr:     true,
			errContains: "Team name cannot contain control characters or newlines",
		},
		{
			name:        "contains tab",
			input:       "Team\tThree",
			wantErr:     true,
			errContains: "Team name cannot contain control characters or newlines",
		},
		{
			name:        "contains null byte",
			input:       "Team\x00Four",
			wantErr:     true,
			errContains: "Team name cannot contain control characters or newlines",
		},

		// Rejections: Zero-width spaces & Look-alike spaces
		{
			name:        "contains zero-width space U+200B",
			input:       "Team\u200BOne",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains zero-width joiner U+200D",
			input:       "Team\u200DTwo",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains zero-width no-break space (BOM) U+FEFF",
			input:       "\uFEFFTeamThree",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains non-breaking space (NBSP) U+00A0",
			input:       "Team\u00A0Four",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains ideographic space U+3000",
			input:       "Team\u3000Five",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains em quad U+2001",
			input:       "Team\u2001Six",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},

		// Rejections: HTML & Markup
		{
			name:        "HTML bold tag",
			input:       "<b>Team Alpha</b>",
			wantErr:     true,
			errContains: "Team name cannot contain HTML or markup tags",
		},
		{
			name:        "HTML script tag",
			input:       "<script>bad()</script>",
			wantErr:     true,
			errContains: "Team name cannot contain HTML or markup tags",
		},
		{
			name:        "contains angle brackets",
			input:       "Team <Pro>",
			wantErr:     true,
			errContains: "Team name cannot contain HTML or markup tags",
		},

		// Rejections: URLs
		{
			name:        "http link",
			input:       "http://team.com",
			wantErr:     true,
			errContains: "Team name cannot contain URLs or web links",
		},
		{
			name:        "https link",
			input:       "https://myteam.io",
			wantErr:     true,
			errContains: "Team name cannot contain URLs or web links",
		},
		{
			name:        "www prefix",
			input:       "www.runners.org",
			wantErr:     true,
			errContains: "Team name cannot contain URLs or web links",
		},
		{
			name:        "domain link .com",
			input:       "runners.com",
			wantErr:     true,
			errContains: "Team name cannot contain URLs or web links",
		},
		{
			name:        "domain link .app",
			input:       "fastest.app",
			wantErr:     true,
			errContains: "Team name cannot contain URLs or web links",
		},

		// Rejections: Disallowed characters (emojis, punctuation, symbols)
		{
			name:        "contains emoji runner",
			input:       "Runner 🏃 Team",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains emoji fire",
			input:       "Fire Squad 🔥",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains exclamation mark",
			input:       "Go Team!",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains at symbol",
			input:       "Team @Home",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains hashtag",
			input:       "Team #1",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains slash",
			input:       "Team/Squad",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains complex ZWJ emoji",
			input:       "🏃‍♂️ Runner",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},
		{
			name:        "contains flag emoji",
			input:       "🇺🇸 Team",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains skull emoji",
			input:       "Skull 💀 Squad",
			wantErr:     true,
			errContains: "Team name can only contain letters, numbers, spaces, hyphens, and underscores",
		},
		{
			name:        "contains RTL bidi override control",
			input:       "\u202EReversed",
			wantErr:     true,
			errContains: "Team name cannot contain zero-width or non-standard spaces",
		},

		// Rejections: Reserved words
		{
			name:        "reserved - admin",
			input:       "admin",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - Admin uppercase",
			input:       "ADMIN",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - support with spaces",
			input:       "  support  ",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - moderator",
			input:       "moderator",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - official with underscores",
			input:       "_official_",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - staff with hyphens",
			input:       "-staff-",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - system",
			input:       "System",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - null",
			input:       "null",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - undefined",
			input:       "undefined",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - mixed case sYsTeM",
			input:       "sYsTeM",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},
		{
			name:        "reserved - mixed case uNdEfInEd",
			input:       "uNdEfInEd",
			wantErr:     true,
			errContains: "Team name cannot be a reserved word",
		},

		// Rejections: Configurable abusive deny-list
		{
			name:        "abusive term from deny-list",
			input:       "Toxic Runners",
			denyList:    []string{"toxic", "cheater"},
			wantErr:     true,
			errContains: "Team name contains prohibited or abusive terms",
		},
		{
			name:        "abusive exact match",
			input:       "Cheater",
			denyList:    []string{"toxic", "cheater"},
			wantErr:     true,
			errContains: "Team name contains prohibited or abusive terms",
		},
		{
			name:        "multi-word abusive term",
			input:       "The Hate Clan",
			denyList:    []string{"hate clan"},
			wantErr:     true,
			errContains: "Team name contains prohibited or abusive terms",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res, err := ValidateTeamName(tt.input, tt.denyList)
			if tt.wantErr {
				require.Error(t, err)
				assert.Contains(t, err.Error(), tt.errContains)
				assert.Nil(t, res)
			} else {
				require.NoError(t, err)
				require.NotNil(t, res)
				assert.Equal(t, tt.wantDisplay, res.DisplayName)
				assert.Equal(t, tt.wantCanonical, res.CanonicalKey)
			}
		})
	}
}

func TestValidateTeamName_NormalizationParity(t *testing.T) {
	// "Team A" and "team  a" must produce the exact same canonical key
	res1, err1 := ValidateTeamName("Team A")
	require.NoError(t, err1)

	res2, err2 := ValidateTeamName("team  a")
	require.NoError(t, err2)

	assert.Equal(t, "Team A", res1.DisplayName)
	assert.Equal(t, "team a", res2.DisplayName)
	assert.Equal(t, res1.CanonicalKey, res2.CanonicalKey)
	assert.Equal(t, "team a", res1.CanonicalKey)
}

func TestHandleUpdateUserFaction_ValidationRules(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := NewAPI(
		memStore,
		nil,
		WithAuthenticator(authenticator),
		WithTeamDenyList([]string{"toxic_clan", "cheaters"}),
	)
	router := SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_val", Username: "ValidatorRunner", Faction: "Cyber Vanguard"})

	t.Run("valid team with space collapsing returns 200 and sanitized display name", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "   Solaris    Nomads   "})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusOK, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "ok", resp["status"])
		assert.Equal(t, "Solaris Nomads", resp["faction"])

		// Verify stored in memory
		u, err := memStore.GetUser(ctx, "usr_val")
		require.NoError(t, err)
		assert.Equal(t, "Solaris Nomads", u.Faction)
	})

	t.Run("empty team returns 400 with INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "   "})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Equal(t, "Team name cannot be empty", resp["detail"])
	})

	t.Run("reserved word returns 400 with INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "admin"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Contains(t, resp["detail"], "reserved word")
	})

	t.Run("emoji in team returns 400 with INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "Rocket 🚀 Runners"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Contains(t, resp["detail"], "letters, numbers, spaces, hyphens, and underscores")
	})

	t.Run("denied abusive word returns 400 with INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "The Cheaters"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Contains(t, resp["detail"], "prohibited or abusive")
	})

	t.Run("unauthenticated request returns 401 UNAUTHORIZED", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "Valid Team"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		// Call handler directly without authentication context
		apiHandler.HandleUpdateUserFaction(rec, req)
		assert.Equal(t, http.StatusUnauthorized, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "UNAUTHORIZED", resp["error"])
	})

	t.Run("url in faction returns 400 INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "https://bad.com"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Contains(t, resp["detail"], "URLs or web links")
	})

	t.Run("html in faction returns 400 INVALID_TEAM_NAME", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "<script>evil</script>"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusBadRequest, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "INVALID_TEAM_NAME", resp["error"])
		assert.Contains(t, resp["detail"], "HTML or markup tags")
	})

	t.Run("international Unicode Japanese returns 200 OK", func(t *testing.T) {
		body, _ := json.Marshal(map[string]string{"faction": "東京ランナー"})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_val")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		router.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusOK, rec.Code)

		var resp map[string]string
		err := json.Unmarshal(rec.Body.Bytes(), &resp)
		require.NoError(t, err)
		assert.Equal(t, "東京ランナー", resp["faction"])
	})
}

func TestSanitizeTeamName_LegacyValues(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		// Valid legacy values preserved and cleaned
		{"valid clean", "Solaris Nomads", "Solaris Nomads"},
		{"valid uncollapsed spaces", "  Iron    Legion  ", "Iron Legion"},
		{"valid hyphenated", "Cyber-Vanguard_01", "Cyber-Vanguard_01"},

		// Invalid legacy values mapped to empty (no team)
		{"empty string", "", ""},
		{"spaces only", "     ", ""},
		{"too short", "AB", ""},
		{"too long", "1234567890123456789012345", ""},
		{"contains newline", "Team\nOne", ""},
		{"contains carriage return", "Team\rTwo", ""},
		{"contains tab", "Team\tThree", ""},
		{"contains null byte", "Team\x00Four", ""},
		{"contains zero width space", "Team\u200BBad", ""},
		{"contains ideographic space", "Team\u3000Bad", ""},
		{"contains non-breaking space", "Team\u00A0Bad", ""},
		{"html script tag", "<script>alert(1)</script>", ""},
		{"html tag", "<b>Hackers</b>", ""},
		{"url http", "http://evil.com", ""},
		{"url https", "https://scam.org", ""},
		{"domain url", "cheats.app", ""},
		{"reserved admin", "admin", ""},
		{"reserved Admin upper", "ADMIN", ""},
		{"reserved official", "_official_", ""},
		{"emoji runner", "Runner 🏃 Squad", ""},
		{"special symbols", "Team #1!", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SanitizeTeamName(tt.input)
			assert.Equal(t, tt.expected, got)
		})
	}
}

func TestHandleGetMe_LegacySanitization(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := NewAPI(memStore, nil, WithAuthenticator(authenticator))
	router := SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	// Insert user with invalid legacy faction (HTML injection)
	_ = memStore.UpsertUser(ctx, &store.User{
		ID:       "usr_legacy_bad",
		Username: "LegacyRunner",
		Faction:  "<script>alert('xss')</script>",
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	req.Header.Set("X-Dev-User", "usr_legacy_bad")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var user store.User
	err := json.Unmarshal(rec.Body.Bytes(), &user)
	require.NoError(t, err)
	// Invalid legacy faction must be sanitized to empty string (no team)
	assert.Equal(t, "", user.Faction)
}

func TestHandleGetFactionStandings_LegacySanitization(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := NewAPI(memStore, nil, WithAuthenticator(authenticator))
	router := SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_valid", Username: "ValidNomad", Faction: "Solaris Nomads"})
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_hacker", Username: "HackerLead", Faction: "admin"})

	req := httptest.NewRequest(http.MethodGet, "/v1/factions/standings", nil)
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	var resp store.FactionStandingsResponse
	err := json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	// Standings must only contain valid teams; "admin" must be excluded
	for _, standing := range resp.Standings {
		assert.NotEqual(t, "admin", standing.Faction)
	}
}

func TestHandleUpdateUserFaction_RateLimit(t *testing.T) {
	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	// Limiter with capacity 3.0 tokens
	limiter := NewRateLimiter(3.0/86400.0, 3.0)
	apiHandler := NewAPI(
		memStore,
		nil,
		WithAuthenticator(authenticator),
		WithTeamLimiter(limiter),
	)
	router := SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{ID: "usr_ratelimit", Username: "Pacer", Faction: ""})

	changeTeam := func(teamName string) (int, map[string]interface{}, http.Header) {
		body, _ := json.Marshal(map[string]string{"faction": teamName})
		req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
		req.Header.Set("X-Dev-User", "usr_ratelimit")
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		var resp map[string]interface{}
		_ = json.Unmarshal(rec.Body.Bytes(), &resp)
		return rec.Code, resp, rec.Header()
	}

	// Change 1 (Allowed)
	code1, _, _ := changeTeam("Team Alpha")
	assert.Equal(t, http.StatusOK, code1)

	// No-op change (same team) must not consume token
	codeNoop, _, _ := changeTeam("Team Alpha")
	assert.Equal(t, http.StatusOK, codeNoop)

	// Invalid input (400) must not consume token
	codeInvalid, respInvalid, _ := changeTeam("a")
	assert.Equal(t, http.StatusBadRequest, codeInvalid)
	assert.Equal(t, "INVALID_TEAM_NAME", respInvalid["error"])

	// Change 2 (Allowed)
	code2, _, _ := changeTeam("Team Beta")
	assert.Equal(t, http.StatusOK, code2)

	// Change 3 (Allowed - 3rd of 3 allowed per day)
	code3, _, _ := changeTeam("Team Gamma")
	assert.Equal(t, http.StatusOK, code3)

	// Change 4 (Rejected with 429 RATE_LIMIT_EXCEEDED)
	code4, resp4, headers4 := changeTeam("Team Delta")
	assert.Equal(t, http.StatusTooManyRequests, code4)
	assert.Equal(t, "RATE_LIMIT_EXCEEDED", resp4["error"])
	assert.Contains(t, resp4["detail"], "limit exceeded")
	assert.NotEmpty(t, headers4.Get("Retry-After"))
}

func TestHandleUpdateUserFaction_PIIFreeLogging(t *testing.T) {
	var logBuf bytes.Buffer
	testLogger := slog.New(slog.NewJSONHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelInfo}))

	memStore := store.NewMemoryStore()
	cfg := &config.Config{AuthMode: "dev", Env: "development"}
	authenticator := auth.NewAuthenticator(cfg)
	apiHandler := NewAPI(
		memStore,
		testLogger,
		WithAuthenticator(authenticator),
	)
	router := SetupRouter(apiHandler, authenticator)

	ctx := context.Background()
	_ = memStore.UpsertUser(ctx, &store.User{
		ID:       "usr_private_9988",
		Username: "SecretRunner",
		Faction:  "Original Team",
	})

	body, _ := json.Marshal(map[string]string{"faction": "New Secret Team"})
	req := httptest.NewRequest(http.MethodPut, "/v1/me/faction", bytes.NewReader(body))
	req.Header.Set("X-Dev-User", "usr_private_9988")
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	router.ServeHTTP(rec, req)
	assert.Equal(t, http.StatusOK, rec.Code)

	// Verify structured log output
	logOutput := logBuf.String()
	require.NotEmpty(t, logOutput)

	var logEntry map[string]interface{}
	err := json.Unmarshal([]byte(strings.TrimSpace(logOutput)), &logEntry)
	require.NoError(t, err)

	// Must be INFO level
	assert.Equal(t, "INFO", logEntry["level"])
	assert.Equal(t, "user team changed", logEntry["msg"])
	assert.Equal(t, "Original Team", logEntry["old_team"])
	assert.Equal(t, "New Secret Team", logEntry["new_team"])

	// Must NOT contain personal data (no UID, username, email, IP, coordinates)
	assert.NotContains(t, logEntry, "uid")
	assert.NotContains(t, logEntry, "username")
	assert.NotContains(t, logEntry, "email")
	assert.NotContains(t, logEntry, "ip")
	assert.NotContains(t, logOutput, "usr_private_9988")
	assert.NotContains(t, logOutput, "SecretRunner")
}
