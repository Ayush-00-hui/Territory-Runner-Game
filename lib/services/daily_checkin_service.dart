import 'dart:math' as math;

import 'package:hive/hive.dart';

import '../models/run_log_entry.dart';
import '../models/training_plan.dart';
import 'app_preferences.dart';
import 'daily_quest_service.dart';
import 'run_log_service.dart';
import 'training_plan_service.dart';

/// Time slots used for daily goal and health check notifications.
enum DailyCheckInSlot {
  morningKickoff(slotIndex: 0, hour: 8, minute: 30, label: 'Morning kickoff'),
  middayHealthCheck(
    slotIndex: 1,
    hour: 13,
    minute: 15,
    label: 'Midday health check',
  ),
  eveningWrapUp(slotIndex: 2, hour: 18, minute: 45, label: 'Evening check-in');

  final int slotIndex;
  final int hour;
  final int minute;
  final String label;

  const DailyCheckInSlot({
    required this.slotIndex,
    required this.hour,
    required this.minute,
    required this.label,
  });
}

/// A planned daily notification paired with its scheduled local wall time.
class PlannedDailyNotification {
  final int id;
  final DailyCheckInSlot slot;
  final DateTime scheduledLocalTime;
  final String title;
  final String body;
  final String payload;

  const PlannedDailyNotification({
    required this.id,
    required this.slot,
    required this.scheduledLocalTime,
    required this.title,
    required this.body,
    required this.payload,
  });
}

/// Composes and schedules 2-3 daily notifications containing today's running goal,
/// progress toward daily quests, a concise health quote, or a quick health check.
class DailyCheckInService {
  static const int baseNotificationId = 2100;
  static const int previewNotificationId = 2199;
  static const int maxSlotSpan = 9;

  /// Calm, practical health and aerobic endurance quotes.
  static const List<String> healthQuotes = [
    'Steady aerobic minutes strengthen heart efficiency and lower resting pulse.',
    'A short run clears stress hormones and sharpens mental focus for hours.',
    'Easy conversational pace builds capillary endurance without straining joints.',
    'Tendons adapt slower than lungs—keep easy outings smooth and unhurried.',
    'Hydrating early before lacing up lowers cardiac drift on warm days.',
    'Consistent short runs beat occasional exhausted sprints for lifelong health.',
    'Cool down with two easy walking minutes so heart rate returns smoothly.',
    'Calm breathing and quality sleep turn today\'s miles into stronger recovery.',
  ];

  /// Quick everyday wellness & mobility check-in messages.
  static const List<String> healthChecks = [
    'Health check: drink a glass of water, drop your shoulders, and unclench your jaw.',
    'Midday check: stand for two minutes, roll your ankles, and take five slow breaths.',
    'Body check: tight calves? A gentle 60-second calf stretch protects your stride.',
    'Wellness check: even a brisk walk around one block supports circulation and mood.',
    'Recovery check: top up fluids now and check your posture away from screens.',
    'Evening check: stretch stiff hips lightly and wind down for restorative sleep.',
  ];

  /// Returns active slots for the user's selected reminder cadence window.
  static List<DailyCheckInSlot> slotsForWindow(String window) {
    switch (window) {
      case 'off':
        return const [];
      case 'morning':
        return const [
          DailyCheckInSlot.morningKickoff,
          DailyCheckInSlot.middayHealthCheck,
        ];
      case 'evening':
        return const [
          DailyCheckInSlot.middayHealthCheck,
          DailyCheckInSlot.eveningWrapUp,
        ];
      case 'daily_2':
        return const [
          DailyCheckInSlot.morningKickoff,
          DailyCheckInSlot.eveningWrapUp,
        ];
      case 'daily_3':
      default:
        return DailyCheckInSlot.values;
    }
  }

  /// Resolves live today metrics & quests and builds the next 2 days of
  /// scheduled notifications (2-3 per day depending on [window]).
  Future<List<PlannedDailyNotification>> buildScheduleFromAppState({
    DateTime? now,
    String? overrideWindow,
  }) async {
    final currentNow = now ?? DateTime.now();
    final prefs = AppPreferences();
    final window = overrideWindow ?? prefs.dailyReminderWindow;
    final slots = slotsForWindow(window);
    if (slots.isEmpty) return const [];

    final runs = RunLogService().isBoxOpen
        ? RunLogService().getAllRuns()
        : const <RunLogEntry>[];

    final todayQuests = await DailyQuestService().getTodayQuests(
      now: currentNow,
      overrideRuns: runs,
    );

    PlanWorkoutDay? nextWorkout;
    if (Hive.isBoxOpen(TrainingPlanService.boxName)) {
      try {
        nextWorkout = await TrainingPlanService().getNextWorkout();
      } catch (_) {}
    }

    return buildPlan(
      now: currentNow,
      slots: slots,
      quests: todayQuests,
      runs: runs,
      customDailyGoalKm: prefs.dailyGoalKm,
      nextPlanWorkout: nextWorkout,
    );
  }

  /// Pure deterministic planner creating up to 3 notifications/day across today
  /// (remaining future times) and tomorrow.
  static List<PlannedDailyNotification> buildPlan({
    required DateTime now,
    required List<DailyCheckInSlot> slots,
    required List<DailyQuestProgress> quests,
    List<RunLogEntry> runs = const [],
    double? customDailyGoalKm,
    PlanWorkoutDay? nextPlanWorkout,
  }) {
    if (slots.isEmpty) return const [];

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayRuns = runs
        .where((r) => !r.simulated && !r.startedAt.isBefore(todayStart))
        .toList();
    final double todayDistanceKm = todayRuns.fold(
      0.0,
      (sum, r) => sum + (r.distanceM / 1000.0),
    );

    final List<PlannedDailyNotification> planned = [];
    int seqId = 1;

    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final dayDate = todayStart.add(Duration(days: dayOffset));
      for (final slot in slots) {
        final scheduled = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          slot.hour,
          slot.minute,
        );
        if (!scheduled.isAfter(now.add(const Duration(minutes: 1)))) {
          continue;
        }

        final content = composeMessage(
          date: scheduled,
          slot: slot,
          quests: dayOffset == 0 ? quests : const [],
          todayDistanceKm: dayOffset == 0 ? todayDistanceKm : 0.0,
          customDailyGoalKm: customDailyGoalKm,
          nextPlanWorkout: nextPlanWorkout,
        );

        planned.add(
          PlannedDailyNotification(
            id: baseNotificationId + seqId,
            slot: slot,
            scheduledLocalTime: scheduled,
            title: content.title,
            body: content.body,
            payload: 'daily_checkin:${slot.name}',
          ),
        );
        seqId++;
        if (seqId > maxSlotSpan) break;
      }
      if (seqId > maxSlotSpan) break;
    }

    return planned;
  }

  /// Builds a concise `(title, body)` notification pairing today's goal progress
  /// with either a health quote or short wellness check-in.
  static ({String title, String body}) composeMessage({
    required DateTime date,
    required DailyCheckInSlot slot,
    List<DailyQuestProgress> quests = const [],
    double todayDistanceKm = 0.0,
    double? customDailyGoalKm,
    PlanWorkoutDay? nextPlanWorkout,
  }) {
    final int daySeed =
        date.difference(DateTime(date.year, 1, 1)).inDays + date.year;
    final String quote =
        healthQuotes[(daySeed + slot.slotIndex) % healthQuotes.length];
    final String healthCheck =
        healthChecks[(daySeed + slot.slotIndex) % healthChecks.length];

    // Derive primary goal description & remaining effort
    DailyQuestProgress? distQuest;
    DailyQuestProgress? incompleteQuest;
    for (final q in quests) {
      if (q.unit == 'km' && distQuest == null) distQuest = q;
      if (!q.isCompleted && incompleteQuest == null) incompleteQuest = q;
    }

    final double effectiveTargetKm =
        customDailyGoalKm ?? (distQuest != null ? distQuest.target : 2.0);
    final double remainingKm = math.max(
      0.0,
      effectiveTargetKm - todayDistanceKm,
    );
    final bool allQuestsDone =
        quests.isNotEmpty && quests.every((q) => q.isCompleted);

    final String goalSummary = nextPlanWorkout != null
        ? '${nextPlanWorkout.title} (${effectiveTargetKm.toStringAsFixed(1)} km target)'
        : '${effectiveTargetKm.toStringAsFixed(1)} km daily goal';

    switch (slot) {
      case DailyCheckInSlot.morningKickoff:
        final title = "Today's Goal: $goalSummary";
        final progressPart = remainingKm <= 0.05 && todayDistanceKm > 0
            ? 'Goal already reached today (${todayDistanceKm.toStringAsFixed(1)} km logged).'
            : '${effectiveTargetKm.toStringAsFixed(1)} km on the schedule today.';
        return (title: title, body: '$progressPart "$quote"');

      case DailyCheckInSlot.middayHealthCheck:
        if (todayDistanceKm > 0.1) {
          return (
            title:
                'Health & Goal Check · ${todayDistanceKm.toStringAsFixed(1)} km done',
            body:
                '$healthCheck ${remainingKm > 0.05 ? "${remainingKm.toStringAsFixed(1)} km left toward $goalSummary." : "Daily distance goal complete!"}',
          );
        }
        return (
          title: 'Midday Health Check',
          body: '$healthCheck Today\'s focus: $goalSummary.',
        );

      case DailyCheckInSlot.eveningWrapUp:
        if (allQuestsDone || (todayDistanceKm >= effectiveTargetKm)) {
          return (
            title: 'Daily Goal Complete · Recovery Check',
            body:
                '${todayDistanceKm.toStringAsFixed(1)} km logged today. "$quote"',
          );
        }
        final String questHint =
            incompleteQuest != null && incompleteQuest.unit != 'km'
            ? 'Today\'s quest "${incompleteQuest.title}" is still open.'
            : '${remainingKm.toStringAsFixed(1)} km left to finish $goalSummary.';
        return (
          title: 'Evening Goal Check-In',
          body: '$questHint $healthCheck',
        );
    }
  }
}
