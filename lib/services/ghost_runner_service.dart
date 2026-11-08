import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/run_log_entry.dart';
import 'run_log_service.dart';

/// Available Ghost Runner pacing modes configured prior to an active run.
enum GhostMode {
  /// Ghost Runner is disabled (default).
  off,

  /// Replays the most recent authentic run that started on this loop.
  lastOnLoop,

  /// Replays the fastest/best historical run on this loop.
  bestOnLoop,

  /// Replays the runner's all-time personal best run for this activity.
  personalBestActivity,
}

extension GhostModeExtension on GhostMode {
  String get label {
    switch (this) {
      case GhostMode.off:
        return 'Off';
      case GhostMode.lastOnLoop:
        return 'Last run on loop';
      case GhostMode.bestOnLoop:
        return 'Best run on loop';
      case GhostMode.personalBestActivity:
        return 'Personal best';
    }
  }

  String get description {
    switch (this) {
      case GhostMode.off:
        return 'No ghost runner active';
      case GhostMode.lastOnLoop:
        return 'Pace against your previous loop on this course';
      case GhostMode.bestOnLoop:
        return 'Pace against your best recorded loop here';
      case GhostMode.personalBestActivity:
        return 'Pace against your best overall run for this sport';
    }
  }
}

/// Result of evaluating candidate runs against ghost mode criteria.
class GhostSelectionResult {
  final GhostMode mode;
  final RunLogEntry? matchedRun;
  final String? calmExplanation;
  final double? frechetDistanceMeters;

  const GhostSelectionResult({
    required this.mode,
    this.matchedRun,
    this.calmExplanation,
    this.frechetDistanceMeters,
  });

  bool get isMatch => matchedRun != null;
}

/// Real-time comparison snapshot between the active runner and ghost.
class GhostTelemetry {
  /// Live geographic position of the ghost along its route.
  final LatLng? ghostPosition;

  /// Elapsed time (seconds) of the ghost run.
  final int ghostElapsedSeconds;

  /// Total duration (seconds) of the ghost run session.
  final int ghostTotalSeconds;

  /// Runner's orthogonal projection progress along ghost path (meters).
  final double runnerProgressDistanceM;

  /// Perpendicular cross-track deviation from ghost route (meters).
  final double runnerCrossTrackErrorM;

  /// Time differential in seconds:
  /// negative (< 0) indicates runner is ahead (took fewer seconds to reach this point).
  /// positive (> 0) indicates runner is behind.
  final int deltaSeconds;

  /// Human-readable calm status copy (e.g. "12 s ahead", "8 s behind", "Off ghost route").
  final String statusText;

  /// True when runner's cross-track distance exceeds 40 m.
  final bool isOffRoute;

  /// True when the ghost has reached the end of its course.
  final bool isGhostFinished;

  /// True when runner is leading the ghost by >= 1 second.
  final bool isRunnerAhead;

  /// True when runner is currently auto-paused or stationary.
  final bool isPaused;

  const GhostTelemetry({
    this.ghostPosition,
    required this.ghostElapsedSeconds,
    required this.ghostTotalSeconds,
    required this.runnerProgressDistanceM,
    required this.runnerCrossTrackErrorM,
    required this.deltaSeconds,
    required this.statusText,
    required this.isOffRoute,
    required this.isGhostFinished,
    required this.isRunnerAhead,
    this.isPaused = false,
  });

  GhostTelemetry copyWith({
    LatLng? ghostPosition,
    int? ghostElapsedSeconds,
    int? ghostTotalSeconds,
    double? runnerProgressDistanceM,
    double? runnerCrossTrackErrorM,
    int? deltaSeconds,
    String? statusText,
    bool? isOffRoute,
    bool? isGhostFinished,
    bool? isRunnerAhead,
    bool? isPaused,
  }) {
    return GhostTelemetry(
      ghostPosition: ghostPosition ?? this.ghostPosition,
      ghostElapsedSeconds: ghostElapsedSeconds ?? this.ghostElapsedSeconds,
      ghostTotalSeconds: ghostTotalSeconds ?? this.ghostTotalSeconds,
      runnerProgressDistanceM:
          runnerProgressDistanceM ?? this.runnerProgressDistanceM,
      runnerCrossTrackErrorM:
          runnerCrossTrackErrorM ?? this.runnerCrossTrackErrorM,
      deltaSeconds: deltaSeconds ?? this.deltaSeconds,
      statusText: statusText ?? this.statusText,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isGhostFinished: isGhostFinished ?? this.isGhostFinished,
      isRunnerAhead: isRunnerAhead ?? this.isRunnerAhead,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// Offline-first pure mathematical engine for Ghost Runner:
/// - Discrete Fréchet Distance loop matching on 100 equidistant points
/// - Orthogonal trajectory projection and cross-track distance calculation
/// - Ahead/behind pace differential calculation
/// - Pause and course-finish handling
class GhostRunnerService {
  static const double startProximityMaxMeters = 50.0;
  static const double frechetSimilarityMaxMeters = 45.0;
  static const double offRouteThresholdMeters = 40.0;
  static const int resamplePointCount = 100;

  static final GhostRunnerService _instance = GhostRunnerService._internal();
  final RunLogService _runLogService;

  factory GhostRunnerService({RunLogService? runLogService}) {
    if (runLogService != null) {
      return GhostRunnerService.custom(runLogService);
    }
    return _instance;
  }

  GhostRunnerService._internal() : _runLogService = RunLogService();

  GhostRunnerService.custom(this._runLogService);

  // ---------------------------------------------------------------------------
  // 1. Loop Matching & Candidate Selection
  // ---------------------------------------------------------------------------

  /// Identifies the appropriate ghost run based on chosen [mode], current GPS [origin],
  /// and [activityType] using strictly local runs.
  GhostSelectionResult selectGhostRun({
    required GhostMode mode,
    LatLng? origin,
    String activityType = 'running',
    List<RunLogEntry>? overrideRuns,
  }) {
    if (mode == GhostMode.off) {
      return const GhostSelectionResult(
        mode: GhostMode.off,
        calmExplanation: 'Ghost runner is disabled.',
      );
    }

    final allRuns = overrideRuns ?? _runLogService.getAllRuns();
    final sportRuns = allRuns
        .where(
          (r) =>
              r.activityType == activityType &&
              r.samples.length >= 2 &&
              r.distanceM >= 100.0,
        )
        .toList();

    if (sportRuns.isEmpty) {
      return GhostSelectionResult(
        mode: mode,
        calmExplanation: 'No completed runs found for this activity.',
      );
    }

    // 1. Personal Best for this Activity (does not require loop proximity)
    if (mode == GhostMode.personalBestActivity) {
      RunLogEntry? bestRun;
      double bestPace = double.infinity;

      for (final run in sportRuns) {
        if (run.movingSeconds <= 0 || run.distanceM <= 0) continue;
        final paceSecPerKm = run.movingSeconds / (run.distanceM / 1000.0);
        if (paceSecPerKm < bestPace) {
          bestPace = paceSecPerKm;
          bestRun = run;
        }
      }

      if (bestRun != null) {
        return GhostSelectionResult(mode: mode, matchedRun: bestRun);
      }
      return GhostSelectionResult(
        mode: mode,
        calmExplanation: 'No qualifying runs found for personal best.',
      );
    }

    // Origin coordinate is required for loop matching
    if (origin == null) {
      return GhostSelectionResult(
        mode: mode,
        calmExplanation: 'Waiting for GPS location to find nearby loops.',
      );
    }

    // Filter runs starting within 50 m of origin
    const distCalc = Distance();
    final nearbyRuns = sportRuns.where((run) {
      final first = run.samples.first;
      final startPt = LatLng(first.lat, first.lng);
      return distCalc.as(LengthUnit.Meter, origin, startPt) <=
          startProximityMaxMeters;
    }).toList();

    if (nearbyRuns.isEmpty) {
      return GhostSelectionResult(
        mode: mode,
        calmExplanation:
            'No previous runs found starting within 50 m of this location.',
      );
    }

    // Sort newest first
    nearbyRuns.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    // The most recent nearby run defines the baseline loop
    final baselineLoopRun = nearbyRuns.first;
    final baselinePoints = baselineLoopRun.samples
        .map((s) => LatLng(s.lat, s.lng))
        .toList(growable: false);

    if (mode == GhostMode.lastOnLoop) {
      return GhostSelectionResult(
        mode: mode,
        matchedRun: baselineLoopRun,
        frechetDistanceMeters: 0.0,
      );
    }

    if (mode == GhostMode.bestOnLoop) {
      // Find all runs that match baseline loop within discrete Fréchet threshold
      final matchingLoopRuns = <RunLogEntry>[];
      final baselineResampled = resamplePath(
        baselinePoints,
        resamplePointCount,
      );

      for (final candidate in nearbyRuns) {
        final candidatePoints = candidate.samples
            .map((s) => LatLng(s.lat, s.lng))
            .toList(growable: false);
        final candidateResampled = resamplePath(
          candidatePoints,
          resamplePointCount,
        );
        final frechet = computeDiscreteFrechetDistance(
          baselineResampled,
          candidateResampled,
        );

        if (frechet <= frechetSimilarityMaxMeters) {
          matchingLoopRuns.add(candidate);
        }
      }

      if (matchingLoopRuns.isEmpty) {
        return GhostSelectionResult(
          mode: mode,
          matchedRun: baselineLoopRun,
          calmExplanation: 'Single run on this loop selected.',
        );
      }

      // Pick the fastest run on this matching loop
      matchingLoopRuns.sort((a, b) {
        final paceA = a.movingSeconds / (a.distanceM / 1000.0);
        final paceB = b.movingSeconds / (b.distanceM / 1000.0);
        return paceA.compareTo(paceB);
      });

      return GhostSelectionResult(
        mode: mode,
        matchedRun: matchingLoopRuns.first,
      );
    }

    return GhostSelectionResult(
      mode: mode,
      calmExplanation: 'No ghost run matched.',
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Discrete Fréchet Distance & Path Resampling Algorithms
  // ---------------------------------------------------------------------------

  /// Resamples a polygonal geographic route into [targetCount] equidistant samples along arc-length.
  /// Guarantees exact point count [targetCount] with smooth spatial distribution.
  static List<LatLng> resamplePath(List<LatLng> points, int targetCount) {
    if (points.length < 2 || targetCount < 2) {
      return List<LatLng>.from(points);
    }

    const distCalc = Distance();
    final cumulative = <double>[0.0];
    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final segDist = distCalc.as(LengthUnit.Meter, points[i], points[i + 1]);
      totalDistance += segDist;
      cumulative.add(totalDistance);
    }

    if (totalDistance <= 0.0) {
      return List.generate(targetCount, (_) => points.first);
    }

    final resampled = <LatLng>[points.first];
    final step = totalDistance / (targetCount - 1);

    int segIndex = 0;
    for (int i = 1; i < targetCount - 1; i++) {
      final targetDist = i * step;
      while (segIndex < cumulative.length - 2 &&
          cumulative[segIndex + 1] < targetDist) {
        segIndex++;
      }

      final segStartDist = cumulative[segIndex];
      final segEndDist = cumulative[segIndex + 1];
      final segLength = segEndDist - segStartDist;

      if (segLength <= 0.0) {
        resampled.add(points[segIndex]);
      } else {
        final ratio = (targetDist - segStartDist) / segLength;
        final p0 = points[segIndex];
        final p1 = points[segIndex + 1];
        resampled.add(
          LatLng(
            p0.latitude + ratio * (p1.latitude - p0.latitude),
            p0.longitude + ratio * (p1.longitude - p0.longitude),
          ),
        );
      }
    }

    resampled.add(points.last);
    return resampled;
  }

  /// Computes the Discrete Fréchet Distance (Eiter & Mannila, 1994) between two polygonal curves.
  ///
  /// Mathematical Formulation:
  /// Let P = (p_1, ..., p_n) and Q = (q_1, ..., q_m) be polygonal curves in R^2.
  /// A coupling L between P and Q is a sequence of index pairs (alpha_1, beta_1), ..., (alpha_k, beta_k)
  /// such that (alpha_1, beta_1) = (1, 1), (alpha_k, beta_k) = (n, m), and
  /// alpha_{i+1} - alpha_i in {0, 1}, beta_{i+1} - beta_i in {0, 1}, with alpha_{i+1} + beta_{i+1} > alpha_i + beta_i.
  ///
  /// The Discrete Fréchet Distance is:
  ///   delta_dF(P, Q) = min_L max_{i=1..k} dist(p_{alpha_i}, q_{beta_i})
  ///
  /// Evaluated via Dynamic Programming in O(n * m) time and O(m) space using row swapping.
  static double computeDiscreteFrechetDistance(List<LatLng> p, List<LatLng> q) {
    if (p.isEmpty || q.isEmpty) return double.infinity;

    const distCalc = Distance();
    final n = p.length;
    final m = q.length;

    // Previous row and current row storage for space efficiency
    var prev = List<double>.filled(m, double.infinity);
    var curr = List<double>.filled(m, double.infinity);

    // Initialize (0, 0)
    prev[0] = distCalc.as(LengthUnit.Meter, p[0], q[0]);

    // Initialize first row (i = 0)
    for (int j = 1; j < m; j++) {
      final d = distCalc.as(LengthUnit.Meter, p[0], q[j]);
      prev[j] = math.max(prev[j - 1], d);
    }

    // Dynamic Programming iteration
    for (int i = 1; i < n; i++) {
      // First column (j = 0)
      final d0 = distCalc.as(LengthUnit.Meter, p[i], q[0]);
      curr[0] = math.max(prev[0], d0);

      for (int j = 1; j < m; j++) {
        final dij = distCalc.as(LengthUnit.Meter, p[i], q[j]);
        final minPrev = math.min(
          prev[j], // (i - 1, j)
          math.min(
            curr[j - 1], // (i, j - 1)
            prev[j - 1], // (i - 1, j - 1)
          ),
        );
        curr[j] = math.max(minPrev, dij);
      }

      // Swap rows
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[m - 1];
  }

  // ---------------------------------------------------------------------------
  // 3. Trajectory Projection & Ahead/Behind Pacing Engine
  // ---------------------------------------------------------------------------

  /// Projects runner's current GPS [runnerPosition] onto the ghost route,
  /// evaluating perpendicular cross-track error and cumulative progress distance.
  static RouteProjection projectOntoGhostRoute({
    required LatLng runnerPosition,
    required List<RunSample> ghostSamples,
  }) {
    if (ghostSamples.isEmpty) {
      return const RouteProjection(
        progressDistanceMeters: 0.0,
        crossTrackErrorMeters: 0.0,
        ghostTimeAtProgressMs: 0,
      );
    }

    if (ghostSamples.length == 1) {
      const distCalc = Distance();
      final p0 = LatLng(ghostSamples.first.lat, ghostSamples.first.lng);
      final d = distCalc.as(LengthUnit.Meter, runnerPosition, p0);
      return RouteProjection(
        progressDistanceMeters: 0.0,
        crossTrackErrorMeters: d,
        ghostTimeAtProgressMs: ghostSamples.first.timeOffsetMs,
      );
    }

    const distCalc = Distance();
    double minCrossTrack = double.infinity;
    double bestProgressDistance = 0.0;
    int bestGhostTimeMs = 0;

    double cumulativeDist = 0.0;

    for (int i = 0; i < ghostSamples.length - 1; i++) {
      final s0 = ghostSamples[i];
      final s1 = ghostSamples[i + 1];
      final p0 = LatLng(s0.lat, s0.lng);
      final p1 = LatLng(s1.lat, s1.lng);
      final segLength = distCalc.as(LengthUnit.Meter, p0, p1);

      if (segLength <= 0.0) {
        continue;
      }

      // Planar projection approximation centered at segment midpoint
      final latMid = (p0.latitude + p1.latitude) / 2.0 * (math.pi / 180.0);
      final cosLat = math.cos(latMid);

      final dx = (p1.longitude - p0.longitude) * cosLat;
      final dy = p1.latitude - p0.latitude;

      final px = (runnerPosition.longitude - p0.longitude) * cosLat;
      final py = runnerPosition.latitude - p0.latitude;

      final denom = dx * dx + dy * dy;
      final double t;
      if (denom > 0) {
        t = ((px * dx + py * dy) / denom).clamp(0.0, 1.0);
      } else {
        t = 0.0;
      }

      final projLat = p0.latitude + t * (p1.latitude - p0.latitude);
      final projLng = p0.longitude + t * (p1.longitude - p0.longitude);
      final projPoint = LatLng(projLat, projLng);

      final crossTrack = distCalc.as(
        LengthUnit.Meter,
        runnerPosition,
        projPoint,
      );

      if (crossTrack < minCrossTrack) {
        minCrossTrack = crossTrack;
        bestProgressDistance = cumulativeDist + t * segLength;
        final timeDelta = s1.timeOffsetMs - s0.timeOffsetMs;
        bestGhostTimeMs = (s0.timeOffsetMs + t * timeDelta).round();
      }

      cumulativeDist += segLength;
    }

    return RouteProjection(
      progressDistanceMeters: bestProgressDistance,
      crossTrackErrorMeters: minCrossTrack,
      ghostTimeAtProgressMs: bestGhostTimeMs,
    );
  }

  /// Evaluates real-time [GhostTelemetry] comparing runner against ghost.
  ///
  /// - Compares runner's elapsed moving seconds against the ghost's historical time
  ///   at the runner's projected distance.
  /// - Interpolates the ghost's live marker position at the runner's elapsed moving time.
  /// - Automatically flags off-route when cross-track error > 40 m.
  /// - Handles stationary pause states without delta distortion.
  GhostTelemetry computeTelemetry({
    required RunLogEntry ghostRun,
    required LatLng? runnerPosition,
    required int runnerMovingSeconds,
    required int runnerElapsedSeconds,
    bool isPaused = false,
  }) {
    final ghostTotalSeconds = ghostRun.movingSeconds > 0
        ? ghostRun.movingSeconds
        : (ghostRun.totalSeconds > 0 ? ghostRun.totalSeconds : 1);

    // 1. Compute ghost marker position at runner's current moving timestamp
    final ghostPosition = interpolateGhostPosition(
      ghostSamples: ghostRun.samples,
      elapsedSeconds: runnerMovingSeconds,
    );

    final isGhostFinished = runnerMovingSeconds >= ghostTotalSeconds;

    // If runner has no GPS fix yet
    if (runnerPosition == null) {
      return GhostTelemetry(
        ghostPosition: ghostPosition,
        ghostElapsedSeconds: math.min(runnerMovingSeconds, ghostTotalSeconds),
        ghostTotalSeconds: ghostTotalSeconds,
        runnerProgressDistanceM: 0.0,
        runnerCrossTrackErrorM: 0.0,
        deltaSeconds: 0,
        statusText: isPaused ? 'Paused' : 'Waiting for GPS',
        isOffRoute: false,
        isGhostFinished: isGhostFinished,
        isRunnerAhead: false,
        isPaused: isPaused,
      );
    }

    // 2. Project runner onto ghost route
    final projection = projectOntoGhostRoute(
      runnerPosition: runnerPosition,
      ghostSamples: ghostRun.samples,
    );

    final isOffRoute =
        projection.crossTrackErrorMeters > offRouteThresholdMeters;

    // 3. Ahead / Behind calculation
    // Ghost historical time to reach this progress distance in seconds
    final ghostTimeSec = projection.ghostTimeAtProgressMs / 1000.0;
    // Delta = runner moving time - ghost moving time at this distance
    // If delta < 0: runner was faster to reach this distance (AHEAD)
    // If delta > 0: runner was slower to reach this distance (BEHIND)
    final deltaSeconds = (runnerMovingSeconds - ghostTimeSec).round();
    final isRunnerAhead = deltaSeconds <= -1;

    // 4. Formulate calm status copy
    final String statusText;
    if (isOffRoute) {
      statusText = isPaused ? 'Paused • Off ghost route' : 'Off ghost route';
    } else if (isGhostFinished && runnerMovingSeconds > ghostTotalSeconds) {
      if (deltaSeconds <= -1) {
        statusText = isPaused
            ? 'Paused • Ghost finished • ${deltaSeconds.abs()} s ahead'
            : 'Ghost finished • ${deltaSeconds.abs()} s ahead';
      } else {
        statusText = isPaused
            ? 'Paused • Ghost finished • $deltaSeconds s behind'
            : 'Ghost finished • $deltaSeconds s behind';
      }
    } else if (isPaused) {
      if (deltaSeconds <= -1) {
        statusText = 'Paused • ${deltaSeconds.abs()} s ahead';
      } else if (deltaSeconds >= 1) {
        statusText = 'Paused • $deltaSeconds s behind';
      } else {
        statusText = 'Paused • On ghost pace';
      }
    } else {
      if (deltaSeconds <= -1) {
        statusText = '${deltaSeconds.abs()} s ahead';
      } else if (deltaSeconds >= 1) {
        statusText = '$deltaSeconds s behind';
      } else {
        statusText = 'On ghost pace';
      }
    }

    return GhostTelemetry(
      ghostPosition: ghostPosition,
      ghostElapsedSeconds: math.min(runnerMovingSeconds, ghostTotalSeconds),
      ghostTotalSeconds: ghostTotalSeconds,
      runnerProgressDistanceM: projection.progressDistanceMeters,
      runnerCrossTrackErrorM: projection.crossTrackErrorMeters,
      deltaSeconds: deltaSeconds,
      statusText: statusText,
      isOffRoute: isOffRoute,
      isGhostFinished: isGhostFinished,
      isRunnerAhead: isRunnerAhead,
      isPaused: isPaused,
    );
  }

  /// Interpolates the ghost marker position along its recorded samples
  /// at a given elapsed time offset in seconds.
  static LatLng? interpolateGhostPosition({
    required List<RunSample> ghostSamples,
    required int elapsedSeconds,
  }) {
    if (ghostSamples.isEmpty) return null;
    if (ghostSamples.length == 1) {
      return LatLng(ghostSamples.first.lat, ghostSamples.first.lng);
    }

    final targetOffsetMs = elapsedSeconds * 1000;

    if (targetOffsetMs <= ghostSamples.first.timeOffsetMs) {
      return LatLng(ghostSamples.first.lat, ghostSamples.first.lng);
    }

    if (targetOffsetMs >= ghostSamples.last.timeOffsetMs) {
      return LatLng(ghostSamples.last.lat, ghostSamples.last.lng);
    }

    for (int i = 0; i < ghostSamples.length - 1; i++) {
      final s0 = ghostSamples[i];
      final s1 = ghostSamples[i + 1];

      if (targetOffsetMs >= s0.timeOffsetMs &&
          targetOffsetMs <= s1.timeOffsetMs) {
        final timeSpan = s1.timeOffsetMs - s0.timeOffsetMs;
        if (timeSpan <= 0) {
          return LatLng(s0.lat, s0.lng);
        }
        final ratio = (targetOffsetMs - s0.timeOffsetMs) / timeSpan;
        return LatLng(
          s0.lat + ratio * (s1.lat - s0.lat),
          s0.lng + ratio * (s1.lng - s0.lng),
        );
      }
    }

    return LatLng(ghostSamples.last.lat, ghostSamples.last.lng);
  }
}

/// Immutable record of orthogonal route projection metrics.
class RouteProjection {
  final double progressDistanceMeters;
  final double crossTrackErrorMeters;
  final int ghostTimeAtProgressMs;

  const RouteProjection({
    required this.progressDistanceMeters,
    required this.crossTrackErrorMeters,
    required this.ghostTimeAtProgressMs,
  });
}
