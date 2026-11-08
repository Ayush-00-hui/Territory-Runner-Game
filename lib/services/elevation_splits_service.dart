import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/run_log_entry.dart';
import 'app_preferences.dart';

/// Single split segment (1 km or 1 mile, or final remainder).
class RunSplit {
  final int index;
  final double distanceMeters;
  final double displayDistance;
  final int durationSeconds;
  final int paceSeconds;
  final double elevationChangeMeters;
  final double elevationGainMeters;
  final double elevationLossMeters;
  final double averageGrade; // e.g. 0.035 = +3.5%
  final bool isBest;
  final bool isPartial;
  final DistanceUnit unit;

  const RunSplit({
    required this.index,
    required this.distanceMeters,
    required this.displayDistance,
    required this.durationSeconds,
    required this.paceSeconds,
    required this.elevationChangeMeters,
    required this.elevationGainMeters,
    required this.elevationLossMeters,
    required this.averageGrade,
    this.isBest = false,
    this.isPartial = false,
    required this.unit,
  });

  RunSplit copyWith({bool? isBest}) {
    return RunSplit(
      index: index,
      distanceMeters: distanceMeters,
      displayDistance: displayDistance,
      durationSeconds: durationSeconds,
      paceSeconds: paceSeconds,
      elevationChangeMeters: elevationChangeMeters,
      elevationGainMeters: elevationGainMeters,
      elevationLossMeters: elevationLossMeters,
      averageGrade: averageGrade,
      isBest: isBest ?? this.isBest,
      isPartial: isPartial,
      unit: unit,
    );
  }

  /// Formatted split pace string (e.g. 5'14").
  String get formattedPace {
    if (paceSeconds <= 0 || paceSeconds > 3600) return "--'--\"";
    final min = paceSeconds ~/ 60;
    final sec = paceSeconds % 60;
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  /// Formatted elevation change in meters or feet with sign (e.g. "+14 m" or "-32 ft").
  String get formattedElevationChange {
    if (unit == DistanceUnit.imperial) {
      final feet = (elevationChangeMeters * 3.28084).round();
      final sign = feet > 0 ? '+' : (feet < 0 ? '-' : '');
      return '$sign${feet.abs()} ft';
    } else {
      final meters = elevationChangeMeters.round();
      final sign = meters > 0 ? '+' : (meters < 0 ? '-' : '');
      return '$sign${meters.abs()} m';
    }
  }

  /// Formatted grade percentage (e.g. "+3.5%").
  String get formattedGrade {
    final pct = averageGrade * 100.0;
    final sign = pct > 0 ? '+' : (pct < 0 ? '' : '');
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}

/// Point on the downsampled elevation chart.
class ElevationPoint {
  final double distanceMeters;
  final double altitudeMeters;
  final double lat;
  final double lng;
  final int timeOffsetMs;
  final double grade;

  const ElevationPoint({
    required this.distanceMeters,
    required this.altitudeMeters,
    required this.lat,
    required this.lng,
    required this.timeOffsetMs,
    this.grade = 0.0,
  });

  LatLng get latLng => LatLng(lat, lng);
}

/// Complete elevation profile and splits dataset for a run session.
class ElevationProfileData {
  final bool hasValidAltitude;
  final String? unavailableReason;
  final List<ElevationPoint> points;
  final double minAltitudeMeters;
  final double maxAltitudeMeters;
  final double totalGainMeters;
  final double totalLossMeters;
  final List<RunSplit> splits;
  final DistanceUnit unit;

  const ElevationProfileData({
    required this.hasValidAltitude,
    this.unavailableReason,
    this.points = const [],
    this.minAltitudeMeters = 0.0,
    this.maxAltitudeMeters = 0.0,
    this.totalGainMeters = 0.0,
    this.totalLossMeters = 0.0,
    this.splits = const [],
    required this.unit,
  });

  static const ElevationProfileData empty = ElevationProfileData(
    hasValidAltitude: false,
    unavailableReason: 'No GPS samples recorded for this run.',
    unit: DistanceUnit.metric,
  );

  /// Formatted minimum altitude with units.
  String get formattedMinAltitude {
    if (unit == DistanceUnit.imperial) {
      return '${(minAltitudeMeters * 3.28084).round()} ft';
    }
    return '${minAltitudeMeters.round()} m';
  }

  /// Formatted maximum altitude with units.
  String get formattedMaxAltitude {
    if (unit == DistanceUnit.imperial) {
      return '${(maxAltitudeMeters * 3.28084).round()} ft';
    }
    return '${maxAltitudeMeters.round()} m';
  }

  /// Formatted total elevation gain with units (e.g. "+42 m").
  String get formattedGain {
    if (unit == DistanceUnit.imperial) {
      return '+${(totalGainMeters * 3.28084).round()} ft';
    }
    return '+${totalGainMeters.round()} m';
  }

  /// Formatted total elevation loss with units (e.g. "-28 m").
  String get formattedLoss {
    if (unit == DistanceUnit.imperial) {
      return '-${(totalLossMeters * 3.28084).round()} ft';
    }
    return '-${totalLossMeters.round()} m';
  }
}

/// Offline elevation profile computation, per-km/mile splits generator, and downsampling cache.
class ElevationSplitsService {
  static final ElevationSplitsService _instance =
      ElevationSplitsService._internal();
  factory ElevationSplitsService() => _instance;
  ElevationSplitsService._internal();

  static const int targetProfilePoints = 300;
  static const double minSplitDistanceThresholdM = 50.0;
  static const double gainHysteresisThresholdMeters = 3.0;
  static const double maxVerticalVelocityMps =
      15.0; // 54 km/h climb spike threshold
  static const double maxAcceptableHorizontalAccuracy = 35.0;

  // In-memory cache: key = "$cacheKeyPrefix$unitName"
  final Map<String, ElevationProfileData> _cache = {};

  /// Clears downsampled elevation cache (e.g. on unit change or data reset).
  void clearCache() {
    _cache.clear();
  }

  /// Processes run samples into splits and elevation profile data.
  ElevationProfileData computeProfile({
    required List<RunSample> samples,
    DistanceUnit? unit,
    String? cacheKey,
  }) {
    final activeUnit = unit ?? AppPreferences().unit;
    final key = cacheKey != null ? '${cacheKey}_${activeUnit.name}' : null;

    if (key != null && _cache.containsKey(key)) {
      return _cache[key]!;
    }

    if (samples.length < 2) {
      final res = ElevationProfileData(
        hasValidAltitude: false,
        unavailableReason:
            'Elevation chart unavailable: run track has insufficient points.',
        unit: activeUnit,
      );
      if (key != null) _cache[key] = res;
      return res;
    }

    // 1. Evaluate Altitude Validity & Quality
    int validAltCount = 0;
    for (final s in samples) {
      if (s.altitude != null && s.altitude != 0.0) {
        if (s.accuracy == null ||
            s.accuracy! <= maxAcceptableHorizontalAccuracy) {
          validAltCount++;
        }
      }
    }

    final validRatio = validAltCount / samples.length;
    final bool hasAcceptableAltitude = validAltCount >= 4 && validRatio >= 0.25;

    // 2. Build cumulative distance and smoothed points track
    const distanceCalculator = Distance();
    final rawTrack = <_TrackPoint>[];
    double accumulatedDistM = 0.0;

    // Rolling median filter for raw altitude (5 samples)
    final medianBuffer = <double>[];
    double? smoothedAlt;
    double? lastAcceptedAlt;
    int? lastAcceptedTimeMs;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (i > 0) {
        final prev = samples[i - 1];
        final stepDist = distanceCalculator.as(
          LengthUnit.Meter,
          LatLng(prev.lat, prev.lng),
          LatLng(s.lat, s.lng),
        );
        accumulatedDistM += stepDist;
      }

      if (hasAcceptableAltitude && s.altitude != null) {
        final rawAlt = s.altitude!;
        final timeMs = s.timeOffsetMs;

        // Vertical velocity spike rejection
        bool rejectSpike = false;
        if (lastAcceptedAlt != null && lastAcceptedTimeMs != null) {
          final dtSec = math.max(
            0.2,
            (timeMs - lastAcceptedTimeMs).abs() / 1000.0,
          );
          final vSpeed = (rawAlt - lastAcceptedAlt).abs() / dtSec;
          if (vSpeed > maxVerticalVelocityMps) {
            rejectSpike = true;
          }
        }

        if (!rejectSpike) {
          lastAcceptedAlt = rawAlt;
          lastAcceptedTimeMs = timeMs;

          medianBuffer.add(rawAlt);
          if (medianBuffer.length > 5) medianBuffer.removeAt(0);

          final sorted = List<double>.from(medianBuffer)..sort();
          final medianVal = sorted[sorted.length ~/ 2];

          // 1D Kalman-like smoothing
          if (smoothedAlt == null) {
            smoothedAlt = medianVal;
          } else {
            smoothedAlt = smoothedAlt * 0.70 + medianVal * 0.30;
          }
        }
      }

      rawTrack.add(
        _TrackPoint(
          distanceMeters: accumulatedDistM,
          altitudeMeters: smoothedAlt ?? 0.0,
          lat: s.lat,
          lng: s.lng,
          timeOffsetMs: s.timeOffsetMs,
        ),
      );
    }

    // 3. Compute Hysteresis Gain and Loss
    double totalGainM = 0.0;
    double totalLossM = 0.0;
    double minAlt = double.infinity;
    double maxAlt = -double.infinity;

    if (hasAcceptableAltitude && rawTrack.isNotEmpty) {
      double climbRef = rawTrack.first.altitudeMeters;
      double climbPeak = climbRef;
      bool inClimb = false;

      double descentRef = rawTrack.first.altitudeMeters;
      double descentTrough = descentRef;
      bool inDescent = false;

      for (final pt in rawTrack) {
        final a = pt.altitudeMeters;
        if (a < minAlt) minAlt = a;
        if (a > maxAlt) maxAlt = a;

        // Upward climb hysteresis
        if (!inClimb) {
          if (a < climbRef) {
            climbRef = a;
          } else if ((a - climbRef) >= gainHysteresisThresholdMeters) {
            inClimb = true;
            totalGainM += (a - climbRef);
            climbPeak = a;
          }
        } else {
          if (a > climbPeak) {
            totalGainM += (a - climbPeak);
            climbPeak = a;
          } else if ((climbPeak - a) >= gainHysteresisThresholdMeters) {
            inClimb = false;
            climbRef = a;
          }
        }

        // Downward descent hysteresis
        if (!inDescent) {
          if (a > descentRef) {
            descentRef = a;
          } else if ((descentRef - a) >= gainHysteresisThresholdMeters) {
            inDescent = true;
            totalLossM += (descentRef - a);
            descentTrough = a;
          }
        } else {
          if (a < descentTrough) {
            totalLossM += (descentTrough - a);
            descentTrough = a;
          } else if ((a - descentTrough) >= gainHysteresisThresholdMeters) {
            inDescent = false;
            descentRef = a;
          }
        }
      }
    }

    if (minAlt == double.infinity) minAlt = 0.0;
    if (maxAlt == -double.infinity) maxAlt = 0.0;

    // 4. Compute Splits (Unit Step: 1000m metric, 1609.344m imperial)
    final double unitStepM = activeUnit == DistanceUnit.imperial
        ? 1609.344
        : 1000.0;
    final splits = _calculateSplits(
      rawTrack: rawTrack,
      unitStepM: unitStepM,
      unit: activeUnit,
      hasAltitude: hasAcceptableAltitude,
    );

    // 5. Downsample Track to ~300 Points
    final downsampledPoints = _downsampleTrack(
      rawTrack,
      targetCount: targetProfilePoints,
    );

    final String? reason;
    if (!hasAcceptableAltitude) {
      reason = 'Elevation chart unavailable: altitude data was missing or had low GPS accuracy.';
    } else {
      reason = null;
    }

    final result = ElevationProfileData(
      hasValidAltitude: hasAcceptableAltitude,
      unavailableReason: reason,
      points: downsampledPoints,
      minAltitudeMeters: minAlt,
      maxAltitudeMeters: maxAlt,
      totalGainMeters: totalGainM,
      totalLossMeters: totalLossM,
      splits: splits,
      unit: activeUnit,
    );

    if (key != null) {
      if (_cache.length > 50) _cache.remove(_cache.keys.first);
      _cache[key] = result;
    }

    return result;
  }

  /// Calculates per-km or per-mile splits from the continuous track.
  List<RunSplit> _calculateSplits({
    required List<_TrackPoint> rawTrack,
    required double unitStepM,
    required DistanceUnit unit,
    required bool hasAltitude,
  }) {
    if (rawTrack.isEmpty) return [];

    final splits = <RunSplit>[];

    int currentSplitIndex = 1;
    int startIndex = 0;
    double currentBoundaryM = unitStepM;

    for (int i = 0; i < rawTrack.length; i++) {
      final pt = rawTrack[i];

      if (pt.distanceMeters >= currentBoundaryM) {
        final startPt = rawTrack[startIndex];
        final splitDistM = pt.distanceMeters - startPt.distanceMeters;
        final durationSec = math.max(
          1,
          (pt.timeOffsetMs - startPt.timeOffsetMs) ~/ 1000,
        );

        final paceSec = (durationSec / (splitDistM / unitStepM)).round();
        final elevChange = hasAltitude
            ? (pt.altitudeMeters - startPt.altitudeMeters)
            : 0.0;
        final grade = splitDistM > 0
            ? (elevChange / splitDistM).clamp(-0.20, 0.20)
            : 0.0;

        splits.add(
          RunSplit(
            index: currentSplitIndex,
            distanceMeters: splitDistM,
            displayDistance: 1.0,
            durationSeconds: durationSec,
            paceSeconds: paceSec,
            elevationChangeMeters: elevChange,
            elevationGainMeters: math.max(0.0, elevChange),
            elevationLossMeters: math.max(0.0, -elevChange),
            averageGrade: grade,
            isPartial: false,
            unit: unit,
          ),
        );

        startIndex = i;
        currentSplitIndex++;
        currentBoundaryM += unitStepM;
      }
    }

    // Handle remainder or short run (< 1 unit)
    final lastPt = rawTrack.last;
    final startPt = rawTrack[startIndex];
    final remainderDistM = lastPt.distanceMeters - startPt.distanceMeters;

    if (remainderDistM >= minSplitDistanceThresholdM || splits.isEmpty) {
      final durationSec = math.max(
        1,
        (lastPt.timeOffsetMs - startPt.timeOffsetMs) ~/ 1000,
      );
      final distFraction = remainderDistM / unitStepM;
      final paceSec = distFraction > 0
          ? (durationSec / distFraction).round()
          : 0;
      final elevChange = hasAltitude
          ? (lastPt.altitudeMeters - startPt.altitudeMeters)
          : 0.0;
      final grade = remainderDistM > 0
          ? (elevChange / remainderDistM).clamp(-0.20, 0.20)
          : 0.0;

      splits.add(
        RunSplit(
          index: currentSplitIndex,
          distanceMeters: remainderDistM,
          displayDistance: distFraction,
          durationSeconds: durationSec,
          paceSeconds: paceSec,
          elevationChangeMeters: elevChange,
          elevationGainMeters: math.max(0.0, elevChange),
          elevationLossMeters: math.max(0.0, -elevChange),
          averageGrade: grade,
          isPartial: splits.isNotEmpty || remainderDistM < (unitStepM * 0.95),
          unit: unit,
        ),
      );
    }

    // Highlight the best split (fastest pace among full splits; or best of partials if short run)
    if (splits.isNotEmpty) {
      final fullSplits = splits.where((s) => !s.isPartial).toList();
      final candidatePool = fullSplits.isNotEmpty ? fullSplits : splits;

      int bestPace = 999999;
      int bestIndex = -1;
      for (final s in candidatePool) {
        if (s.paceSeconds > 0 && s.paceSeconds < bestPace) {
          bestPace = s.paceSeconds;
          bestIndex = s.index;
        }
      }

      for (int i = 0; i < splits.length; i++) {
        if (splits[i].index == bestIndex) {
          splits[i] = splits[i].copyWith(isBest: true);
        }
      }
    }

    return splits;
  }

  /// Downsamples the dense raw track to approximately [targetCount] equidistant distance points.
  List<ElevationPoint> _downsampleTrack(
    List<_TrackPoint> track, {
    int targetCount = targetProfilePoints,
  }) {
    if (track.isEmpty) return const [];
    if (track.length <= targetCount) {
      return track.map((p) => p.toElevationPoint()).toList();
    }

    final totalDistance = track.last.distanceMeters;
    if (totalDistance <= 0.0) {
      return [track.first.toElevationPoint()];
    }

    final result = <ElevationPoint>[];
    final step = totalDistance / (targetCount - 1);
    int currentIdx = 0;

    for (int i = 0; i < targetCount; i++) {
      if (i == targetCount - 1) {
        result.add(track.last.toElevationPoint());
        break;
      }

      final targetDist = i * step;

      while (currentIdx < track.length - 1 &&
          track[currentIdx + 1].distanceMeters < targetDist) {
        currentIdx++;
      }

      if (currentIdx >= track.length - 1) {
        result.add(track.last.toElevationPoint());
        continue;
      }

      final p0 = track[currentIdx];
      final p1 = track[currentIdx + 1];
      final segmentLength = p1.distanceMeters - p0.distanceMeters;

      if (segmentLength <= 0.001) {
        result.add(p0.toElevationPoint());
      } else {
        final t = ((targetDist - p0.distanceMeters) / segmentLength).clamp(
          0.0,
          1.0,
        );
        final interpAlt =
            p0.altitudeMeters + (p1.altitudeMeters - p0.altitudeMeters) * t;
        final interpLat = p0.lat + (p1.lat - p0.lat) * t;
        final interpLng = p0.lng + (p1.lng - p0.lng) * t;
        final interpTime =
            (p0.timeOffsetMs + (p1.timeOffsetMs - p0.timeOffsetMs) * t).round();
        final grade = ((p1.altitudeMeters - p0.altitudeMeters) / segmentLength)
            .clamp(-0.20, 0.20);

        result.add(
          ElevationPoint(
            distanceMeters: targetDist,
            altitudeMeters: interpAlt,
            lat: interpLat,
            lng: interpLng,
            timeOffsetMs: interpTime,
            grade: grade,
          ),
        );
      }
    }

    return result;
  }
}

class _TrackPoint {
  final double distanceMeters;
  final double altitudeMeters;
  final double lat;
  final double lng;
  final int timeOffsetMs;

  const _TrackPoint({
    required this.distanceMeters,
    required this.altitudeMeters,
    required this.lat,
    required this.lng,
    required this.timeOffsetMs,
  });

  ElevationPoint toElevationPoint() => ElevationPoint(
    distanceMeters: distanceMeters,
    altitudeMeters: altitudeMeters,
    lat: lat,
    lng: lng,
    timeOffsetMs: timeOffsetMs,
  );
}
