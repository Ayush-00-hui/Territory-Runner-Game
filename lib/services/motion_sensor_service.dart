import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'package:territory_runner/core/logging/app_logger.dart';

/// Summary features for a 10-second motion sensor analysis window.
///
/// NOTE: Territory Runner strictly adheres to privacy-by-design. Raw high-frequency
/// accelerometer time-series are NEVER stored or transmitted off-device. Only these
/// coarsened statistical summaries are retained for anti-cheat validation.
class MotionWindow {
  final DateTime startTime;
  final double durationSeconds;
  final double cadenceSpm;
  final double motionEnergy;
  final double cadenceConfidence;

  const MotionWindow({
    required this.startTime,
    required this.durationSeconds,
    required this.cadenceSpm,
    required this.motionEnergy,
    required this.cadenceConfidence,
  });

  Map<String, dynamic> toJson() => {
    'start_time': startTime.toIso8601String(),
    'duration_seconds': durationSeconds,
    'cadence_spm': cadenceSpm,
    'motion_energy': motionEnergy,
    'cadence_confidence': cadenceConfidence,
  };

  factory MotionWindow.fromJson(Map<String, dynamic> json) => MotionWindow(
    startTime: DateTime.parse(json['start_time'] as String),
    durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 10.0,
    cadenceSpm: (json['cadence_spm'] as num?)?.toDouble() ?? 0.0,
    motionEnergy: (json['motion_energy'] as num?)?.toDouble() ?? 0.0,
    cadenceConfidence: (json['cadence_confidence'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Internal sample point used during the active 10s accumulation window.
class _AccelSample {
  final double timestampSec;
  final double
  magnitude; // Linear acceleration magnitude: sqrt(x^2 + y^2 + z^2)

  const _AccelSample(this.timestampSec, this.magnitude);
}

/// Samples the device accelerometer at ~25 Hz during active runs and extracts
/// cadence and motion energy features across 10-second tumbling windows, while
/// providing real-time online step detection and continuous cadence estimation.
///
/// Cadence Algorithm:
/// - Target Band: 1.0 Hz - 3.5 Hz (60 - 210 Steps Per Minute).
/// - 3-point smoothing filter on linear acceleration magnitude.
/// - Adaptive threshold peak detection with minimum refractory period (0.285s = 1/3.5 Hz).
/// - Online step counting with phone in pocket, hand, or armband.
/// - Cadence confidence estimated from step regularity (CV of inter-step intervals)
///   and signal-to-noise motion energy ratio.
class MotionSensorService {
  static const String _tag = 'MotionSensorService';

  // Analysis Window Configuration
  static const double windowDurationSec = 10.0;
  static const double targetSamplingIntervalMs = 40.0; // ~25 Hz
  static const double minCadenceHz = 1.0; // 60 SPM
  static const double maxCadenceHz = 3.5; // 210 SPM
  static const double minPeakIntervalSec = 1.0 / maxCadenceHz; // ~0.285s
  static const double maxPeakIntervalSec = 1.0 / minCadenceHz; // 1.0s

  static MotionSensorService? _instance;

  /// Singleton access for app execution, with factory support for mock injection in tests.
  factory MotionSensorService({Stream<UserAccelerometerEvent>? customStream}) {
    if (customStream != null) {
      return MotionSensorService._internal(customStream: customStream);
    }
    return _instance ??= MotionSensorService._internal();
  }

  MotionSensorService._internal({this.customStream});

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final Stream<UserAccelerometerEvent>? customStream;

  // Windowed Batch State (for Anti-Cheat & Sync Queue)
  final List<MotionWindow> _completedWindows = [];
  final List<_AccelSample> _currentSamples = [];
  DateTime? _windowStartTime;
  double _lastSampleTimeSec = 0.0;
  bool _isRunning = false;

  // Real-Time Online Step & Cadence State
  int _liveStepCount = 0;
  double _currentCadenceSpm = 0.0;
  double _currentCadenceConfidence = 0.0;
  double _currentMotionEnergy = 0.0;
  double _lastStepTimeSec = -1.0;
  final List<double> _recentStepIntervals = [];

  // Running magnitude statistics for online dynamic threshold
  double _runningMeanMag = 0.0;
  double _runningVarMag = 0.0;
  final List<_AccelSample> _onlineSmoothingBuffer = [];

  /// Returns unmodifiable list of completed 10-second motion windows.
  List<MotionWindow> get windows => List.unmodifiable(_completedWindows);

  /// Total steps detected in real-time by accelerometer since run started.
  int get liveStepCount => _liveStepCount;

  /// Live instantaneous/short-window cadence in steps per minute.
  double get currentCadenceSpm => _currentCadenceSpm;

  /// Live confidence score [0.0 - 1.0] of step regularity and motion strength.
  double get currentCadenceConfidence => _currentCadenceConfidence;

  /// Live motion energy (mean squared linear acceleration).
  double get currentMotionEnergy => _currentMotionEnergy;

  /// Returns whether step detection is currently deemed an estimate due to
  /// low confidence (< 0.40) or low motion energy (< 0.15).
  bool get isStepCountEstimated {
    if (_liveStepCount == 0) return true;
    if (_currentCadenceConfidence < 0.40) return true;
    if (_currentMotionEnergy < 0.15) return true;
    return false;
  }

  /// Computes stride length in meters: speed (m/s) / cadence (steps/s).
  ///
  /// Returns null if stationary or cadence is below walking threshold.
  /// Clamped to plausible physiological range: [0.4m, 2.2m].
  double? computeStrideLength(double speedKmh) {
    if (_currentCadenceSpm < 40.0 || speedKmh < 1.0) return null;
    final speedMs = speedKmh / 3.6;
    final stepsPerSec = _currentCadenceSpm / 60.0;
    if (stepsPerSec <= 0) return null;
    final stride = speedMs / stepsPerSec;
    return stride.clamp(0.4, 2.2);
  }

  /// Average cadence in steps per minute across all completed windows.
  double get averageCadenceSpm {
    if (_completedWindows.isEmpty) return _currentCadenceSpm;
    final sum = _completedWindows.fold<double>(
      0.0,
      (acc, w) => acc + w.cadenceSpm,
    );
    return sum / _completedWindows.length;
  }

  /// Average motion energy across all completed windows.
  double get averageMotionEnergy {
    if (_completedWindows.isEmpty) return _currentMotionEnergy;
    final sum = _completedWindows.fold<double>(
      0.0,
      (acc, w) => acc + w.motionEnergy,
    );
    return sum / _completedWindows.length;
  }

  /// Average cadence confidence across all completed windows.
  double get averageCadenceConfidence {
    if (_completedWindows.isEmpty) return _currentCadenceConfidence;
    final sum = _completedWindows.fold<double>(
      0.0,
      (acc, w) => acc + w.cadenceConfidence,
    );
    return sum / _completedWindows.length;
  }

  bool get isRunning => _isRunning;

  /// Starts sampling the linear accelerometer at ~25 Hz.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _completedWindows.clear();
    _currentSamples.clear();
    _onlineSmoothingBuffer.clear();
    _recentStepIntervals.clear();
    _liveStepCount = 0;
    _currentCadenceSpm = 0.0;
    _currentCadenceConfidence = 0.0;
    _currentMotionEnergy = 0.0;
    _runningMeanMag = 0.0;
    _runningVarMag = 0.0;
    _lastStepTimeSec = -1.0;
    _windowStartTime = DateTime.now();
    _lastSampleTimeSec = 0.0;

    if (customStream == null &&
        Platform.environment.containsKey('FLUTTER_TEST')) {
      AppLogger.info(
        'Motion sensor cadence service idle in test environment without mock stream',
        tag: _tag,
      );
      return;
    }

    try {
      final stream =
          customStream ??
          userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 40),
          );

      _subscription = stream.listen(
        _onAccelerometerEvent,
        onError: (err) {
          AppLogger.warning('Accelerometer stream error: $err', tag: _tag);
        },
        cancelOnError: false,
      );
      AppLogger.info(
        'Motion sensor cadence service started at ~25 Hz',
        tag: _tag,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to initialize accelerometer stream: $e',
        tag: _tag,
      );
    }
  }

  /// Process an incoming accelerometer event.
  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    if (!_isRunning) return;

    final now = DateTime.now();
    _windowStartTime ??= now;

    // Compute relative timestamp in seconds
    final elapsedSec =
        now.difference(_windowStartTime!).inMilliseconds / 1000.0;

    _processSample(elapsedSec, event.x, event.y, event.z, now);
  }

  /// Manually add samples (useful for tests and synthetic trace ingestion).
  void addRawSample(double timestampSec, double x, double y, double z) {
    _windowStartTime ??= DateTime.now();
    _processSample(timestampSec, x, y, z, DateTime.now());
  }

  /// Unified sample processing pipeline for both live streams and test replay.
  void _processSample(
    double timestampSec,
    double x,
    double y,
    double z,
    DateTime now,
  ) {
    final mag = math.sqrt(x * x + y * y + z * z);
    _currentSamples.add(_AccelSample(timestampSec, mag));
    _lastSampleTimeSec = timestampSec;

    // 1. Online dynamic threshold statistics (exponential moving averages)
    const alpha = 0.05;
    final diff = mag - _runningMeanMag;
    _runningMeanMag += alpha * diff;
    _runningVarMag = (1.0 - alpha) * (_runningVarMag + alpha * diff * diff);
    final stdMag = math.sqrt(_runningVarMag);
    _currentMotionEnergy =
        (1.0 - alpha) * _currentMotionEnergy + alpha * (mag * mag);

    // 2. Online 3-point smoothing buffer
    _onlineSmoothingBuffer.add(_AccelSample(timestampSec, mag));
    if (_onlineSmoothingBuffer.length > 3) {
      _onlineSmoothingBuffer.removeAt(0);
    }

    if (_onlineSmoothingBuffer.length == 3) {
      final sPrev = _onlineSmoothingBuffer[0].magnitude;
      final sCurr = _onlineSmoothingBuffer[1].magnitude;
      final sNext = _onlineSmoothingBuffer[2].magnitude;
      final tCurr = _onlineSmoothingBuffer[1].timestampSec;

      // Centered 3-point smoothed magnitude
      final smoothedCurr = (sPrev + 2.0 * sCurr + sNext) / 4.0;
      final threshold = _runningMeanMag + math.max(0.20, 0.35 * stdMag);

      // Local peak condition: sCurr is higher than neighbors and exceeds adaptive threshold
      if (smoothedCurr >= threshold && sCurr > sPrev && sCurr >= sNext) {
        if (_lastStepTimeSec < 0 ||
            (tCurr - _lastStepTimeSec) >= minPeakIntervalSec) {
          _liveStepCount++;

          if (_lastStepTimeSec >= 0) {
            final interval = tCurr - _lastStepTimeSec;
            if (interval >= minPeakIntervalSec &&
                interval <= maxPeakIntervalSec) {
              _recentStepIntervals.add(interval);
              if (_recentStepIntervals.length > 6) {
                _recentStepIntervals.removeAt(0);
              }

              // Update online cadence from median interval
              final sorted = List<double>.from(_recentStepIntervals)..sort();
              final medianIv = sorted[sorted.length ~/ 2];
              if (medianIv > 0) {
                _currentCadenceSpm = (60.0 / medianIv).clamp(40.0, 240.0);
              }

              // Confidence from CV of inter-step intervals
              final meanIv =
                  _recentStepIntervals.reduce((a, b) => a + b) /
                  _recentStepIntervals.length;
              double sumSqDiff = 0.0;
              for (final iv in _recentStepIntervals) {
                sumSqDiff += (iv - meanIv) * (iv - meanIv);
              }
              final stdIv = math.sqrt(sumSqDiff / _recentStepIntervals.length);
              final cv = meanIv > 0 ? (stdIv / meanIv) : 1.0;

              final regularity = (1.0 - (cv / 0.35)).clamp(0.0, 1.0);
              final energyScore = (_currentMotionEnergy / 1.5).clamp(0.0, 1.0);
              _currentCadenceConfidence = (regularity * 0.7 + energyScore * 0.3)
                  .clamp(0.0, 1.0);
            }
          }
          _lastStepTimeSec = tCurr;
        }
      }
    }

    // 3. Cadence decay: if no step detected for > 2.0 seconds, decay cadence to 0
    if (_lastStepTimeSec >= 0 && (timestampSec - _lastStepTimeSec) > 2.0) {
      _currentCadenceSpm = 0.0;
      _currentCadenceConfidence = 0.0;
    }

    // 4. Batch Tumbling Window Flush (every 10s or 250 samples)
    if (_currentSamples.length >= 250 || timestampSec >= windowDurationSec) {
      _flushCurrentWindow(now);
      _windowStartTime = now;
      _lastSampleTimeSec = 0.0;
    }
  }

  /// Stops sampling and flushes any partial window with at least 3 seconds of data.
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;

    if (_currentSamples.length >= 75) {
      // At least ~3s of data at 25 Hz
      _flushCurrentWindow(DateTime.now());
    }
    _currentSamples.clear();
    _onlineSmoothingBuffer.clear();
    AppLogger.info(
      'Motion sensor stopped. Steps: $_liveStepCount, windows: ${_completedWindows.length}',
      tag: _tag,
    );
  }

  /// Clears all recorded windows and resets state.
  void reset() {
    stop();
    _completedWindows.clear();
    _currentSamples.clear();
    _onlineSmoothingBuffer.clear();
    _recentStepIntervals.clear();
    _windowStartTime = null;
    _liveStepCount = 0;
    _currentCadenceSpm = 0.0;
    _currentCadenceConfidence = 0.0;
    _currentMotionEnergy = 0.0;
    _lastStepTimeSec = -1.0;
  }

  /// Analyzes the accumulated samples in the window, derives cadence, energy,
  /// and confidence, and immediately discards the raw samples.
  void _flushCurrentWindow(DateTime windowEndTime) {
    if (_currentSamples.isEmpty) return;

    final windowStart =
        _windowStartTime ?? windowEndTime.subtract(const Duration(seconds: 10));
    final duration = math.max(
      1.0,
      _lastSampleTimeSec > 0 ? _lastSampleTimeSec : 10.0,
    );

    final n = _currentSamples.length;

    // 1. Compute Motion Energy: Mean squared linear acceleration
    double energySum = 0.0;
    double magSum = 0.0;
    for (int i = 0; i < n; i++) {
      final m = _currentSamples[i].magnitude;
      energySum += m * m;
      magSum += m;
    }
    final motionEnergy = energySum / n;
    final meanMag = magSum / n;

    // 2. 3-point smoothing filter on demeaned magnitude
    final smoothed = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final prev = i > 0
          ? _currentSamples[i - 1].magnitude - meanMag
          : _currentSamples[i].magnitude - meanMag;
      final curr = _currentSamples[i].magnitude - meanMag;
      final next = i + 1 < n
          ? _currentSamples[i + 1].magnitude - meanMag
          : _currentSamples[i].magnitude - meanMag;
      smoothed[i] = (prev + 2.0 * curr + next) / 4.0;
    }

    // 3. Peak Detection in 1.0 - 3.5 Hz band
    double varianceSum = 0.0;
    for (int i = 0; i < n; i++) {
      varianceSum += smoothed[i] * smoothed[i];
    }
    final stdMag = math.sqrt(varianceSum / n);
    final minPeakThreshold = math.max(0.20, 0.35 * stdMag);

    final peakTimes = <double>[];
    double lastPeakTime = -1.0;

    for (int i = 1; i < n - 1; i++) {
      final sPrev = smoothed[i - 1];
      final sCurr = smoothed[i];
      final sNext = smoothed[i + 1];

      // Local maximum check
      if (sCurr > sPrev && sCurr > sNext && sCurr >= minPeakThreshold) {
        final t = _currentSamples[i].timestampSec;
        if (lastPeakTime < 0 || (t - lastPeakTime) >= minPeakIntervalSec) {
          peakTimes.add(t);
          lastPeakTime = t;
        }
      }
    }

    // 4. Derive Cadence (SPM) and Regularity Confidence
    double cadenceSpm = 0.0;
    double cadenceConfidence = 0.0;

    if (peakTimes.length >= 2 && motionEnergy >= 0.15) {
      final intervals = <double>[];
      for (int i = 1; i < peakTimes.length; i++) {
        final dt = peakTimes[i] - peakTimes[i - 1];
        if (dt >= minPeakIntervalSec && dt <= maxPeakIntervalSec) {
          intervals.add(dt);
        }
      }

      if (intervals.isNotEmpty) {
        intervals.sort();
        final medianInterval = intervals[intervals.length ~/ 2];
        if (medianInterval > 0) {
          cadenceSpm = (60.0 / medianInterval).clamp(0.0, 240.0);
        }

        double sumInterval = 0.0;
        for (final iv in intervals) {
          sumInterval += iv;
        }
        final meanInterval = sumInterval / intervals.length;

        double sumSqDiff = 0.0;
        for (final iv in intervals) {
          sumSqDiff += (iv - meanInterval) * (iv - meanInterval);
        }
        final stdInterval = math.sqrt(sumSqDiff / intervals.length);
        final cv = meanInterval > 0 ? (stdInterval / meanInterval) : 1.0;

        final regularityScore = (1.0 - (cv / 0.35)).clamp(0.0, 1.0);
        final energyScore = (motionEnergy / 1.5).clamp(0.0, 1.0);
        final validStepRatio = (intervals.length / peakTimes.length).clamp(
          0.0,
          1.0,
        );

        cadenceConfidence =
            (regularityScore * 0.6 + energyScore * 0.2 + validStepRatio * 0.2)
                .clamp(0.0, 1.0);
      }
    }

    _completedWindows.add(
      MotionWindow(
        startTime: windowStart,
        durationSeconds: duration,
        cadenceSpm: cadenceSpm,
        motionEnergy: motionEnergy,
        cadenceConfidence: cadenceConfidence,
      ),
    );

    // CRITICAL: Immediately clear raw samples to guarantee privacy
    _currentSamples.clear();
  }
}
