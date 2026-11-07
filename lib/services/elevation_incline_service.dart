import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Snapshot result from the elevation and incline sensing pipeline.
class ElevationResult {
  final double smoothedAltitudeMeters;
  final double grade; // Clamped to +/- 0.20 (+/- 20%)
  final double cumulativeGainMeters;

  const ElevationResult({
    required this.smoothedAltitudeMeters,
    required this.grade,
    required this.cumulativeGainMeters,
  });

  double get smoothedAltitude => smoothedAltitudeMeters;

  /// Incline percentage expressed as integer or decimal string (e.g., "+4.5%").
  String get gradePercentString {
    final pct = grade * 100.0;
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}

/// Historical fix record used to compute grade across a minimum distance baseline.
class _DistanceAltitudeFix {
  final double distanceMeters;
  final double altitudeMeters;
  final DateTime timestamp;

  const _DistanceAltitudeFix({
    required this.distanceMeters,
    required this.altitudeMeters,
    required this.timestamp,
  });
}

/// Offline elevation, incline, and cumulative elevation gain pipeline.
///
/// Features:
/// 1. Reject low-accuracy fixes: horizontal accuracy > 30m or altitude accuracy > 25m.
/// 2. Reject vertical velocity anomalies (|delta h / delta t| > 15 m/s).
/// 3. 5-sample rolling median filter to eliminate impulsive GPS altitude spikes.
/// 4. 1D Kalman filter for smooth, low-latency altitude tracking.
/// 5. Barometer fusion when hardware sensor is present, applying the hypsometric
///    formula to track relative micro-elevation changes.
/// 6. Incline/grade calculation computed over rolling windows of at least 25 meters
///    of accumulated horizontal distance, clamped to [-0.20, +0.20] (+/- 20%).
/// 7. Cumulative elevation gain accumulator with 3.0-meter hysteresis threshold
///    to prevent false gain accumulation from stationary or flat-ground sensor jitter.
class ElevationGradePipeline {
  static const double maxHorizontalAccuracyMeters = 30.0;
  static const double maxAltitudeAccuracyMeters = 25.0;
  static const double maxVerticalVelocityMps =
      15.0; // 54 km/h vertical climb limit
  static const double minGradeWindowDistanceMeters =
      25.0; // Minimum horizontal distance for grade
  static const double maxGradeClamp = 0.20; // +/- 20% incline limit
  static const double gainHysteresisThresholdMeters =
      3.0; // Ignore elevation changes < 3m

  // Median filter buffer (up to 5 samples)
  final List<double> _rawAltitudeBuffer = [];

  // Kalman filter state
  double? _kalmanAltitude;
  double _kalmanP = 25.0; // Initial error variance
  static const double _kalmanQRate = 0.25; // Process noise variance per second
  static const double _defaultKalmanR =
      16.0; // Measurement noise variance (4m std)

  // Barometer fusion state
  StreamSubscription<BarometerEvent>? _barometerSubscription;
  final Stream<BarometerEvent>? customBarometerStream;
  double? _lastBarometerPressureHpa;
  bool _isBarometerActive = false;

  // Grade tracking buffer
  final List<_DistanceAltitudeFix> _distanceFixes = [];

  // Cumulative gain hysteresis state
  double _cumulativeGainMeters = 0.0;
  double? _climbReferenceAltitude;
  double? _peakAltitude;
  bool _inClimbPhase = false;

  // Last accepted GPS fix timestamp for velocity gating
  DateTime? _lastAcceptedGpsTime;
  double? _lastAcceptedAltitude;
  double _currentSmoothedAltitude = 0.0;
  double _currentGrade = 0.0;

  ElevationGradePipeline({this.customBarometerStream}) {
    _initBarometer();
  }

  double get smoothedAltitude => _currentSmoothedAltitude;
  double get currentGrade => _currentGrade;
  double get cumulativeGainMeters => _cumulativeGainMeters;
  bool get isBarometerActive => _isBarometerActive;

  /// Initializes the device barometer stream if available.
  void _initBarometer() {
    if (customBarometerStream == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      _isBarometerActive = false;
      return;
    }

    try {
      final stream = customBarometerStream ?? barometerEventStream();
      _barometerSubscription = stream.listen(
        _onBarometerEvent,
        onError: (_) {
          _isBarometerActive = false;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _isBarometerActive = false;
    }
  }

  /// Hypsometric barometric altitude delta computation.
  /// h(P) = 44330 * (1 - (P / 1013.25)^(1/5.255))
  void _onBarometerEvent(BarometerEvent event) {
    final pressure = event.pressure;
    if (pressure <= 300.0 || pressure >= 1150.0) {
      return; // Discard invalid baro readings
    }
    _isBarometerActive = true;

    if (_lastBarometerPressureHpa != null && _kalmanAltitude != null) {
      final altPrev =
          44330.0 *
          (1.0 -
              math
                  .pow(_lastBarometerPressureHpa! / 1013.25, 0.190284)
                  .toDouble());
      final altCurr =
          44330.0 * (1.0 - math.pow(pressure / 1013.25, 0.190284).toDouble());
      final deltaH = altCurr - altPrev;

      // Reject extreme transient pressure shocks (e.g., slamming car door > 20m)
      if (deltaH.abs() <= 20.0) {
        _kalmanAltitude = _kalmanAltitude! + deltaH;
        _currentSmoothedAltitude = _kalmanAltitude!;
      }
    }
    _lastBarometerPressureHpa = pressure;
  }

  /// Manually add barometer reading for unit tests.
  void addBarometerReading(double pressureHpa) {
    _onBarometerEvent(BarometerEvent(pressureHpa, DateTime.now()));
  }

  /// Ingests a GPS fix and the current accumulated horizontal distance in meters,
  /// updating the smoothed altitude, grade, and cumulative gain.
  ElevationResult processPosition(
    Position pos, {
    required double accumulatedDistanceMeters,
  }) {
    final now = pos.timestamp;

    // 1. Horizontal and vertical accuracy rejection
    if (pos.accuracy > maxHorizontalAccuracyMeters) {
      return _buildResult();
    }
    if (pos.altitudeAccuracy > 0 &&
        pos.altitudeAccuracy > maxAltitudeAccuracyMeters) {
      return _buildResult();
    }

    // 2. Vertical velocity spike rejection (|delta h / delta t| > 15 m/s)
    final rawAlt = pos.altitude;
    if (_lastAcceptedGpsTime != null && _lastAcceptedAltitude != null) {
      final dtSec =
          (now.difference(_lastAcceptedGpsTime!).inMilliseconds / 1000.0).abs();
      if (dtSec > 0.1) {
        final vSpeed = (rawAlt - _lastAcceptedAltitude!).abs() / dtSec;
        if (vSpeed > maxVerticalVelocityMps) {
          // Reject spike: do not let it contaminate filter
          return _buildResult();
        }
      }
    }

    _lastAcceptedGpsTime = now;
    _lastAcceptedAltitude = rawAlt;

    // 3. 5-sample rolling median filter on raw altitude
    _rawAltitudeBuffer.add(rawAlt);
    if (_rawAltitudeBuffer.length > 5) {
      _rawAltitudeBuffer.removeAt(0);
    }
    final sortedBuffer = List<double>.from(_rawAltitudeBuffer)..sort();
    final medianAlt = sortedBuffer[sortedBuffer.length ~/ 2];

    // 4. 1D Kalman filter update
    if (_kalmanAltitude == null) {
      _kalmanAltitude = medianAlt;
      _kalmanP = 25.0;
    } else {
      // Time update
      final dt = math.max(0.2, _rawAltitudeBuffer.length > 1 ? 1.0 : 1.0);
      _kalmanP += _kalmanQRate * dt;

      // Measurement update
      final r = (pos.altitudeAccuracy > 0)
          ? math.max(4.0, pos.altitudeAccuracy * pos.altitudeAccuracy)
          : _defaultKalmanR;
      final k = _kalmanP / (_kalmanP + r);
      _kalmanAltitude = _kalmanAltitude! + k * (medianAlt - _kalmanAltitude!);
      _kalmanP = (1.0 - k) * _kalmanP;
    }

    _currentSmoothedAltitude = _kalmanAltitude!;

    // 5. Incline / Grade computation over windows of at least 25 meters
    _distanceFixes.add(
      _DistanceAltitudeFix(
        distanceMeters: accumulatedDistanceMeters,
        altitudeMeters: _currentSmoothedAltitude,
        timestamp: now,
      ),
    );

    // Prune history older than 150 meters to prevent unbounded memory growth
    while (_distanceFixes.length > 2 &&
        (accumulatedDistanceMeters - _distanceFixes.first.distanceMeters) >
            150.0) {
      _distanceFixes.removeAt(0);
    }

    // Find the oldest fix in history that satisfies >= 25m horizontal distance baseline
    _DistanceAltitudeFix? baseFix;
    for (final fix in _distanceFixes) {
      if ((accumulatedDistanceMeters - fix.distanceMeters) >=
          minGradeWindowDistanceMeters) {
        baseFix = fix;
        break;
      }
    }

    if (baseFix != null) {
      final deltaD = accumulatedDistanceMeters - baseFix.distanceMeters;
      final deltaH = _currentSmoothedAltitude - baseFix.altitudeMeters;
      if (deltaD >= minGradeWindowDistanceMeters) {
        final rawGrade = deltaH / deltaD;
        _currentGrade = rawGrade.clamp(-maxGradeClamp, maxGradeClamp);
      }
    } else {
      _currentGrade = 0.0;
    }

    // 6. Cumulative Elevation Gain with 3.0-meter hysteresis threshold
    _updateCumulativeGainHysteresis(_currentSmoothedAltitude);

    return _buildResult();
  }

  /// Updates cumulative elevation gain using a 3.0m hysteresis climb detector.
  void _updateCumulativeGainHysteresis(double alt) {
    if (_climbReferenceAltitude == null) {
      _climbReferenceAltitude = alt;
      _peakAltitude = alt;
      return;
    }

    if (!_inClimbPhase) {
      // In descent/flat phase: track the local minimum
      if (alt < _climbReferenceAltitude!) {
        _climbReferenceAltitude = alt;
      } else if ((alt - _climbReferenceAltitude!) >=
          gainHysteresisThresholdMeters) {
        // Hysteresis threshold crossed: confirmed genuine climb!
        _inClimbPhase = true;
        _cumulativeGainMeters += (alt - _climbReferenceAltitude!);
        _peakAltitude = alt;
      }
    } else {
      // Active climb phase: accumulate upward gain
      if (alt > _peakAltitude!) {
        _cumulativeGainMeters += (alt - _peakAltitude!);
        _peakAltitude = alt;
      } else if ((_peakAltitude! - alt) >= gainHysteresisThresholdMeters) {
        // Descended at least 3m from peak: climb phase terminates
        _inClimbPhase = false;
        _climbReferenceAltitude = alt;
      }
    }
  }

  ElevationResult _buildResult() {
    return ElevationResult(
      smoothedAltitudeMeters: _currentSmoothedAltitude,
      grade: _currentGrade,
      cumulativeGainMeters: _cumulativeGainMeters,
    );
  }

  /// Resets all internal buffers, Kalman filter state, and gain accumulators.
  void reset() {
    _rawAltitudeBuffer.clear();
    _kalmanAltitude = null;
    _kalmanP = 25.0;
    _lastBarometerPressureHpa = null;
    _distanceFixes.clear();
    _cumulativeGainMeters = 0.0;
    _climbReferenceAltitude = null;
    _peakAltitude = null;
    _inClimbPhase = false;
    _lastAcceptedGpsTime = null;
    _lastAcceptedAltitude = null;
    _currentSmoothedAltitude = 0.0;
    _currentGrade = 0.0;
  }

  void dispose() {
    _barometerSubscription?.cancel();
    _barometerSubscription = null;
  }
}
