import 'package:package_info_plus/package_info_plus.dart';

/// Territory Runner Version & Build Constants
///
/// Automatically retrieves runtime package metadata from `package_info_plus`
/// with seamless compile-time fallbacks.
class AppVersion {
  AppVersion._();

  /// Fallback version string matching pubspec.yaml
  static const String defaultVersion = '1.0.0';

  /// Fallback build number matching pubspec.yaml
  static const String defaultBuildNumber = '1';

  static String _version = defaultVersion;
  static String _buildNumber = defaultBuildNumber;

  /// Canonical runtime version string (resolved from package_info_plus)
  static String get version => _version;

  /// Canonical runtime build number (resolved from package_info_plus)
  static String get buildNumber => _buildNumber;

  /// Complete formatted version string (e.g. "v1.0.0+1")
  static String get full => 'v$_version+$_buildNumber';

  /// User-facing display string (e.g. "v1.0.0 (1)")
  static String get display => 'v$_version ($_buildNumber)';

  /// Asynchronously loads real version and build number from native platform metadata
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _version = info.version;
      }
      if (info.buildNumber.isNotEmpty) {
        _buildNumber = info.buildNumber;
      }
    } catch (_) {
      // In unit test environments or when channel is unavailable, preserve defaults
    }
  }

  /// Sets values directly (primarily for unit tests)
  static void setMock({required String version, required String buildNumber}) {
    _version = version;
    _buildNumber = buildNumber;
  }

  /// Resets back to defaults
  static void reset() {
    _version = defaultVersion;
    _buildNumber = defaultBuildNumber;
  }
}
