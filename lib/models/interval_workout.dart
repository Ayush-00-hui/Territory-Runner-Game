import 'package:flutter/material.dart';

import '../ui/theme/app_colors.dart';

/// Category of an athletic interval workout phase.
enum WorkoutPhaseType { warmup, run, walk, cooldown }

extension WorkoutPhaseTypeExtension on WorkoutPhaseType {
  String get displayName {
    switch (this) {
      case WorkoutPhaseType.warmup:
        return 'WARM UP';
      case WorkoutPhaseType.run:
        return 'RUN';
      case WorkoutPhaseType.walk:
        return 'WALK';
      case WorkoutPhaseType.cooldown:
        return 'COOL DOWN';
    }
  }

  Color get color {
    switch (this) {
      case WorkoutPhaseType.warmup:
        return AppColors.warning;
      case WorkoutPhaseType.run:
        return AppColors.accent;
      case WorkoutPhaseType.walk:
        return AppColors.info;
      case WorkoutPhaseType.cooldown:
        return AppColors.textSecondary;
    }
  }
}

/// Target measurement type for a workout phase.
enum WorkoutTargetType { time, distance }

/// A single step/interval within an athletic workout.
class WorkoutPhase {
  final String id;
  final String name;
  final WorkoutPhaseType type;
  final WorkoutTargetType targetType;
  final int? targetSeconds;
  final double? targetDistanceM;

  const WorkoutPhase({
    required this.id,
    required this.name,
    required this.type,
    this.targetType = WorkoutTargetType.time,
    this.targetSeconds,
    this.targetDistanceM,
  });

  /// Formatted target description (e.g. "1:00", "200m", "1.0 km").
  String get formattedTarget {
    if (targetType == WorkoutTargetType.time) {
      final sec = targetSeconds ?? 0;
      final m = sec ~/ 60;
      final s = sec % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    } else {
      final dist = targetDistanceM ?? 0.0;
      if (dist >= 1000.0) {
        return '${(dist / 1000.0).toStringAsFixed(1)} km';
      }
      return '${dist.round()}m';
    }
  }

  /// Banner headline (e.g. "RUN 1:00", "WALK 2:00").
  String get bannerHeadline => '${type.displayName} $formattedTarget';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'targetType': targetType.name,
    if (targetSeconds != null) 'targetSeconds': targetSeconds,
    if (targetDistanceM != null) 'targetDistanceM': targetDistanceM,
  };

  factory WorkoutPhase.fromJson(Map<String, dynamic> json) => WorkoutPhase(
    id: json['id'] as String,
    name: json['name'] as String,
    type: WorkoutPhaseType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => WorkoutPhaseType.run,
    ),
    targetType: WorkoutTargetType.values.firstWhere(
      (e) => e.name == json['targetType'],
      orElse: () => WorkoutTargetType.time,
    ),
    targetSeconds: (json['targetSeconds'] as num?)?.toInt(),
    targetDistanceM: (json['targetDistanceM'] as num?)?.toDouble(),
  );
}

/// Recorded outcome of an executed workout phase.
class WorkoutPhaseExecution {
  final WorkoutPhase phase;
  final int actualDurationSeconds;
  final double actualDistanceM;
  final bool isCompleted;
  final bool isSkipped;

  const WorkoutPhaseExecution({
    required this.phase,
    required this.actualDurationSeconds,
    required this.actualDistanceM,
    this.isCompleted = false,
    this.isSkipped = false,
  });

  /// Formatted actual duration (e.g. "1:02", "0:45").
  String get formattedActualDuration {
    final m = actualDurationSeconds ~/ 60;
    final s = actualDurationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'phase': phase.toJson(),
    'actualDurationSeconds': actualDurationSeconds,
    'actualDistanceM': actualDistanceM,
    'isCompleted': isCompleted,
    'isSkipped': isSkipped,
  };

  factory WorkoutPhaseExecution.fromJson(Map<String, dynamic> json) =>
      WorkoutPhaseExecution(
        phase: WorkoutPhase.fromJson(json['phase'] as Map<String, dynamic>),
        actualDurationSeconds: (json['actualDurationSeconds'] as num).toInt(),
        actualDistanceM: (json['actualDistanceM'] as num).toDouble(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        isSkipped: json['isSkipped'] as bool? ?? false,
      );
}

/// A structured interval workout routine.
class IntervalWorkoutPlan {
  final String id;
  final String name;
  final String description;
  final List<WorkoutPhase> phases;

  const IntervalWorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.phases,
  });

  int get totalPlannedDurationSeconds {
    int total = 0;
    for (final p in phases) {
      if (p.targetType == WorkoutTargetType.time) {
        total += p.targetSeconds ?? 0;
      }
    }
    return total;
  }

  double get totalPlannedDistanceMeters {
    double total = 0.0;
    for (final p in phases) {
      if (p.targetType == WorkoutTargetType.distance) {
        total += p.targetDistanceM ?? 0.0;
      }
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Standard Athletic Presets
  // ---------------------------------------------------------------------------

  /// Beginner Run-Walk: 8x (1 min Run / 2 min Walk) with warm-up & cool-down.
  static IntervalWorkoutPlan get beginnerRunWalk {
    final phases = <WorkoutPhase>[
      const WorkoutPhase(
        id: 'warmup',
        name: 'Warm up',
        type: WorkoutPhaseType.warmup,
        targetSeconds: 180, // 3 min
      ),
    ];

    for (int i = 1; i <= 8; i++) {
      phases.add(
        WorkoutPhase(
          id: 'run_$i',
          name: 'Run $i/8',
          type: WorkoutPhaseType.run,
          targetSeconds: 60, // 1 min
        ),
      );
      phases.add(
        WorkoutPhase(
          id: 'walk_$i',
          name: 'Walk $i/8',
          type: WorkoutPhaseType.walk,
          targetSeconds: 120, // 2 min
        ),
      );
    }

    phases.add(
      const WorkoutPhase(
        id: 'cooldown',
        name: 'Cool down',
        type: WorkoutPhaseType.cooldown,
        targetSeconds: 120, // 2 min
      ),
    );

    return IntervalWorkoutPlan(
      id: 'preset_beginner_run_walk',
      name: 'Beginner run-walk',
      description: '8 repeats of 1 min run / 2 min walk',
      phases: phases,
    );
  }

  /// 5 x (2 min fast + 1 min easy) with warm-up & cool-down.
  static IntervalWorkoutPlan get fiveByTwoFastOneEasy {
    final phases = <WorkoutPhase>[
      const WorkoutPhase(
        id: 'warmup',
        name: 'Warm up',
        type: WorkoutPhaseType.warmup,
        targetSeconds: 300, // 5 min
      ),
    ];

    for (int i = 1; i <= 5; i++) {
      phases.add(
        WorkoutPhase(
          id: 'fast_$i',
          name: 'Fast $i/5',
          type: WorkoutPhaseType.run,
          targetSeconds: 120, // 2 min
        ),
      );
      phases.add(
        WorkoutPhase(
          id: 'easy_$i',
          name: 'Easy $i/5',
          type: WorkoutPhaseType.walk,
          targetSeconds: 60, // 1 min
        ),
      );
    }

    phases.add(
      const WorkoutPhase(
        id: 'cooldown',
        name: 'Cool down',
        type: WorkoutPhaseType.cooldown,
        targetSeconds: 180, // 3 min
      ),
    );

    return IntervalWorkoutPlan(
      id: 'preset_5x_2min_fast',
      name: '5x (2 min fast + 1 min easy)',
      description: '5 high-intensity repeats with active recovery',
      phases: phases,
    );
  }

  /// Creates a custom interval workout plan with variable repeats and durations.
  static IntervalWorkoutPlan custom({
    required int warmupSeconds,
    required int repeats,
    required int runSeconds,
    required int walkSeconds,
    required int cooldownSeconds,
    String name = 'Custom intervals',
  }) {
    final phases = <WorkoutPhase>[];
    if (warmupSeconds > 0) {
      phases.add(
        WorkoutPhase(
          id: 'warmup',
          name: 'Warm up',
          type: WorkoutPhaseType.warmup,
          targetSeconds: warmupSeconds,
        ),
      );
    }

    for (int i = 1; i <= repeats; i++) {
      if (runSeconds > 0) {
        phases.add(
          WorkoutPhase(
            id: 'run_$i',
            name: 'Run $i/$repeats',
            type: WorkoutPhaseType.run,
            targetSeconds: runSeconds,
          ),
        );
      }
      if (walkSeconds > 0) {
        phases.add(
          WorkoutPhase(
            id: 'walk_$i',
            name: 'Walk $i/$repeats',
            type: WorkoutPhaseType.walk,
            targetSeconds: walkSeconds,
          ),
        );
      }
    }

    if (cooldownSeconds > 0) {
      phases.add(
        WorkoutPhase(
          id: 'cooldown',
          name: 'Cool down',
          type: WorkoutPhaseType.cooldown,
          targetSeconds: cooldownSeconds,
        ),
      );
    }

    return IntervalWorkoutPlan(
      id: 'custom_workout',
      name: name,
      description: '$repeats repeats ($runSeconds s run / $walkSeconds s walk)',
      phases: phases,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'phases': phases.map((p) => p.toJson()).toList(),
  };

  factory IntervalWorkoutPlan.fromJson(Map<String, dynamic> json) =>
      IntervalWorkoutPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        phases: (json['phases'] as List<dynamic>)
            .map((p) => WorkoutPhase.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
