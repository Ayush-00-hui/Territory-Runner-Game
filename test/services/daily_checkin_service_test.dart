import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/profile/widgets/settings_list.dart';
import 'package:territory_runner/models/run_log_entry.dart';
import 'package:territory_runner/models/training_plan.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/daily_checkin_service.dart';
import 'package:territory_runner/services/daily_quest_service.dart';
import 'package:territory_runner/services/firebase_service.dart';
import 'package:territory_runner/services/notification_service.dart';
import 'package:territory_runner/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'fcm_permission_prompted': true});
  });

  group('DailyCheckInService & Notification Cadence Tests', () {
    test('slotsForWindow maps off/2-day/3-day windows accurately', () {
      expect(DailyCheckInService.slotsForWindow('off'), isEmpty);
      expect(DailyCheckInService.slotsForWindow('daily_2').length, 2);
      expect(DailyCheckInService.slotsForWindow('morning').length, 2);
      expect(DailyCheckInService.slotsForWindow('evening').length, 2);
      expect(DailyCheckInService.slotsForWindow('daily_3').length, 3);
    });

    test('buildPlan schedules 3 notifications/day containing goal and health content', () {
      final morningNow = DateTime(2026, 11, 27, 7, 15);
      final quests = DailyQuestService().getTodayQuestsSync(now: morningNow);

      final plan = DailyCheckInService.buildPlan(
        now: morningNow,
        slots: DailyCheckInService.slotsForWindow('daily_3'),
        quests: quests,
        customDailyGoalKm: 3.0,
        nextPlanWorkout: TrainingPlan.couchTo5k.schedule.first,
      );

      // Today (3 future slots: 08:30, 13:15, 18:45) + Tomorrow (3 slots) = 6
      expect(plan.length, 6);
      expect(plan[0].scheduledLocalTime.hour, 8);
      expect(plan[1].scheduledLocalTime.hour, 13);
      expect(plan[2].scheduledLocalTime.hour, 18);

      expect(plan[0].title, contains('3.0 km target'));
      expect(
        plan[1].body.toLowerCase(),
        anyOf(contains('water'), contains('check'), contains('stride')),
      );
    });

    test('composeMessage adapts evening message to recovery when daily goal is met', () {
      final now = DateTime(2026, 11, 27, 17, 0);
      final completedQuests = [
        const DailyQuestProgress(
          id: 'q1',
          title: 'Daily distance run',
          description: 'Run 2 km',
          current: 3.2,
          target: 2.0,
          unit: 'km',
          xpReward: 80,
        ),
      ];

      final msg = DailyCheckInService.composeMessage(
        date: now,
        slot: DailyCheckInSlot.eveningWrapUp,
        quests: completedQuests,
        todayDistanceKm: 3.2,
        customDailyGoalKm: 2.0,
      );

      expect(msg.title, contains('Goal Complete'));
      expect(msg.body, contains('3.2 km logged today'));
    });

    test('buildPlan handles unfinished run progress cleanly for remaining day distance', () {
      final afternoonNow = DateTime(2026, 11, 27, 11, 0);
      final partialRun = RunLogEntry(
        id: 'run_partial_1',
        startedAt: DateTime(2026, 11, 27, 7, 30),
        endedAt: DateTime(2026, 11, 27, 7, 45),
        movingSeconds: 900,
        totalSeconds: 900,
        distanceM: 1200.0,
        samples: const [],
      );

      final plan = DailyCheckInService.buildPlan(
        now: afternoonNow,
        slots: DailyCheckInService.slotsForWindow('daily_3'),
        quests: const [],
        runs: [partialRun],
        customDailyGoalKm: 3.0,
      );

      // Today still has 13:15 and 18:45 (2 remaining today + 3 tomorrow = 5)
      expect(plan.length, 5);
      expect(plan.first.title, contains('1.2 km done'));
      expect(plan.first.body, contains('1.8 km left'));
    });

    test('NotificationService syncDailyReminders and sendSampleDailyCheckIn work safely in tests', () async {
      await AppPreferences().setDailyReminderWindow('daily_3');
      final scheduled = await NotificationService().syncDailyReminders(
        now: DateTime(2026, 11, 27, 7, 0),
      );
      expect(scheduled.length, 6);

      final preview = await NotificationService().sendSampleDailyCheckIn();
      expect(preview, isNotNull);
      expect(preview!.body, isNotEmpty);
    });

    testWidgets(
      'ProfileSettingsList exposes 2/day, 3/day and preview check-in controls',
      (tester) async {
        await AppPreferences().setDailyReminderWindow('daily_3');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileSettingsList(
                  firebaseService: FirebaseService(),
                  territoryService: TerritoryService(),
                  onOpenAuth: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Daily run reminder'), findsOneWidget);
        expect(find.text('2/day'), findsOneWidget);
        expect(find.text('3/day'), findsOneWidget);
        expect(find.text('Preview daily check-in'), findsOneWidget);

        await tester.ensureVisible(find.text('2/day'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2/day'));
        await tester.pumpAndSettle();
        expect(AppPreferences().dailyReminderWindow, 'daily_2');

        // Restore default 3/day cadence
        await AppPreferences().setDailyReminderWindow('daily_3');
      },
    );
  });
}
