enum AutoPauseTransition {
  none,
  paused,
  resumed,
}

/// Athletic auto-pause engine with hysteresis to avoid erratic start/stop toggling.
///
/// Hysteresis policy:
/// - Enters pause state only after runner speed stays strictly below [pauseSpeedCeilingKmh] (1.8 km/h)
///   for [pauseDelaySeconds] (3) consecutive seconds.
/// - Exits pause state immediately when runner speed reaches or exceeds [resumeSpeedFloorKmh] (3.0 km/h).
class AutoPauseEngine {
  static const double pauseSpeedCeilingKmh = 1.8;
  static const double resumeSpeedFloorKmh = 3.0;
  static const int pauseDelaySeconds = 3;

  bool _isAutoPaused = false;
  int _consecutiveStationarySeconds = 0;

  bool get isAutoPaused => _isAutoPaused;
  int get consecutiveStationarySeconds => _consecutiveStationarySeconds;

  /// Evaluates one clock second tick at [currentSpeedKmh].
  /// Returns an [AutoPauseTransition] indicating whether state changed.
  AutoPauseTransition tick(double currentSpeedKmh) {
    if (!_isAutoPaused) {
      if (currentSpeedKmh < pauseSpeedCeilingKmh) {
        _consecutiveStationarySeconds++;
        if (_consecutiveStationarySeconds >= pauseDelaySeconds) {
          _isAutoPaused = true;
          return AutoPauseTransition.paused;
        }
      } else {
        _consecutiveStationarySeconds = 0;
      }
      return AutoPauseTransition.none;
    } else {
      // Currently paused: require higher threshold (hysteresis) to resume
      if (currentSpeedKmh >= resumeSpeedFloorKmh) {
        _isAutoPaused = false;
        _consecutiveStationarySeconds = 0;
        return AutoPauseTransition.resumed;
      }
      return AutoPauseTransition.none;
    }
  }

  /// Manually reset engine counters and state
  void reset() {
    _isAutoPaused = false;
    _consecutiveStationarySeconds = 0;
  }
}
