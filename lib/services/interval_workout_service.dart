import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/app_logger.dart';
import '../models/interval_workout.dart';
import 'app_preferences.dart';
import 'countdown_audio_service.dart';

/// Real-time snapshot of the active workout execution for HUD rendering.
class IntervalWorkoutSnapshot {
  final IntervalWorkoutPlan plan;
  final WorkoutPhase currentPhase;
  final int phaseIndex;
  final int totalPhases;
  final int? remainingSeconds;
  final double? remainingDistanceMeters;
  final String bannerText;
  final double progressFraction;
  final bool isCompleted;
  final bool isPaused;

  const IntervalWorkoutSnapshot({
    required this.plan,
    required this.currentPhase,
    required this.phaseIndex,
    required this.totalPhases,
    this.remainingSeconds,
    this.remainingDistanceMeters,
    required this.bannerText,
    required this.progressFraction,
    required this.isCompleted,
    required this.isPaused,
  });

  IntervalWorkoutSnapshot copyWith({
    IntervalWorkoutPlan? plan,
    WorkoutPhase? currentPhase,
    int? phaseIndex,
    int? totalPhases,
    int? remainingSeconds,
    double? remainingDistanceMeters,
    String? bannerText,
    double? progressFraction,
    bool? isCompleted,
    bool? isPaused,
  }) {
    return IntervalWorkoutSnapshot(
      plan: plan ?? this.plan,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      totalPhases: totalPhases ?? this.totalPhases,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      bannerText: bannerText ?? this.bannerText,
      progressFraction: progressFraction ?? this.progressFraction,
      isCompleted: isCompleted ?? this.isCompleted,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// Pure Dart timeline execution engine for athletic interval workouts.
///
/// - Driven by elapsed seconds delta and GPS distance, independent of UI render frames.
/// - Keeps ticking when device screen is turned off.
/// - Auto-pause halts the workout clock.
/// - Triggers purposeful tone cues and haptics on phase transitions (tones only, zero spoken voice).
/// - Records planned vs. actual duration and distance per phase.
class IntervalWorkoutTimeline {
  final IntervalWorkoutPlan plan;
  final CountdownAudioService _audioService;
  final AppPreferences _appPrefs;

  int _currentPhaseIndex = 0;
  int _currentPhaseElapsedSeconds = 0;
  double _currentPhaseStartDistanceM = 0.0;
  double _currentPhaseElapsedDistanceM = 0.0;
  bool _isPaused = false;
  bool _isCompleted = false;

  final List<WorkoutPhaseExecution> _executions = [];

  // Callbacks
  ValueChanged<IntervalWorkoutSnapshot>? onSnapshotUpdated;
  ValueChanged<WorkoutPhase>? onPhaseChanged;
  VoidCallback? onWorkoutCompleted;

  IntervalWorkoutTimeline({
    required this.plan,
    CountdownAudioService? audioService,
    AppPreferences? appPrefs,
    double initialDistanceM = 0.0,
  }) : _audioService = audioService ?? CountdownAudioService(),
       _appPrefs = appPrefs ?? AppPreferences(),
       _currentPhaseStartDistanceM = initialDistanceM {
    if (plan.phases.isEmpty) {
      _isCompleted = true;
    } else {
      _playPhaseTransitionCue(currentPhase, isInitial: true);
      _checkImmediateTarget(initialDistanceM);
    }
  }

  // Getters
  int get currentPhaseIndex => _currentPhaseIndex;
  WorkoutPhase get currentPhase => _isCompleted
      ? (plan.phases.isNotEmpty
            ? plan.phases.last
            : const WorkoutPhase(
                id: 'done',
                name: 'Completed',
                type: WorkoutPhaseType.cooldown,
              ))
      : plan.phases[_currentPhaseIndex.clamp(0, plan.phases.length - 1)];
  int get totalPhases => plan.phases.length;
  bool get isPaused => _isPaused;
  bool get isCompleted => _isCompleted;
  List<WorkoutPhaseExecution> get executions => List.unmodifiable(_executions);

  /// Pauses the workout timeline (e.g. on manual pause or auto-pause).
  void pause() {
    if (_isPaused || _isCompleted) return;
    _isPaused = true;
    _dispatchSnapshot(
      currentDistanceM:
          _currentPhaseStartDistanceM + _currentPhaseElapsedDistanceM,
    );
  }

  /// Resumes the workout timeline.
  void resume() {
    if (!_isPaused || _isCompleted) return;
    _isPaused = false;
    _dispatchSnapshot(
      currentDistanceM:
          _currentPhaseStartDistanceM + _currentPhaseElapsedDistanceM,
    );
  }

  void _checkImmediateTarget(double currentDistanceM) {
    while (!_isCompleted && plan.phases.isNotEmpty) {
      final phase = currentPhase;
      bool targetMet = false;
      if (phase.targetType == WorkoutTargetType.time) {
        final target = phase.targetSeconds ?? 0;
        if (target <= 0) targetMet = true;
      } else {
        final targetDist = phase.targetDistanceM ?? 0.0;
        if (targetDist <= 0) targetMet = true;
      }

      if (targetMet) {
        _completeCurrentPhase(
          wasSkipped: false,
          currentDistanceM: currentDistanceM,
        );
      } else {
        break;
      }
    }
  }

  /// Ticks the workout timeline forward by [secondsDelta] with [currentRunDistanceMeters].
  void tick({
    required int secondsDelta,
    required double currentRunDistanceMeters,
  }) {
    if (_isPaused || _isCompleted || plan.phases.isEmpty) return;

    _currentPhaseElapsedSeconds += secondsDelta;
    _currentPhaseElapsedDistanceM =
        (currentRunDistanceMeters - _currentPhaseStartDistanceM).clamp(
          0.0,
          double.infinity,
        );

    while (!_isCompleted) {
      final phase = currentPhase;
      bool isPhaseTargetMet = false;

      if (phase.targetType == WorkoutTargetType.time) {
        final target = phase.targetSeconds ?? 0;
        if (target <= 0 || _currentPhaseElapsedSeconds >= target) {
          isPhaseTargetMet = true;
        }
      } else {
        final targetDist = phase.targetDistanceM ?? 0.0;
        if (targetDist <= 0 || _currentPhaseElapsedDistanceM >= targetDist) {
          isPhaseTargetMet = true;
        }
      }

      if (isPhaseTargetMet) {
        _completeCurrentPhase(
          wasSkipped: false,
          currentDistanceM: currentRunDistanceMeters,
        );
      } else {
        break;
      }
    }

    _dispatchSnapshot(currentDistanceM: currentRunDistanceMeters);
  }

  /// Manually skips the current workout phase and transitions to the next phase immediately.
  void skipPhase({required double currentRunDistanceMeters}) {
    if (_isCompleted || plan.phases.isEmpty) return;
    _completeCurrentPhase(
      wasSkipped: true,
      currentDistanceM: currentRunDistanceMeters,
    );
    _dispatchSnapshot(currentDistanceM: currentRunDistanceMeters);
  }

  void _completeCurrentPhase({
    required bool wasSkipped,
    required double currentDistanceM,
  }) {
    final finishedPhase = currentPhase;
    _executions.add(
      WorkoutPhaseExecution(
        phase: finishedPhase,
        actualDurationSeconds: _currentPhaseElapsedSeconds,
        actualDistanceM: _currentPhaseElapsedDistanceM,
        isCompleted: !wasSkipped,
        isSkipped: wasSkipped,
      ),
    );

    if (_currentPhaseIndex + 1 < plan.phases.length) {
      _currentPhaseIndex++;
      _currentPhaseElapsedSeconds = 0;
      _currentPhaseStartDistanceM = currentDistanceM;
      _currentPhaseElapsedDistanceM = 0.0;

      final nextPhase = currentPhase;
      _playPhaseTransitionCue(nextPhase);
      onPhaseChanged?.call(nextPhase);
    } else {
      _isCompleted = true;
      _playPhaseTransitionCue(finishedPhase, isWorkoutEnding: true);
      onWorkoutCompleted?.call();
    }
  }

  void _playPhaseTransitionCue(
    WorkoutPhase phase, {
    bool isInitial = false,
    bool isWorkoutEnding = false,
  }) {
    // 1. Audio tone cue (tones only, zero spoken voice)
    if (_appPrefs.isSoundEffectsEnabled) {
      if (isWorkoutEnding) {
        _audioService.playIntervalRest();
      } else if (phase.type == WorkoutPhaseType.run) {
        _audioService.playIntervalWork();
      } else {
        _audioService.playIntervalRest();
      }
    }

    // 2. Tactile haptic feedback
    if (_appPrefs.isHapticsEnabled) {
      if (phase.type == WorkoutPhaseType.run) {
        _appPrefs.triggerIntervalRunHaptic();
      } else {
        _appPrefs.triggerIntervalWalkHaptic();
      }
    }

    // 3. Screen reader accessibility announcement
    try {
      final announcement = isWorkoutEnding
          ? 'Workout completed. Great effort!'
          : '${phase.type.displayName}. ${phase.formattedTarget}.';
      // ignore: deprecated_member_use
      SemanticsService.announce(announcement, TextDirection.ltr);
    } catch (_) {}
  }

  void _dispatchSnapshot({required double currentDistanceM}) {
    final snapshot = getSnapshot(currentDistanceM: currentDistanceM);
    onSnapshotUpdated?.call(snapshot);
  }

  /// Builds a current immutable snapshot of the workout progress.
  IntervalWorkoutSnapshot getSnapshot({required double currentDistanceM}) {
    if (plan.phases.isEmpty) {
      return IntervalWorkoutSnapshot(
        plan: plan,
        currentPhase: const WorkoutPhase(
          id: 'done',
          name: 'Completed',
          type: WorkoutPhaseType.cooldown,
        ),
        phaseIndex: 0,
        totalPhases: 0,
        remainingSeconds: 0,
        remainingDistanceMeters: 0.0,
        bannerText: 'WORKOUT COMPLETED',
        progressFraction: 1.0,
        isCompleted: true,
        isPaused: _isPaused,
      );
    }

    if (_isCompleted) {
      return IntervalWorkoutSnapshot(
        plan: plan,
        currentPhase: plan.phases.last,
        phaseIndex: plan.phases.length - 1,
        totalPhases: plan.phases.length,
        remainingSeconds: 0,
        remainingDistanceMeters: 0.0,
        bannerText: 'WORKOUT COMPLETED',
        progressFraction: 1.0,
        isCompleted: true,
        isPaused: _isPaused,
      );
    }

    final phase = currentPhase;
    int? remainingSec;
    double? remainingDistM;
    double progress = 0.0;
    String banner;

    if (phase.targetType == WorkoutTargetType.time) {
      final target = phase.targetSeconds ?? 1;
      final rem = (target - _currentPhaseElapsedSeconds).clamp(0, target);
      remainingSec = rem;
      progress = (_currentPhaseElapsedSeconds / (target > 0 ? target : 1))
          .clamp(0.0, 1.0);
      final m = rem ~/ 60;
      final s = rem % 60;
      final timeStr = '$m:${s.toString().padLeft(2, '0')}';
      banner = '${phase.type.displayName} $timeStr';
    } else {
      final target = phase.targetDistanceM ?? 100.0;
      final rem = (target - _currentPhaseElapsedDistanceM).clamp(0.0, target);
      remainingDistM = rem;
      progress = (_currentPhaseElapsedDistanceM / (target > 0 ? target : 1))
          .clamp(0.0, 1.0);
      final distStr = rem >= 1000.0
          ? '${(rem / 1000.0).toStringAsFixed(1)} km'
          : '${rem.round()}m';
      banner = '${phase.type.displayName} $distStr';
    }

    return IntervalWorkoutSnapshot(
      plan: plan,
      currentPhase: phase,
      phaseIndex: _currentPhaseIndex,
      totalPhases: plan.phases.length,
      remainingSeconds: remainingSec,
      remainingDistanceMeters: remainingDistM,
      bannerText: banner,
      progressFraction: progress,
      isCompleted: false,
      isPaused: _isPaused,
    );
  }
}

/// Offline-first service managing saved and custom interval workout routines.
class IntervalWorkoutService {
  static const String _prefCustomWorkoutKey = 'pref_custom_interval_workout_v1';
  static final IntervalWorkoutService _instance =
      IntervalWorkoutService._internal();

  factory IntervalWorkoutService() => _instance;

  IntervalWorkoutService._internal();

  /// Returns available presets and any locally saved custom routine.
  Future<List<IntervalWorkoutPlan>> getAvailablePlans() async {
    final plans = <IntervalWorkoutPlan>[
      IntervalWorkoutPlan.beginnerRunWalk,
      IntervalWorkoutPlan.fiveByTwoFastOneEasy,
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCustomWorkoutKey);
      if (raw != null && raw.isNotEmpty) {
        plans.add(
          IntervalWorkoutPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Custom workout read error: $e',
        tag: 'IntervalWorkout',
      );
    }

    return plans;
  }

  /// Persists a custom interval workout plan locally.
  Future<void> saveCustomPlan(IntervalWorkoutPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCustomWorkoutKey, jsonEncode(plan.toJson()));
    } catch (e) {
      AppLogger.warning(
        'Custom workout save error: $e',
        tag: 'IntervalWorkout',
      );
    }
  }
}
