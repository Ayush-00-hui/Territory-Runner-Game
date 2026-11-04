enum AutoPauseTransition { none, paused, resumed }

/// Athletic auto-pause engine with hysteresis to avoid erratic start/stop toggling.
///
/// Hysteresis policy:
/// - Enters pause state only after runner speed stays strictly below [pauseSpeedCeilingKmh] (2.5 km/h)
///   for [pauseDelaySeconds] (3) consecutive seconds.
/// - Exits pause state immediately when runner speed reaches or exceeds [resumeSpeedFloorKmh] (3.0 km/h).
/// - Inhibits auto-pausing at run start until initial movement is established.
class AutoPauseEngine {
  static const double pauseSpeedCeilingKmh = 2.5;
  static const double resumeSpeedFloorKmh = 3.0;
  static const int pauseDelaySeconds = 3;

  bool _isAutoPaused = false;
  int _consecutiveStationarySeconds = 0;
  bool _hasInitialMovement = false;

  AutoPauseEngine({this._hasInitialMovement = false});

  bool get isAutoPaused => _isAutoPaused;
  int get consecutiveStationarySeconds => _consecutiveStationarySeconds;
  bool get hasInitialMovement => _hasInitialMovement;

  /// Explicitly marks that initial movement has been detected (e.g. from GPS displacement).
  void markMovement() {
    _hasInitialMovement = true;
  }

  /// Evaluates one clock second tick at [currentSpeedKmh].
  /// Returns an [AutoPauseTransition] indicating whether state changed.
  AutoPauseTransition tick(double currentSpeedKmh) {
    // Inhibit auto-pause before the athlete has established initial run movement.
    if (!_hasInitialMovement) {
      if (currentSpeedKmh >= pauseSpeedCeilingKmh) {
        _hasInitialMovement = true;
        _consecutiveStationarySeconds = 0;
      }
      return AutoPauseTransition.none;
    }

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

  /// Forces state to resumed (e.g. on immediate displacement detection).
  void forceResume() {
    _isAutoPaused = false;
    _consecutiveStationarySeconds = 0;
    _hasInitialMovement = true;
  }

  /// Manually reset engine counters and state
  void reset() {
    _isAutoPaused = false;
    _consecutiveStationarySeconds = 0;
    _hasInitialMovement = false;
  }
}
