import 'dart:math' as math;
import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'gps_quality_service.dart';

/// Result of GPS filtering containing smoothed coordinates and distance delta.
class GpsFilterResult {
  final LatLng filteredLatLng;
  final double distanceDeltaMeters;
  final bool isStationary;
  final double smoothedSpeedKmh;

  const GpsFilterResult({
    required this.filteredLatLng,
    required this.distanceDeltaMeters,
    required this.isStationary,
    required this.smoothedSpeedKmh,
  });
}

/// 2D Kalman filter and speed-gated dead-reckoning distance pipeline.
///
/// Eliminates stationary GPS wander (+728m baseline phantom drift) via
/// Zero-Velocity Updates (ZUPT) and dampens lateral GPS noise on running tracks.
class GpsDistanceFilter {
  static const double minLocomotionSpeedKmh = 1.2; // ~0.33 m/s
  static const double maxPlausibleAccelerationMps2 = 3.5;
  static const double earthRadius = 6378137.0; // WGS84

  // Anchor for local Cartesian conversion (tangent plane)
  double? _anchorLat;
  double? _anchorLng;
  double? _cosAnchorLat;

  // 4D Kalman state: [x, y, vx, vy] in local Cartesian meters and m/s
  double _x = 0.0;
  double _y = 0.0;
  double _vx = 0.0;
  double _vy = 0.0;

  // Covariance matrix diagonal elements
  double _pPos = 25.0; // position error variance
  double _pVel = 4.0; // velocity error variance

  DateTime? _lastTimestamp;
  LatLng? _lastFilteredLatLng;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  LatLng? get lastFilteredLatLng => _lastFilteredLatLng;

  /// Resets all internal Kalman matrices and anchors.
  void reset() {
    _anchorLat = null;
    _anchorLng = null;
    _cosAnchorLat = null;
    _x = 0.0;
    _y = 0.0;
    _vx = 0.0;
    _vy = 0.0;
    _pPos = 25.0;
    _pVel = 4.0;
    _lastTimestamp = null;
    _lastFilteredLatLng = null;
    _isInitialized = false;
  }

  /// Converts lat/lng into local Cartesian meters relative to anchor.
  Offset _toCartesian(double lat, double lng) {
    final dLat = (lat - _anchorLat!) * (math.pi / 180.0);
    final dLng = (lng - _anchorLng!) * (math.pi / 180.0);
    final y = dLat * earthRadius;
    final x = dLng * earthRadius * _cosAnchorLat!;
    return Offset(x, y);
  }

  /// Converts local Cartesian meters back to WGS84 LatLng.
  LatLng _toLatLng(double x, double y) {
    final dLat = y / earthRadius;
    final dLng = x / (earthRadius * _cosAnchorLat!);
    final lat = _anchorLat! + (dLat * (180.0 / math.pi));
    final lng = _anchorLng! + (dLng * (180.0 / math.pi));
    return LatLng(lat, lng);
  }

  /// Ingests a new GPS fix and returns a smoothed [GpsFilterResult].
  GpsFilterResult processFix(
    Position pos, {
    required bool isAutoPaused,
    required double smoothedSpeedKmh,
  }) {
    final now = pos.timestamp;
    final rawLatLng = LatLng(pos.latitude, pos.longitude);

    if (!_isInitialized) {
      _anchorLat = pos.latitude;
      _anchorLng = pos.longitude;
      _cosAnchorLat = math.cos(pos.latitude * (math.pi / 180.0));
      _x = 0.0;
      _y = 0.0;
      _vx = 0.0;
      _vy = 0.0;
      _lastTimestamp = now;
      _lastFilteredLatLng = rawLatLng;
      _isInitialized = true;
      return GpsFilterResult(
        filteredLatLng: rawLatLng,
        distanceDeltaMeters: 0.0,
        isStationary: true,
        smoothedSpeedKmh: 0.0,
      );
    }

    // Calculate time delta in seconds
    double dt = now.difference(_lastTimestamp!).inMilliseconds / 1000.0;
    _lastTimestamp = now;
    if (dt <= 0.01) dt = 0.01;
    if (dt > 10.0) dt = 10.0;

    // 1. Zero-Velocity Update (ZUPT) & Stationary Gating
    final bool isLowSpeed =
        smoothedSpeedKmh < minLocomotionSpeedKmh && pos.speed <= 0.4;
    final bool isStationary =
        isAutoPaused ||
        isLowSpeed ||
        GpsQualityService.isStationary(smoothedSpeedKmh);

    if (isStationary) {
      // Runner is stationary: zero out velocity and hold filtered position steady
      _vx = 0.0;
      _vy = 0.0;
      return GpsFilterResult(
        filteredLatLng: _lastFilteredLatLng ?? rawLatLng,
        distanceDeltaMeters: 0.0,
        isStationary: true,
        smoothedSpeedKmh: 0.0,
      );
    }

    // 2. Local Cartesian Measurement
    final meas = _toCartesian(pos.latitude, pos.longitude);

    // 3. 2D Constant Velocity Kalman Filter
    // Predict step:
    _x += _vx * dt;
    _y += _vy * dt;

    // Process noise Q
    const qRate = maxPlausibleAccelerationMps2;
    _pPos += _pVel * dt * dt + 0.25 * qRate * dt * dt * dt * dt;
    _pVel += qRate * dt * dt;

    // Measurement noise R (scaled by horizontal satellite accuracy)
    final r = math.max(4.0, pos.accuracy * pos.accuracy);

    // Kalman gain K
    final kPos = _pPos / (_pPos + r);
    final kVel = (_pPos / (_pPos + r)) / dt;

    // Innovation residual
    final resX = meas.dx - _x;
    final resY = meas.dy - _y;

    // Update step:
    _x += kPos * resX;
    _y += kPos * resY;
    _vx += kVel * resX * 0.5; // dampen velocity overshoots
    _vy += kVel * resY * 0.5;

    _pPos *= (1.0 - kPos);
    _pVel *= (1.0 - kPos);

    final filteredLatLng = _toLatLng(_x, _y);

    // 4. Calculate incremental displacement
    double deltaMeters = 0.0;
    if (_lastFilteredLatLng != null) {
      deltaMeters = Geolocator.distanceBetween(
        _lastFilteredLatLng!.latitude,
        _lastFilteredLatLng!.longitude,
        filteredLatLng.latitude,
        filteredLatLng.longitude,
      );
    }

    // Minimum movement threshold: only accumulate if movement >= 1.0m
    if (deltaMeters >= 1.0) {
      _lastFilteredLatLng = filteredLatLng;
    } else {
      deltaMeters = 0.0;
    }

    final computedSpeedKmh = math.sqrt(_vx * _vx + _vy * _vy) * 3.6;

    return GpsFilterResult(
      filteredLatLng: filteredLatLng,
      distanceDeltaMeters: deltaMeters,
      isStationary: false,
      smoothedSpeedKmh: computedSpeedKmh,
    );
  }
}
