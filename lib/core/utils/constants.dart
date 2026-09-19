class AppConstants {
  // Pass via --dart-define=MAPBOX_API_KEY=YOUR_KEY or use default fallback
  static const String mapApiKey = String.fromEnvironment(
    'MAPBOX_API_KEY',
    defaultValue: '',
  );
}
