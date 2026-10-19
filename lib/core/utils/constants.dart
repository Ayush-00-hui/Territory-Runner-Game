class AppConstants {
  static const String mapApiKey = String.fromEnvironment('MAPBOX_API_KEY');

  // Tile provider default values
  static const String defaultOsmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String defaultOsmAttribution = '© OpenStreetMap contributors';

  /// Tile URL template configurable via --dart-define=TILE_URL_TEMPLATE=...
  static const String tileUrlTemplate = String.fromEnvironment(
    'TILE_URL_TEMPLATE',
    defaultValue: defaultOsmUrlTemplate,
  );

  /// Attribution string configurable via --dart-define=TILE_ATTRIBUTION=...
  static const String tileAttribution = String.fromEnvironment(
    'TILE_ATTRIBUTION',
    defaultValue: defaultOsmAttribution,
  );

  /// Tile service API key configurable via --dart-define=TILE_API_KEY=... or MAPBOX_API_KEY
  static const String tileApiKey = String.fromEnvironment(
    'TILE_API_KEY',
    defaultValue: String.fromEnvironment('MAPBOX_API_KEY'),
  );

  /// OpenStreetMap Tile Usage Policy forbids bulk downloading / prefetching.
  /// Set to true only with dedicated or self-hosted tile infrastructure.
  /// Configurable via --dart-define=ALLOW_TILE_PREFETCH=true
  static const bool allowTilePrefetch = bool.fromEnvironment(
    'ALLOW_TILE_PREFETCH',
    defaultValue: false,
  );

  /// Minimum cache age in days before tile revalidation (default 7 days).
  static const int minTileCacheDays = 7;

  /// User-Agent identifying application and repository contact per OSM policy.
  static const String userAgent = 'com.territoryrunner.app/1.0.0 (https://github.com/Ayush-00-hui/Territory-Runner-Game)';
}

