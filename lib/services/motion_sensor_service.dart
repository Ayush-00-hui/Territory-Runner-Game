import 'dart:async';
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
/// cadence and motion energy features across 10-second tumbling windows.
///
/// Cadence Algorithm:
/// - Target Band: 1.0 Hz - 3.5 Hz (60 - 210 Steps Per Minute).
/// - 3-point smoothing filter on linear acceleration magnitude.
/// - Adaptive threshold peak detection with minimum refractory period (0.285s = 1/3.5 Hz).
/// - Cadence confidence estimated from step regularity (coefficient of variation of inter-step intervals)
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

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final Stream<UserAccelerometerEvent>? customStream;

  final List<MotionWindow> _completedWindows = [];
  final List<_AccelSample> _currentSamples = [];

  DateTime? _windowStartTime;
  double _lastSampleTimeSec = 0.0;
  bool _isRunning = false;

  MotionSensorService({this.customStream});

  /// Returns unmodifiable list of completed 10-second motion windows.
  List<MotionWindow> get windows => List.unmodifiable(_completedWindows);

  /// Average cadence in steps per minute across all completed windows.
  double get averageCadenceSpm {
    if (_completedWindows.isEmpty) return 0.0;
    final sum = _completedWindows.fold<double>(
      0.0,
      (acc, w) => acc + w.cadenceSpm,
    );
    return sum / _completedWindows.length;
  }

  /// Average motion energy across all completed windows.
  double get averageMotionEnergy {
    if (_completedWindows.isEmpty) return 0.0;
    final sum = _completedWindows.fold<double>(
      0.0,
      (acc, w) => acc + w.motionEnergy,
    );
    return sum / _completedWindows.length;
  }

  /// Average cadence confidence across all completed windows.
  double get averageCadenceConfidence {
    if (_completedWindows.isEmpty) return 0.0;
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
    _windowStartTime = DateTime.now();
    _lastSampleTimeSec = 0.0;

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

    // Magnitude of linear acceleration (gravity removed by sensor fusion)
    final mag = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Compute relative timestamp in seconds
    final elapsedSec =
        now.difference(_windowStartTime!).inMilliseconds / 1000.0;
    _currentSamples.add(_AccelSample(elapsedSec, mag));
    _lastSampleTimeSec = elapsedSec;

    // When current tumbling window reaches 10 seconds, flush and compute window features
    if (elapsedSec >= windowDurationSec) {
      _flushCurrentWindow(now);
      _windowStartTime = now;
      _lastSampleTimeSec = 0.0;
    }
  }

  /// Manually add samples (useful for tests and synthetic trace ingestion).
  void addRawSample(double timestampSec, double x, double y, double z) {
    final mag = math.sqrt(x * x + y * y + z * z);
    _currentSamples.add(_AccelSample(timestampSec, mag));
    _lastSampleTimeSec = timestampSec;

    _windowStartTime ??= DateTime.now();

    if (_currentSamples.length >= 250 || timestampSec >= windowDurationSec) {
      _flushCurrentWindow(DateTime.now());
      _windowStartTime = DateTime.now();
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
    AppLogger.info(
      'Motion sensor stopped. Total analysis windows computed: ${_completedWindows.length}',
      tag: _tag,
    );
  }

  /// Clears all recorded windows and resets state.
  void reset() {
    stop();
    _completedWindows.clear();
    _currentSamples.clear();
    _windowStartTime = null;
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
    // Adaptive noise threshold: require peak to exceed at least 0.35 * std or 0.25 m/s²
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
      // Calculate inter-peak intervals (seconds per step)
      final intervals = <double>[];
      for (int i = 1; i < peakTimes.length; i++) {
        final dt = peakTimes[i] - peakTimes[i - 1];
        if (dt >= minPeakIntervalSec && dt <= maxPeakIntervalSec) {
          intervals.add(dt);
        }
      }

      if (intervals.isNotEmpty) {
        // Median interval for robust cadence estimation
        intervals.sort();
        final medianInterval = intervals[intervals.length ~/ 2];
        if (medianInterval > 0) {
          cadenceSpm = (60.0 / medianInterval).clamp(0.0, 240.0);
        }

        // Regularity confidence: coefficient of variation of valid step intervals
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

        // Regular athletic running has CV < 0.15. Random vibrations have CV > 0.40.
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
