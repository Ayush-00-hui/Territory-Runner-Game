import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/logging/app_logger.dart';
import '../../models/sector_guardian.dart';

/// Service managing Asynchronous Sector Guardian Ghost Boss challenges.
class GuardianChallengeService extends ChangeNotifier {
  static final GuardianChallengeService _instance =
      GuardianChallengeService._internal();
  factory GuardianChallengeService() => _instance;
  GuardianChallengeService._internal();

  SectorGuardian? _activeGuardian;
  double _userLeadDistanceMeters = 0.0;
  bool _isChallengeActive = false;
  final Distance _distanceCalc = const Distance();

  SectorGuardian? get activeGuardian => _activeGuardian;
  bool get isChallengeActive => _isChallengeActive;
  double get userLeadDistanceMeters => _userLeadDistanceMeters;
  bool get isUserLeading => _userLeadDistanceMeters >= 0.0;

  /// Default mock guardian for local sector
  SectorGuardian defaultSectorGuardian(LatLng startPos) {
    // Generate an illustrative 2.5km loop route starting near athlete
    final points = <LatLng>[startPos];
    final bearings = [0.0, 90.0, 180.0, 270.0];
    LatLng cur = startPos;
    for (final b in bearings) {
      cur = _distanceCalc.offset(cur, 600.0, b);
      points.add(cur);
    }
    points.add(startPos); // Close loop

    return SectorGuardian(
      sectorId: 'sector_central_01',
      districtName: 'Metro Central Loop',
      guardianName: 'Vanguard_Phantom',
      faction: 'Apex Vanguard',
      recordTimeSeconds: 680.0, // ~11:20 for 2.4km (~4:43/km)
      distanceKm: 2.4,
      averagePaceMinPerKm: 4.72,
      routePoints: points,
    );
  }

  void startChallenge(SectorGuardian guardian) {
    _activeGuardian = guardian;
    _isChallengeActive = true;
    _userLeadDistanceMeters = 0.0;
    AppLogger.info(
      'Started challenge against Sector Guardian: ${guardian.guardianName} (${guardian.districtName})',
      tag: 'GuardianChallengeService',
    );
    notifyListeners();
  }

  void cancelChallenge() {
    _activeGuardian = null;
    _isChallengeActive = false;
    _userLeadDistanceMeters = 0.0;
    notifyListeners();
  }

  /// Updates comparison against the ghost guardian given athlete's elapsed distance and current position
  void updateAthleteProgress(double athleteDistanceMeters, LatLng athletePos) {
    if (!_isChallengeActive || _activeGuardian == null) return;

    // Projected ghost position along guardian route based on pace
    // If athlete has covered 800m, compare with guardian expected distance
    final expectedGhostDist =
        athleteDistanceMeters * 0.98; // Simulated competitive pacing
    _userLeadDistanceMeters = athleteDistanceMeters - expectedGhostDist;
    notifyListeners();
  }
}
