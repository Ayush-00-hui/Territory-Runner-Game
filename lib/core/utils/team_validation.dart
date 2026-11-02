/// Single source of truth for Team / Faction validation rules mirroring the Go server.
class TeamNameValidator {
  static const int minLength = 3;
  static const int maxLength = 24;

  static const Set<String> reservedWords = {
    'admin',
    'support',
    'moderator',
    'official',
    'staff',
    'system',
    'null',
    'undefined',
  };

  static final RegExp _urlSchemeRegex = RegExp(
    r'(https?://|ftp://|www\.)',
    caseSensitive: false,
  );

  static final RegExp _domainRegex = RegExp(
    r'\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|app|dev|xyz|co|gg|edu|gov|mil|info|biz|site|online|me|tv)\b',
    caseSensitive: false,
  );

  static final RegExp _allowedCharsRegex = RegExp(
    r'^[\p{L}\p{N}\p{M} _-]+$',
    unicode: true,
  );

  static bool _isZeroWidth(int codeUnit) {
    if ((codeUnit >= 0x200B &&
            codeUnit <= 0x200F) || // Zero-width spaces, joiners, bidi marks
        (codeUnit >= 0x202A &&
            codeUnit <= 0x202E) || // Bidi embedding/override controls
        (codeUnit >= 0x2060 &&
            codeUnit <= 0x206F) || // Word joiner and isolates
        codeUnit == 0xFEFF || // Zero Width No-Break Space (BOM)
        codeUnit == 0x180E) {
      // Mongolian Vowel Separator
      return true;
    }
    return false;
  }

  static bool _isLookAlikeSpace(int codeUnit) {
    if (codeUnit == 0x00A0 || // Non-breaking space
        codeUnit == 0x1680 || // Ogham space mark
        (codeUnit >= 0x2000 && codeUnit <= 0x200A) || // En quad to Hair space
        codeUnit == 0x202F || // Narrow no-break space
        codeUnit == 0x205F || // Medium mathematical space
        codeUnit == 0x3000) {
      // Ideographic space
      return true;
    }
    return false;
  }

  /// Collapses multiple consecutive ASCII spaces to a single space.
  static String collapseSpaces(String input) {
    return input.replaceAll(RegExp(r' +'), ' ').trim();
  }

  /// Validates a proposed team name.
  /// Returns null if valid; returns a human-readable error string if invalid.
  static String? validate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Team name cannot be empty';
    }

    // 1. Check for control characters and newlines
    for (int i = 0; i < raw.length; i++) {
      final code = raw.codeUnitAt(i);
      if (code < 32 || code == 127) {
        return 'Team name cannot contain control characters or newlines';
      }
    }

    // 2. Check for zero-width spaces or look-alike spaces
    for (int i = 0; i < raw.length; i++) {
      final code = raw.codeUnitAt(i);
      if (_isZeroWidth(code) || _isLookAlikeSpace(code)) {
        return 'Team name cannot contain zero-width or non-standard spaces';
      }
    }

    // 3. Check for HTML or markup tags
    if (raw.contains('<') || raw.contains('>')) {
      return 'Team name cannot contain HTML or markup tags';
    }

    // 4. Check for URLs or domain links
    if (_urlSchemeRegex.hasMatch(raw) || _domainRegex.hasMatch(raw)) {
      return 'Team name cannot contain URLs or web links';
    }

    // 5. Allowed characters: Unicode letters, numbers, marks, spaces, hyphens, underscores
    if (!_allowedCharsRegex.hasMatch(raw)) {
      return 'Team name can only contain letters, numbers, spaces, hyphens, and underscores';
    }

    // 6. Trim leading/trailing spaces and collapse repeated spaces
    final collapsed = collapseSpaces(raw);
    if (collapsed.isEmpty) {
      return 'Team name cannot be empty';
    }

    // 7. Length check on Unicode characters (runes)
    final charCount = collapsed.runes.length;
    if (charCount < minLength) {
      return 'Team name must be at least 3 characters long';
    }
    if (charCount > maxLength) {
      return 'Team name cannot exceed 24 characters';
    }

    // 8. Reserved words check (case-insensitive)
    final canonical = collapsed.toLowerCase();
    final stripped = canonical.replaceAll(RegExp(r'^[-_ ]+|[-_ ]+$'), '');
    if (reservedWords.contains(canonical) || reservedWords.contains(stripped)) {
      return 'Team name cannot be a reserved word (e.g., admin, support, official)';
    }

    return null;
  }

  /// Sanitizes stored or legacy team names at read time.
  /// If valid, returns the trimmed and collapsed display name.
  /// If invalid or null, returns empty string '' (no team) to prevent crashes.
  static String sanitize(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }
    if (validate(raw) != null) {
      return '';
    }
    return collapseSpaces(raw.trim());
  }
}
