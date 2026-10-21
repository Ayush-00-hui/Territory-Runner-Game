import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/map/notifiers/run_telemetry_notifier.dart';
import 'package:territory_runner/models/run_goal.dart';

void main() {
  group('RunTelemetryNotifier Phase 3 State Isolation Tests', () {
    late RunTelemetryNotifier notifier;

    setUp(() {
      notifier = RunTelemetryNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('Initial telemetry has default zero state', () {
      final t = notifier.value;
      expect(t.distanceKm, equals(0.0));
      expect(t.elapsedSeconds, equals(0));
      expect(t.movingSeconds, equals(0));
      expect(t.splitPace, equals('--:--'));
      expect(t.isRunActive, isFalse);
      expect(t.isAutoPaused, isFalse);
    });

    test(
      'tick increments both elapsed and moving seconds when not auto-paused',
      () {
        notifier.tick(isAutoPaused: false);
        notifier.tick(isAutoPaused: false);

        expect(notifier.value.elapsedSeconds, equals(2));
        expect(notifier.value.movingSeconds, equals(2));
        expect(notifier.value.isAutoPaused, isFalse);
      },
    );

    test('tick increments only elapsed seconds when auto-paused', () {
      notifier.tick(isAutoPaused: false); // 1s moving
      notifier.tick(isAutoPaused: true); // 1s paused
      notifier.tick(isAutoPaused: true); // 1s paused

      expect(notifier.value.elapsedSeconds, equals(3));
      expect(notifier.value.movingSeconds, equals(1));
      expect(notifier.value.isAutoPaused, isTrue);
    });

    test('updateGps accurately reflects latest kinematic metrics', () {
      notifier.updateGps(
        speedKmh: 12.4,
        accuracyMeters: 2.1,
        distanceKm: 3.52,
        splitPace: '4:50',
        distanceToClosure: 45.0,
        proximityToClosure: 0.88,
        currentAreaSqm: 1250.0,
      );

      final t = notifier.value;
      expect(t.currentSpeedKmh, equals(12.4));
      expect(t.satelliteAccuracyMeters, equals(2.1));
      expect(t.distanceKm, equals(3.52));
      expect(t.splitPace, equals('4:50'));
      expect(t.distanceToClosureMeters, equals(45.0));
      expect(t.proximityToClosure, equals(0.88));
      expect(t.currentAreaSqm, equals(1250.0));
    });

    test('State lifecycle transitions: active, autoPaused, goal, reset', () {
      notifier.setRunActive(true);
      expect(notifier.value.isRunActive, isTrue);

      notifier.setAutoPaused(true);
      expect(notifier.value.isAutoPaused, isTrue);

      const goal = RunGoal(type: GoalType.distance, targetValue: 5.0);
      notifier.setGoal(goal);
      expect(notifier.value.activeGoal?.targetValue, equals(5.0));

      notifier.setTerritoriesClaimed(3);
      expect(notifier.value.territoriesClaimed, equals(3));

      notifier.reset();
      expect(notifier.value.elapsedSeconds, equals(0));
      expect(notifier.value.distanceKm, equals(0.0));
      expect(notifier.value.territoriesClaimed, equals(0));
      expect(notifier.value.isRunActive, isFalse);
    });
  });
}
