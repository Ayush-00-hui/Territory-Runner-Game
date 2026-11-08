import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:territory_runner/features/coach/llm_coach_service.dart';
import 'package:territory_runner/features/map/widgets/interval_workout_banner.dart';
import 'package:territory_runner/features/map/widgets/interval_workout_picker_sheet.dart';
import 'package:territory_runner/features/map/widgets/summary_sheet.dart';
import 'package:territory_runner/models/interval_workout.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/services/app_preferences.dart';
import 'package:territory_runner/services/countdown_audio_service.dart';
import 'package:territory_runner/services/interval_workout_service.dart';
import 'package:territory_runner/ui/theme/app_theme.dart';

class MockCountdownAudioService extends CountdownAudioService {
  MockCountdownAudioService() : super.forTesting();
  int workCueCalls = 0;
  int restCueCalls = 0;

  @override
  Future<void> playIntervalWork() async {
    workCueCalls++;
  }

  @override
  Future<void> playIntervalRest() async {
    restCueCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task F4: Interval Workout Models and Serialization', () {
    test('beginnerRunWalk preset has expected phase count and duration', () {
      final plan = IntervalWorkoutPlan.beginnerRunWalk;
      expect(plan.id, equals('preset_beginner_run_walk'));
      // 1 warm up + 8 * (run + walk) + 1 cool down = 18 phases
      expect(plan.phases.length, equals(18));
      expect(plan.phases.first.type, equals(WorkoutPhaseType.warmup));
      expect(plan.phases.last.type, equals(WorkoutPhaseType.cooldown));
      // 180 + 8 * (60 + 120) + 120 = 1740s = 29 minutes
      expect(plan.totalPlannedDurationSeconds, equals(1740));
    });

    test('fiveByTwoFastOneEasy preset has expected structure', () {
      final plan = IntervalWorkoutPlan.fiveByTwoFastOneEasy;
      expect(plan.id, equals('preset_5x_2min_fast'));
      // 1 warm up + 5 * 2 + 1 cool down = 12 phases
      expect(plan.phases.length, equals(12));
      // 300 + 5 * (120 + 60) + 180 = 1380s = 23 minutes
      expect(plan.totalPlannedDurationSeconds, equals(1380));
    });

    test('custom plan builder configures repeats and targets properly', () {
      final custom = IntervalWorkoutPlan.custom(
        warmupSeconds: 120,
        repeats: 3,
        runSeconds: 45,
        walkSeconds: 75,
        cooldownSeconds: 60,
        name: 'Hill repeats',
      );
      expect(custom.name, equals('Hill repeats'));
      expect(custom.phases.length, equals(1 + 3 * 2 + 1)); // 8 phases
      expect(custom.totalPlannedDurationSeconds, equals(120 + 3 * 120 + 60));
    });

    test('JSON serialization roundtrip maintains fidelity', () {
      final original = IntervalWorkoutPlan.custom(
        warmupSeconds: 60,
        repeats: 2,
        runSeconds: 30,
        walkSeconds: 30,
        cooldownSeconds: 60,
      );
      final json = original.toJson();
      final revived = IntervalWorkoutPlan.fromJson(json);

      expect(revived.id, equals(original.id));
      expect(revived.name, equals(original.name));
      expect(revived.phases.length, equals(original.phases.length));
      expect(
        revived.phases.first.targetSeconds,
        equals(original.phases.first.targetSeconds),
      );
    });

    test('WorkoutPhaseExecution formats actual duration cleanly', () {
      const phase = WorkoutPhase(
        id: 'p1',
        name: 'Fast lap',
        type: WorkoutPhaseType.run,
        targetSeconds: 60,
      );
      const execution = WorkoutPhaseExecution(
        phase: phase,
        actualDurationSeconds: 65,
        actualDistanceM: 250.0,
        isCompleted: true,
      );
      expect(execution.formattedActualDuration, equals('1:05'));
    });
  });

  group('Task F4: Pure Dart Interval Workout Timeline Engine', () {
    late MockCountdownAudioService mockAudio;

    setUp(() async {
      mockAudio = MockCountdownAudioService();
      await AppPreferences().toggleSoundEffects(false);
      await AppPreferences().toggleHaptics(false);
    });

    test(
      'Phase transitions advance through warm-up, repeats, and cool-down',
      () {
        const plan = IntervalWorkoutPlan(
          id: 'test_plan',
          name: 'Quick intervals',
          description: 'Test workout',
          phases: [
            WorkoutPhase(
              id: 'w',
              name: 'Warm up',
              type: WorkoutPhaseType.warmup,
              targetSeconds: 3,
            ),
            WorkoutPhase(
              id: 'r1',
              name: 'Run 1',
              type: WorkoutPhaseType.run,
              targetSeconds: 2,
            ),
            WorkoutPhase(
              id: 'cd',
              name: 'Cool down',
              type: WorkoutPhaseType.cooldown,
              targetSeconds: 2,
            ),
          ],
        );

        final timeline = IntervalWorkoutTimeline(
          plan: plan,
          audioService: mockAudio,
          initialDistanceM: 0.0,
        );

        expect(timeline.currentPhaseIndex, equals(0));
        expect(timeline.currentPhase.name, equals('Warm up'));
        expect(timeline.isCompleted, isFalse);

        // Tick 2 seconds (still in Warm up)
        timeline.tick(secondsDelta: 2, currentRunDistanceMeters: 5.0);
        expect(timeline.currentPhaseIndex, equals(0));
        expect(timeline.isCompleted, isFalse);

        // Tick 1 second (completes Warm up -> transitions to Run 1)
        timeline.tick(secondsDelta: 1, currentRunDistanceMeters: 10.0);
        expect(timeline.currentPhaseIndex, equals(1));
        expect(timeline.currentPhase.name, equals('Run 1'));

        // Tick 2 seconds (completes Run 1 -> transitions to Cool down)
        timeline.tick(secondsDelta: 2, currentRunDistanceMeters: 30.0);
        expect(timeline.currentPhaseIndex, equals(2));
        expect(timeline.currentPhase.name, equals('Cool down'));

        // Tick 2 seconds (completes Cool down -> workout ends)
        bool completedCallbackFired = false;
        timeline.onWorkoutCompleted = () => completedCallbackFired = true;
        timeline.tick(secondsDelta: 2, currentRunDistanceMeters: 40.0);

        expect(timeline.isCompleted, isTrue);
        expect(completedCallbackFired, isTrue);
        expect(timeline.executions.length, equals(3));
        expect(timeline.executions[0].phase.name, equals('Warm up'));
        expect(timeline.executions[0].actualDurationSeconds, equals(3));
        expect(timeline.executions[1].phase.name, equals('Run 1'));
        expect(timeline.executions[1].actualDurationSeconds, equals(2));
        expect(timeline.executions[2].phase.name, equals('Cool down'));
        expect(timeline.executions[2].actualDurationSeconds, equals(2));
      },
    );

    test('Skip phase transitions immediately and records skipped status', () {
      const plan = IntervalWorkoutPlan(
        id: 'test_skip',
        name: 'Skip test',
        description: 'Skip testing',
        phases: [
          WorkoutPhase(
            id: 'p1',
            name: 'Warm up',
            type: WorkoutPhaseType.warmup,
            targetSeconds: 120,
          ),
          WorkoutPhase(
            id: 'p2',
            name: 'Sprint',
            type: WorkoutPhaseType.run,
            targetSeconds: 60,
          ),
        ],
      );

      final timeline = IntervalWorkoutTimeline(
        plan: plan,
        audioService: mockAudio,
      );
      timeline.tick(secondsDelta: 10, currentRunDistanceMeters: 20.0);

      // User taps skip button
      timeline.skipPhase(currentRunDistanceMeters: 25.0);

      expect(timeline.currentPhaseIndex, equals(1));
      expect(timeline.currentPhase.name, equals('Sprint'));
      expect(timeline.executions.length, equals(1));
      expect(timeline.executions.first.isSkipped, isTrue);
      expect(timeline.executions.first.actualDurationSeconds, equals(10));
    });

    test(
      'Pause and resume stops workout clock from accumulating elapsed time',
      () {
        const plan = IntervalWorkoutPlan(
          id: 'test_pause',
          name: 'Pause test',
          description: 'Auto pause test',
          phases: [
            WorkoutPhase(
              id: 'p1',
              name: 'Run',
              type: WorkoutPhaseType.run,
              targetSeconds: 10,
            ),
          ],
        );

        final timeline = IntervalWorkoutTimeline(
          plan: plan,
          audioService: mockAudio,
        );
        timeline.tick(secondsDelta: 3, currentRunDistanceMeters: 10.0);
        expect(
          timeline.getSnapshot(currentDistanceM: 10.0).remainingSeconds,
          equals(7),
        );

        // Auto-pause occurs
        timeline.pause();
        expect(timeline.isPaused, isTrue);

        // Ticks while paused should be ignored
        timeline.tick(secondsDelta: 5, currentRunDistanceMeters: 10.0);
        expect(
          timeline.getSnapshot(currentDistanceM: 10.0).remainingSeconds,
          equals(7),
        );

        // Resume
        timeline.resume();
        expect(timeline.isPaused, isFalse);
        timeline.tick(secondsDelta: 4, currentRunDistanceMeters: 20.0);
        expect(
          timeline.getSnapshot(currentDistanceM: 20.0).remainingSeconds,
          equals(3),
        );
      },
    );

    test('Distance-based phases advance when target distance is reached', () {
      const plan = IntervalWorkoutPlan(
        id: 'test_distance',
        name: 'Track laps',
        description: 'Distance intervals',
        phases: [
          WorkoutPhase(
            id: 'lap1',
            name: 'Lap 1',
            type: WorkoutPhaseType.run,
            targetType: WorkoutTargetType.distance,
            targetDistanceM: 400.0,
          ),
          WorkoutPhase(
            id: 'lap2',
            name: 'Lap 2',
            type: WorkoutPhaseType.walk,
            targetType: WorkoutTargetType.distance,
            targetDistanceM: 200.0,
          ),
        ],
      );

      final timeline = IntervalWorkoutTimeline(
        plan: plan,
        audioService: mockAudio,
        initialDistanceM: 100.0,
      );

      // Advance 250m (relative to 100m -> 350m total)
      timeline.tick(secondsDelta: 30, currentRunDistanceMeters: 350.0);
      expect(timeline.currentPhaseIndex, equals(0));
      expect(
        timeline.getSnapshot(currentDistanceM: 350.0).remainingDistanceMeters,
        equals(150.0),
      );

      // Reach 400m target (total distance 500m)
      timeline.tick(secondsDelta: 15, currentRunDistanceMeters: 500.0);
      expect(timeline.currentPhaseIndex, equals(1));
      expect(timeline.currentPhase.name, equals('Lap 2'));
      expect(timeline.executions.first.actualDistanceM, closeTo(400.0, 0.1));
    });

    test('Zero-length and short phases handle smoothly without hanging', () {
      const plan = IntervalWorkoutPlan(
        id: 'test_zero',
        name: 'Instant',
        description: 'Zero test',
        phases: [
          WorkoutPhase(
            id: 'zero',
            name: 'Zero Phase',
            type: WorkoutPhaseType.warmup,
            targetSeconds: 0,
          ),
          WorkoutPhase(
            id: 'real',
            name: 'Real Phase',
            type: WorkoutPhaseType.run,
            targetSeconds: 5,
          ),
        ],
      );

      final timeline = IntervalWorkoutTimeline(
        plan: plan,
        audioService: mockAudio,
      );
      // Zero phase should auto-advance upon initialization or initial check
      expect(timeline.currentPhaseIndex, equals(1));
      expect(timeline.currentPhase.name, equals('Real Phase'));
    });
  });

  group('Task F4: Audio and Haptic Gating', () {
    test(
      'Audio cues play on phase transitions when sound effects are enabled',
      () async {
        final mockAudio = MockCountdownAudioService();
        await AppPreferences().toggleSoundEffects(true);
        await AppPreferences().toggleHaptics(false);
        final prefs = AppPreferences();

        const plan = IntervalWorkoutPlan(
          id: 'cue_test',
          name: 'Cue test',
          description: 'Sound test',
          phases: [
            WorkoutPhase(
              id: 'w',
              name: 'Warm up',
              type: WorkoutPhaseType.warmup,
              targetSeconds: 1,
            ),
            WorkoutPhase(
              id: 'r',
              name: 'Run',
              type: WorkoutPhaseType.run,
              targetSeconds: 1,
            ),
          ],
        );

        // Constructor triggers initial cue for warm up (rest chime)
        final timeline = IntervalWorkoutTimeline(
          plan: plan,
          audioService: mockAudio,
          appPrefs: prefs,
        );
        expect(mockAudio.restCueCalls, equals(1));

        // Advance to Run (triggers work chime)
        timeline.tick(secondsDelta: 1, currentRunDistanceMeters: 5.0);
        expect(mockAudio.workCueCalls, equals(1));

        // Complete workout (triggers rest chime)
        timeline.tick(secondsDelta: 1, currentRunDistanceMeters: 10.0);
        expect(mockAudio.restCueCalls, equals(2));
      },
    );

    test('Audio cues are muted when sound effects are disabled', () async {
      final mockAudio = MockCountdownAudioService();
      await AppPreferences().toggleSoundEffects(false);
      await AppPreferences().toggleHaptics(false);
      final prefs = AppPreferences();

      const plan = IntervalWorkoutPlan(
        id: 'mute_test',
        name: 'Mute test',
        description: 'Mute test',
        phases: [
          WorkoutPhase(
            id: 'r',
            name: 'Run',
            type: WorkoutPhaseType.run,
            targetSeconds: 1,
          ),
        ],
      );

      final timeline = IntervalWorkoutTimeline(
        plan: plan,
        audioService: mockAudio,
        appPrefs: prefs,
      );
      expect(mockAudio.workCueCalls, equals(0));

      timeline.tick(secondsDelta: 1, currentRunDistanceMeters: 5.0);
      expect(mockAudio.restCueCalls, equals(0));
    });

    test('Haptic triggers respect pref toggle state', () async {
      await AppPreferences().toggleHaptics(false);
      expect(AppPreferences().isHapticsEnabled, isFalse);

      await AppPreferences().toggleHaptics(true);
      expect(AppPreferences().isHapticsEnabled, isTrue);

      // Verify triggers do not throw
      await expectLater(AppPreferences().triggerIntervalRunHaptic(), completes);
      await expectLater(
        AppPreferences().triggerIntervalWalkHaptic(),
        completes,
      );
    });
  });

  group('Task F4: IntervalWorkoutService Offline Persistence', () {
    test('getAvailablePlans returns default presets out of the box', () async {
      SharedPreferences.setMockInitialValues({});
      final service = IntervalWorkoutService();
      final plans = await service.getAvailablePlans();

      expect(plans.length, greaterThanOrEqualTo(2));
      expect(plans.any((p) => p.id == 'preset_beginner_run_walk'), isTrue);
      expect(plans.any((p) => p.id == 'preset_5x_2min_fast'), isTrue);
    });

    test(
      'saveCustomPlan persists custom plan to local device storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = IntervalWorkoutService();
        final custom = IntervalWorkoutPlan.custom(
          warmupSeconds: 180,
          repeats: 4,
          runSeconds: 90,
          walkSeconds: 90,
          cooldownSeconds: 120,
          name: 'My 4x90 intervals',
        );

        await service.saveCustomPlan(custom);
        final plans = await service.getAvailablePlans();

        expect(plans.length, equals(3));
        final saved = plans.firstWhere((p) => p.id == 'custom_workout');
        expect(saved.name, equals('My 4x90 intervals'));
        expect(saved.phases.length, equals(1 + 4 * 2 + 1));
      },
    );
  });

  group('Task F4: Interval Workout UI Widgets', () {
    testWidgets(
      'IntervalWorkoutBanner renders readable text, step count and handles skip',
      (WidgetTester tester) async {
        bool skipTapped = false;
        final snapshot = IntervalWorkoutSnapshot(
          plan: IntervalWorkoutPlan.beginnerRunWalk,
          currentPhase: const WorkoutPhase(
            id: 'run_1',
            name: 'Run 1/8',
            type: WorkoutPhaseType.run,
            targetSeconds: 60,
          ),
          phaseIndex: 1,
          totalPhases: 18,
          remainingSeconds: 45,
          remainingDistanceMeters: null,
          bannerText: 'RUN 0:45',
          progressFraction: 0.25,
          isCompleted: false,
          isPaused: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: IntervalWorkoutBanner(
                  snapshot: snapshot,
                  onSkipPhase: () => skipTapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('RUN 0:45'), findsOneWidget);
        expect(find.text('Step 2 of 18 • Beginner run-walk'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        await tester.tap(find.text('Skip'));
        expect(skipTapped, isTrue);
      },
    );

    testWidgets(
      'IntervalWorkoutPickerSheet allows selecting workout and Free run',
      (WidgetTester tester) async {
        IntervalWorkoutPlan? selectedPlan = IntervalWorkoutPlan.beginnerRunWalk;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    IntervalWorkoutPickerSheet.show(
                      context: ctx,
                      currentPlan: selectedPlan,
                      onPlanSelected: (plan) => selectedPlan = plan,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Workout plan'), findsOneWidget);
        expect(find.text('Free run'), findsOneWidget);
        expect(find.text('Beginner run-walk'), findsOneWidget);
        expect(find.text('5x (2 min fast + 1 min easy)'), findsOneWidget);

        // Select Free Run
        await tester.tap(find.text('Free run'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm Free run'));
        await tester.pumpAndSettle();

        expect(selectedPlan, isNull);
      },
    );

    testWidgets(
      'SummarySheet displays workout breakdown card with planned vs actual',
      (WidgetTester tester) async {
        final executions = [
          const WorkoutPhaseExecution(
            phase: WorkoutPhase(
              id: 'w',
              name: 'Warm up',
              type: WorkoutPhaseType.warmup,
              targetSeconds: 180,
            ),
            actualDurationSeconds: 182,
            actualDistanceM: 300.0,
            isCompleted: true,
          ),
          const WorkoutPhaseExecution(
            phase: WorkoutPhase(
              id: 'r1',
              name: 'Run 1/8',
              type: WorkoutPhaseType.run,
              targetSeconds: 60,
            ),
            actualDurationSeconds: 59,
            actualDistanceM: 220.0,
            isCompleted: true,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SummarySheet(
                distanceKm: 2.5,
                durationSeconds: 600,
                territoriesClaimed: 1,
                profile: RunnerProfile(id: 'test_u1', username: 'TestUser'),
                coachService: LLMCoachService(),
                workoutPlan: IntervalWorkoutPlan.beginnerRunWalk,
                workoutExecutions: executions,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Beginner run-walk'), findsOneWidget);
        expect(find.text('2 phases'), findsOneWidget);
        expect(find.text('Warm up'), findsOneWidget);
        expect(find.text('3:00'), findsOneWidget);
        expect(find.text('3:02'), findsOneWidget);
        expect(find.text('Run 1/8'), findsOneWidget);
        expect(find.text('1:00'), findsOneWidget);
        expect(find.text('0:59'), findsOneWidget);
      },
    );
  });
}
