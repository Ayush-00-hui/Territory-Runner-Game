import 'package:geolocator/geolocator.dart';

/// Single sample of speed and position for smoothing window.
class _SpeedSample {
  final double speedKmh;
  final DateTime timestamp;

  const _SpeedSample(this.speedKmh, this.timestamp);
}

/// Offline GPS speed smoothing and fallback pipeline.
///
/// Features:
/// 1. Rejects fixes with poor horizontal accuracy (> 30.0m).
/// 2. Falls back to geodesic displacement (delta d / delta t) when Doppler
///    speed is zero, negative, or missing.
/// 3. Applies a rolling window filter (3 to 5 seconds) to eliminate single-point
///    speed noise and multipath jitter.
/// 4. Handles auto-pause: zeroes output speed immediately and freezes/clears
///    the rolling buffer so pause periods do not contaminate moving pace.
class SpeedSmoothingPipeline {
  static const double maxAccuracyMeters = 30.0;
  static const double windowDurationSeconds = 4.0;
  static const double maxHumanSpeedKmh = 75.0; // Sprint/cycling upper bound
  static const double minDopplerSpeedThresholdMps = 0.05; // ~0.18 km/h

  final List<_SpeedSample> _recentSamples = [];
  Position? _lastValidPosition;
  double _currentSmoothedSpeedKmh = 0.0;

  double get currentSmoothedSpeedKmh => _currentSmoothedSpeedKmh;

  /// Resets all internal speed history and last known position.
  void reset() {
    _recentSamples.clear();
    _lastValidPosition = null;
    _currentSmoothedSpeedKmh = 0.0;
  }

  /// Ingests a new GPS fix and returns the smoothed speed in km/h.
  ///
  /// If [isAutoPaused] is true, immediately returns 0.0 km/h and clears the
  /// rolling buffer.
  double processPosition(Position pos, {required bool isAutoPaused}) {
    if (isAutoPaused) {
      _recentSamples.clear();
      _currentSmoothedSpeedKmh = 0.0;
      _lastValidPosition = pos;
      return 0.0;
    }

    // 1. Accuracy gate: discard coarse fixes (> 30m) from contaminating speed
    if (pos.accuracy > maxAccuracyMeters) {
      return _currentSmoothedSpeedKmh;
    }

    final now = pos.timestamp;
    double rawSpeedKmh = 0.0;

    // 2. Doppler speed vs Displacement fallback
    final bool hasDoppler = pos.speed > minDopplerSpeedThresholdMps;
    if (hasDoppler) {
      rawSpeedKmh = pos.speed * 3.6;
    } else if (_lastValidPosition != null) {
      final dt =
          now.difference(_lastValidPosition!.timestamp).inMilliseconds / 1000.0;
      if (dt >= 0.5 && dt <= 10.0) {
        final dMeters = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        rawSpeedKmh = (dMeters / dt) * 3.6;
      }
    } else {
      // First fix with missing Doppler: store anchor and wait for second fix to compute displacement
      _lastValidPosition = pos;
      return _currentSmoothedSpeedKmh;
    }

    _lastValidPosition = pos;

    // Clamp raw speed to plausible human locomotion ceiling
    rawSpeedKmh = rawSpeedKmh.clamp(0.0, maxHumanSpeedKmh);

    // 3. Rolling window accumulation (last 4 seconds)
    _recentSamples.add(_SpeedSample(rawSpeedKmh, now));
    _recentSamples.removeWhere(
      (s) =>
          now.difference(s.timestamp).inMilliseconds / 1000.0 >
          windowDurationSeconds,
    );

    // 4. Weighted smoothing: give highest weight to recent fixes while smoothing spikes
    if (_recentSamples.isEmpty) {
      _currentSmoothedSpeedKmh = rawSpeedKmh;
    } else if (_recentSamples.length == 1) {
      _currentSmoothedSpeedKmh = _recentSamples.first.speedKmh;
    } else {
      // Exponentially weighted or linear weighting toward most recent fix
      double totalWeight = 0.0;
      double weightedSum = 0.0;
      for (int i = 0; i < _recentSamples.length; i++) {
        // Linear weight: older samples get lower weight, newest gets highest
        final weight = 1.0 + (i * 0.5);
        weightedSum += _recentSamples[i].speedKmh * weight;
        totalWeight += weight;
      }
      _currentSmoothedSpeedKmh = weightedSum / totalWeight;
    }

    // If speed is negligible (< 0.2 km/h), round to 0.0 to prevent drifting decimal noise
    if (_currentSmoothedSpeedKmh < 0.2) {
      _currentSmoothedSpeedKmh = 0.0;
    }

    return _currentSmoothedSpeedKmh;
  }
}
