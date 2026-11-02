package api

import (
	"errors"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

var (
	urlSchemeRegex = regexp.MustCompile(`(?i)(https?://|ftp://|www\.)`)
	domainRegex    = regexp.MustCompile(`(?i)\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|app|dev|xyz|co|gg|edu|gov|mil|info|biz|site|online|me|tv)\b`)

	// Reserved team names that cannot be claimed or impersonated.
	reservedWords = map[string]struct{}{
		"admin":     {},
		"support":   {},
		"moderator": {},
		"official":  {},
		"staff":     {},
		"system":    {},
		"null":      {},
		"undefined": {},
	}
)

// TeamValidationResult holds the sanitized display name and canonical comparison key.
type TeamValidationResult struct {
	DisplayName  string
	CanonicalKey string
}

// isZeroWidth returns true if rune is a zero-width space or format character.
func isZeroWidth(r rune) bool {
	if unicode.Is(unicode.Cf, r) {
		return true
	}
	switch r {
	case '\u200B', // Zero Width Space
		'\u200C', // Zero Width Non-Joiner
		'\u200D', // Zero Width Joiner
		'\u2060', // Word Joiner
		'\uFEFF', // Zero Width No-Break Space (BOM)
		'\u180E': // Mongolian Vowel Separator
		return true
	default:
		return false
	}
}

// isLookAlikeSpace returns true for non-standard or look-alike whitespace runes.
func isLookAlikeSpace(r rune) bool {
	if r == '\u00A0' || // Non-breaking space
		r == '\u1680' || // Ogham space mark
		(r >= '\u2000' && r <= '\u200A') || // En quad to Hair space
		r == '\u202F' || // Narrow no-break space
		r == '\u205F' || // Medium mathematical space
		r == '\u3000' { // Ideographic space
		return true
	}
	return false
}

// isAllowedRune checks whether rune is a letter, digit, mark/accent, space, hyphen, or underscore.
func isAllowedRune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r) || unicode.IsMark(r) || r == ' ' || r == '-' || r == '_'
}

// ValidateTeamName validates and normalizes a proposed team name.
// It enforces server-side validation rules (single source of truth):
// - Trim leading/trailing spaces and collapse repeated spaces
// - Length between 3 and 24 Unicode characters (runes)
// - Allowed characters: letters, digits, space, hyphen, underscore
// - Rejection of control characters, newlines, HTML/markup, URLs, zero-width or look-alike spaces
// - Rejection of reserved words (admin, support, moderator, official, staff, system, null, undefined)
// - Rejection of words in the configurable abusive deny-list
// - Normalization for comparison (case-insensitive Unicode NFKC)
func ValidateTeamName(raw string, denyList ...[]string) (*TeamValidationResult, error) {
	if len(raw) == 0 {
		return nil, errors.New("Team name cannot be empty")
	}

	// 1. Reject control characters and newlines
	for _, r := range raw {
		if r < 32 || r == 127 || unicode.IsControl(r) {
			return nil, errors.New("Team name cannot contain control characters or newlines")
		}
	}

	// 2. Reject zero-width spaces or look-alike spaces
	for _, r := range raw {
		if isZeroWidth(r) || isLookAlikeSpace(r) || (unicode.IsSpace(r) && r != ' ') {
			return nil, errors.New("Team name cannot contain zero-width or non-standard spaces")
		}
	}

	// 3. Reject HTML or markup tags
	if strings.ContainsAny(raw, "<>") {
		return nil, errors.New("Team name cannot contain HTML or markup tags")
	}

	// 4. Reject URLs or domain links
	if urlSchemeRegex.MatchString(raw) || domainRegex.MatchString(raw) {
		return nil, errors.New("Team name cannot contain URLs or web links")
	}

	// 5. Allowed characters: letters, digits, space, hyphen, underscore
	for _, r := range raw {
		if !isAllowedRune(r) {
			return nil, errors.New("Team name can only contain letters, numbers, spaces, hyphens, and underscores")
		}
	}

	// 6. Trim leading/trailing spaces and collapse repeated ASCII spaces to single space
	trimmed := strings.Trim(raw, " ")
	if trimmed == "" {
		return nil, errors.New("Team name cannot be empty")
	}

	var b strings.Builder
	b.Grow(len(trimmed))
	prevSpace := false
	for _, r := range trimmed {
		if r == ' ' {
			if !prevSpace {
				b.WriteRune(r)
				prevSpace = true
			}
		} else {
			b.WriteRune(r)
			prevSpace = false
		}
	}
	displayName := b.String()

	// 7. Length check on Unicode runes (3 to 24)
	runeCount := utf8.RuneCountInString(displayName)
	if runeCount < 3 {
		return nil, errors.New("Team name must be at least 3 characters long")
	}
	if runeCount > 24 {
		return nil, errors.New("Team name cannot exceed 24 characters")
	}

	// 8. Normalise for comparison: case-insensitive, Unicode NFKC
	canonicalKey := strings.ToLower(norm.NFKC.String(displayName))

	// 9. Reject reserved words
	strippedReserved := strings.Trim(canonicalKey, "-_ ")
	if _, ok := reservedWords[canonicalKey]; ok {
		return nil, errors.New("Team name cannot be a reserved word (e.g., admin, support, official)")
	}
	if _, ok := reservedWords[strippedReserved]; ok {
		return nil, errors.New("Team name cannot be a reserved word (e.g., admin, support, official)")
	}

	// 10. Configurable deny-list for abusive words
	var activeDenyList []string
	if len(denyList) > 0 && len(denyList[0]) > 0 {
		activeDenyList = denyList[0]
	}

	if len(activeDenyList) > 0 {
		tokens := strings.FieldsFunc(canonicalKey, func(r rune) bool {
			return r == ' ' || r == '-' || r == '_'
		})

		for _, term := range activeDenyList {
			cleanTerm := strings.ToLower(strings.TrimSpace(term))
			if cleanTerm == "" {
				continue
			}

			// Direct match on full canonical key
			if canonicalKey == cleanTerm {
				return nil, errors.New("Team name contains prohibited or abusive terms")
			}

			// Match on token boundaries
			for _, token := range tokens {
				if token == cleanTerm {
					return nil, errors.New("Team name contains prohibited or abusive terms")
				}
			}

			// Match multi-word terms
			if strings.Contains(cleanTerm, " ") || strings.Contains(cleanTerm, "-") || strings.Contains(cleanTerm, "_") {
				if strings.Contains(canonicalKey, cleanTerm) {
					return nil, errors.New("Team name contains prohibited or abusive terms")
				}
			}
		}
	}

	return &TeamValidationResult{
		DisplayName:  displayName,
		CanonicalKey: canonicalKey,
	}, nil
}

// SanitizeTeamName safely sanitizes stored or legacy team names at read time.
// If the stored value fails server validation rules (e.g. control chars, HTML,
// URLs, reserved words, too short, too long, emojis, non-standard spaces),
// it maps the value to "" (empty / no team) without crashing.
func SanitizeTeamName(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}
	res, err := ValidateTeamName(raw)
	if err != nil {
		return ""
	}
	return res.DisplayName
}
