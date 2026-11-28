import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/logging/app_logger.dart';
import '../models/drone_companion.dart';
import 'countdown_audio_service.dart';

/// Service managing the AI Companion Drone ('Aero'), computing its orbiting map
/// position and dispatching personality-driven tactical audio coaching.
class DroneCompanionService extends ChangeNotifier {
  static final DroneCompanionService _instance =
      DroneCompanionService._internal();
  factory DroneCompanionService() => _instance;
  DroneCompanionService._internal();

  final DroneCompanion _drone = DroneCompanion(
    name: 'Aero',
    level: 1,
    currentXp: 0,
    personality: DronePersonality.tactical,
  );

  double _orbitalAngleRad = 0.0;
  final Distance _distanceCalc = const Distance();
  DateTime _lastVoiceCue = DateTime.fromMillisecondsSinceEpoch(0);

  DroneCompanion get drone => _drone;

  /// Computes the drone's position orbiting ~18 meters from the runner's GPS position
  LatLng computeDronePosition(LatLng runnerPos) {
    _orbitalAngleRad = (_orbitalAngleRad + 0.08) % (2 * math.pi);
    final bearingDeg = (_orbitalAngleRad * (180.0 / math.pi));
    return _distanceCalc.offset(runnerPos, 18.0, bearingDeg);
  }

  /// Adds progress XP to the drone (e.g. 50 XP per kilometer)
  void addKilometerXp(double distanceKm) {
    final xpEarned = (distanceKm * 50).round();
    if (xpEarned > 0) {
      _drone.addXp(xpEarned);
      notifyListeners();
    }
  }

  /// Delivers tactical drone voice encouragement
  Future<void> deliverDroneCue(String message) async {
    final now = DateTime.now();
    // Throttle voice prompts to minimum 20 seconds apart
    if (now.difference(_lastVoiceCue).inSeconds < 20) return;
    _lastVoiceCue = now;

    try {
      AppLogger.info(
        'Drone Aero dispatch: "$message"',
        tag: 'DroneCompanionService',
      );
      await CountdownAudioService().speakCue(message);
    } catch (e) {
      AppLogger.warning(
        'Drone voice prompt failed: $e',
        tag: 'DroneCompanionService',
      );
    }
  }

  /// Triggered when runner encounters an incline grade >= 4%
  void onInclineEncountered(double gradePct) {
    final pct = (gradePct * 100).round();
    deliverDroneCue(
      'Incline $pct percent ahead! Minetti metabolic physics engaged — pump those arms!',
    );
  }

  /// Triggered when a tactical crate is spotted
  void onCrateSpotted(String crateTitle) {
    deliverDroneCue(
      '$crateTitle detected on radar! Intercept ahead for tactical advantage!',
    );
  }

  /// Triggered on loop closure
  void onLoopClosed() {
    deliverDroneCue('Perimeter sealed! Territory beacon online!');
  }
}
