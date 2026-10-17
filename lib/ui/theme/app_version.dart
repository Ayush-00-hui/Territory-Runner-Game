/// Territory Runner Version & Build Constants
class AppVersion {
  AppVersion._();

  /// Canonical version string matching pubspec.yaml
  static const String version = '1.0.0';

  /// Canonical build number matching pubspec.yaml
  static const String buildNumber = '1';

  /// Complete formatted version string (e.g. "v1.0.0+1")
  static const String full = 'v$version+$buildNumber';

  /// User-facing display string (e.g. "v1.0.0 (1)")
  static const String display = 'v$version ($buildNumber)';
}
