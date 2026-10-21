import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// GNSS Signal Quality classification for tactical HUD telemetry.
enum GpsQuality {
  optimal, // <= 10m accuracy (sub-meter or high precision)
  fair, // 10m - 30m accuracy (acceptable running GPS)
  degraded, // > 30m accuracy (dilution of precision / multipath)
  lost, // Signal timeout > 15s (tunnel, indoor, subway)
}

/// Helper service for GPS quality categorization, signal gap handling, and stationary auto-pause.
class GpsQualityService {
  static const double optimalThresholdMeters = 10.0;
  static const double maxAcceptableAccuracyMeters = 30.0;
  static const Duration gapTimeout = Duration(seconds: 15);
  static const double stationarySpeedCeilingKmh = 1.5;

  /// Evaluates GNSS signal health based on horizontal dilution and time since last fix.
  static GpsQuality evaluateQuality({
    required double accuracyMeters,
    required DateTime lastFixTimestamp,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastFixTimestamp);

    if (elapsed > gapTimeout) {
      return GpsQuality.lost;
    }

    if (accuracyMeters <= optimalThresholdMeters) {
      return GpsQuality.optimal;
    } else if (accuracyMeters <= maxAcceptableAccuracyMeters) {
      return GpsQuality.fair;
    } else {
      return GpsQuality.degraded;
    }
  }

  /// Returns true if a signal gap exceeded the timeout (e.g. runner went through an urban tunnel).
  static bool isSignalGap(
    DateTime previousFix,
    DateTime newFix, {
    Duration threshold = gapTimeout,
  }) {
    return newFix.difference(previousFix) > threshold;
  }

  /// Determines whether a fix pair represents an unrealistic teleportation jump across a gap.
  static bool isUnrealisticJump(
    LatLng start,
    LatLng end,
    double timeDeltaSeconds, {
    double maxSpeedKmh = 35.0,
  }) {
    if (timeDeltaSeconds <= 0) return true;
    final distMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final speedKmh = (distMeters / timeDeltaSeconds) * 3.6;
    return speedKmh > maxSpeedKmh;
  }

  /// Returns true if runner velocity falls below stationary jogging threshold.
  static bool isStationary(double speedKmh) {
    return speedKmh < stationarySpeedCeilingKmh;
  }
}
