import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../models/sprint_incursion.dart';
import '../../services/arcade_audio_service.dart';

/// Service managing dynamic in-run sprint incursions (Gamified HIIT).
class IncursionService extends ChangeNotifier {
  static final IncursionService _instance = IncursionService._internal();
  factory IncursionService() => _instance;
  IncursionService._internal();

  SprintIncursion? _currentIncursion;
  Timer? _countdownTimer;
  double _currentSpeedMps = 0.0;
  int _repelledIncursionsCount = 0;
  int _totalEarnedXp = 0;

  SprintIncursion? get currentIncursion => _currentIncursion;
  bool get hasActiveIncursion =>
      _currentIncursion != null && _currentIncursion!.isActive;
  int get repelledIncursionsCount => _repelledIncursionsCount;
  int get totalEarnedXp => _totalEarnedXp;

  final StreamController<SprintIncursion> _incursionStateStream =
      StreamController<SprintIncursion>.broadcast();
  Stream<SprintIncursion> get onIncursionStateChanged =>
      _incursionStateStream.stream;

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _currentIncursion = null;
    _currentSpeedMps = 0.0;
    _repelledIncursionsCount = 0;
    _totalEarnedXp = 0;
    notifyListeners();
  }

  /// Triggers a dynamic incursion sprint challenge
  void triggerIncursion({
    String? rivalFaction,
    double? customTargetSpeedMps,
    int durationSeconds = 60,
  }) {
    if (hasActiveIncursion) return;

    final factions = ['Obsidian', 'Apex', 'Terra Wardens'];
    final faction =
        rivalFaction ?? factions[math.Random().nextInt(factions.length)];
    // Default target: ~4:45/km (3.51 m/s) or adaptive
    final targetSpeed = customTargetSpeedMps ?? 3.5;

    _currentIncursion = SprintIncursion(
      id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
      rivalFactionName: faction,
      targetSpeedMps: targetSpeed,
      totalDurationSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
      rewardXp: 150,
    );

    ArcadeAudioService().playIncursionAlarm();
    AppLogger.info(
      'Sprint Incursion TRIGGERED! Repel $faction for ${durationSeconds}s at $targetSpeed m/s',
      tag: 'IncursionService',
    );

    _startIncursionTimer();
    _incursionStateStream.add(_currentIncursion!);
    notifyListeners();
  }

  void _startIncursionTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentIncursion == null || !_currentIncursion!.isActive) {
        timer.cancel();
        return;
      }

      if (_currentIncursion!.remainingSeconds > 0) {
        _currentIncursion!.remainingSeconds--;
        notifyListeners();
      } else {
        // Time completed! Check if repelled
        timer.cancel();
        _evaluateIncursionOutcome();
      }
    });
  }

  /// Updates runner's current telemetry speed
  void updateRunnerSpeed(double speedMps) {
    _currentSpeedMps = speedMps;
    notifyListeners();
  }

  void _evaluateIncursionOutcome() {
    if (_currentIncursion == null) return;

    // Successful if runner stayed strong near target speed (within 10%)
    if (_currentSpeedMps >= (_currentIncursion!.targetSpeedMps * 0.90)) {
      _currentIncursion!.status = IncursionStatus.repelled;
      _repelledIncursionsCount++;
      _totalEarnedXp += _currentIncursion!.rewardXp;
      ArcadeAudioService().playLoopVictoryChime();
      AppLogger.info(
        'Incursion REPELLED successfully! +${_currentIncursion!.rewardXp} XP',
        tag: 'IncursionService',
      );
    } else {
      _currentIncursion!.status = IncursionStatus.failed;
      AppLogger.info(
        'Incursion FAILED: pace fell below target speed threshold.',
        tag: 'IncursionService',
      );
    }

    _incursionStateStream.add(_currentIncursion!);
    notifyListeners();

    // Auto-dismiss resolved incursion banner after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (_currentIncursion != null && !_currentIncursion!.isActive) {
        _currentIncursion = null;
        notifyListeners();
      }
    });
  }
}
