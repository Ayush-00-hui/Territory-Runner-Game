import 'interval_workout.dart';

/// Represents a structured workout day in a multi-week training plan.
class PlanWorkoutDay {
  final String id;
  final int weekNumber; // 1-indexed (e.g. Week 1..8)
  final int dayNumber; // 1-indexed within week (e.g. Day 1..7)
  final String title;
  final String description;
  final bool isRestDay;
  final IntervalWorkoutPlan? intervalPlan;
  final double? targetDistanceKm;

  const PlanWorkoutDay({
    required this.id,
    required this.weekNumber,
    required this.dayNumber,
    required this.title,
    required this.description,
    this.isRestDay = false,
    this.intervalPlan,
    this.targetDistanceKm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekNumber': weekNumber,
    'dayNumber': dayNumber,
    'title': title,
    'description': description,
    'isRestDay': isRestDay,
    'targetDistanceKm': targetDistanceKm,
  };

  factory PlanWorkoutDay.fromJson(Map<String, dynamic> json) => PlanWorkoutDay(
    id: json['id'] as String,
    weekNumber: json['weekNumber'] as int,
    dayNumber: json['dayNumber'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    isRestDay: json['isRestDay'] as bool? ?? false,
    targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble(),
  );
}

/// Represents an authentic multi-week training curriculum (e.g. Couch to 5K, 4-Week Pace Builder).
class TrainingPlan {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final int durationWeeks;
  final String targetAudience;
  final List<PlanWorkoutDay> schedule;

  const TrainingPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.durationWeeks,
    required this.targetAudience,
    required this.schedule,
  });

  int get totalWorkouts => schedule.where((d) => !d.isRestDay).length;

  /// Built-in Plan 1: Beginner 8-Week Couch to 5 km Plan
  static TrainingPlan get couchTo5k {
    final schedule = <PlanWorkoutDay>[];

    // Week 1: 1m run / 2m walk x 6
    for (int d = 1; d <= 7; d++) {
      if (d == 1 || d == 3 || d == 5) {
        schedule.add(
          PlanWorkoutDay(
            id: 'c25k_w1_d$d',
            weekNumber: 1,
            dayNumber: d,
            title: 'Run / Walk Foundation',
            description: '6 intervals: 1 min easy run, 2 min recovery walk',
            intervalPlan: IntervalWorkoutPlan.beginnerRunWalk,
            targetDistanceKm: 2.2,
          ),
        );
      } else {
        schedule.add(
          PlanWorkoutDay(
            id: 'c25k_w1_d$d',
            weekNumber: 1,
            dayNumber: d,
            title: 'Rest & Recovery',
            description:
                'Gentle walk or complete rest to allow tissue recovery.',
            isRestDay: true,
          ),
        );
      }
    }

    // Week 2: 1.5m run / 2m walk x 5
    for (int d = 1; d <= 7; d++) {
      if (d == 1 || d == 3 || d == 5) {
        schedule.add(
          PlanWorkoutDay(
            id: 'c25k_w2_d$d',
            weekNumber: 2,
            dayNumber: d,
            title: 'Building Aerobic Base',
            description: '5 intervals: 90s jog, 2 min walk',
            intervalPlan: IntervalWorkoutPlan.beginnerRunWalk,
            targetDistanceKm: 2.5,
          ),
        );
      } else {
        schedule.add(
          PlanWorkoutDay(
            id: 'c25k_w2_d$d',
            weekNumber: 2,
            dayNumber: d,
            title: 'Rest & Recovery',
            description: 'Rest or light stretching.',
            isRestDay: true,
          ),
        );
      }
    }

    // Weeks 3 to 8 progressive build up to continuous 5 km
    for (int w = 3; w <= 8; w++) {
      for (int d = 1; d <= 7; d++) {
        if (d == 1 || d == 3 || d == 5) {
          final targetDist = 2.5 + ((w - 2) * 0.5);
          schedule.add(
            PlanWorkoutDay(
              id: 'c25k_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: w == 8 && d == 5
                  ? '5K Graduation Run'
                  : 'Week $w Endurance Build',
              description: w == 8 && d == 5
                  ? 'Your culminating 5 km continuous effort at a calm conversation pace.'
                  : 'Progressive aerobic volume: run intervals with minimal walk recovery.',
              intervalPlan: w < 6
                  ? IntervalWorkoutPlan.beginnerRunWalk
                  : IntervalWorkoutPlan.fiveByTwoFastOneEasy,
              targetDistanceKm: targetDist,
            ),
          );
        } else {
          schedule.add(
            PlanWorkoutDay(
              id: 'c25k_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: 'Rest & Recovery',
              description: 'Tissue recovery and muscular adaptation.',
              isRestDay: true,
            ),
          );
        }
      }
    }

    return TrainingPlan(
      id: 'plan_couch_to_5k',
      title: 'Run/Walk to 5K',
      subtitle: '8 Weeks • 3 sessions/week',
      description: 'A gentle, zero-shame progression from alternating walking and running up to a confident continuous 5 km.',
      durationWeeks: 8,
      targetAudience: 'Beginners & runners rebuilding base fitness',
      schedule: schedule,
    );
  }

  /// Built-in Plan 2: 4-Week Pace Builder
  static TrainingPlan get paceBuilder4Week {
    final schedule = <PlanWorkoutDay>[];

    for (int w = 1; w <= 4; w++) {
      for (int d = 1; d <= 7; d++) {
        if (d == 2) {
          schedule.add(
            PlanWorkoutDay(
              id: 'pace_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: 'Tempo Speed Repeats',
              description: '5 sets: 2 min fast stride, 1 min recovery jog.',
              intervalPlan: IntervalWorkoutPlan.fiveByTwoFastOneEasy,
              targetDistanceKm: 3.5 + (w * 0.4),
            ),
          );
        } else if (d == 4) {
          schedule.add(
            PlanWorkoutDay(
              id: 'pace_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: 'Aerobic Threshold Cruise',
              description: 'Consistent rhythm run slightly below race pace.',
              targetDistanceKm: 4.0 + (w * 0.5),
            ),
          );
        } else if (d == 6) {
          schedule.add(
            PlanWorkoutDay(
              id: 'pace_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: 'Endurance Territory Claim',
              description:
                  'Long steady run exploring new outer boundary loops.',
              targetDistanceKm: 5.5 + (w * 0.5),
            ),
          );
        } else {
          schedule.add(
            PlanWorkoutDay(
              id: 'pace_w${w}_d$d',
              weekNumber: w,
              dayNumber: d,
              title: 'Rest & Recovery',
              description: 'Active recovery or complete rest.',
              isRestDay: true,
            ),
          );
        }
      }
    }

    return TrainingPlan(
      id: 'plan_pace_builder_4w',
      title: 'Pace Builder',
      subtitle: '4 Weeks • 3 sessions/week',
      description: 'Sharpen your 5K/10K pacing with structured threshold repeats and steady endurance expansion.',
      durationWeeks: 4,
      targetAudience: 'Intermediate runners aiming to break pace plateaus',
      schedule: schedule,
    );
  }
}

/// Runner's local progress within an enrolled training plan.
class UserPlanEnrollment {
  final String planId;
  final DateTime enrolledAt;
  final Set<String> completedWorkoutIds;
  final DateTime? lastCompletedAt;

  const UserPlanEnrollment({
    required this.planId,
    required this.enrolledAt,
    this.completedWorkoutIds = const {},
    this.lastCompletedAt,
  });

  UserPlanEnrollment copyWith({
    String? planId,
    DateTime? enrolledAt,
    Set<String>? completedWorkoutIds,
    DateTime? lastCompletedAt,
  }) {
    return UserPlanEnrollment(
      planId: planId ?? this.planId,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      completedWorkoutIds: completedWorkoutIds ?? this.completedWorkoutIds,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'enrolledAt': enrolledAt.toIso8601String(),
    'completedWorkoutIds': completedWorkoutIds.toList(),
    'lastCompletedAt': lastCompletedAt?.toIso8601String(),
  };

  factory UserPlanEnrollment.fromJson(Map<String, dynamic> json) =>
      UserPlanEnrollment(
        planId: json['planId'] as String,
        enrolledAt: DateTime.parse(json['enrolledAt'] as String),
        completedWorkoutIds: (json['completedWorkoutIds'] as List? ?? [])
            .map((e) => e.toString())
            .toSet(),
        lastCompletedAt: json['lastCompletedAt'] != null
            ? DateTime.parse(json['lastCompletedAt'] as String)
            : null,
      );
}
