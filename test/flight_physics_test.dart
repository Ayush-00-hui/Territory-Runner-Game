import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/physics/flight_physics_controller.dart';
import 'package:territory_runner/models/runner_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlightPhysicsController Tests', () {
    late FlightPhysicsController controller;

    setUp(() {
      controller = FlightPhysicsController();
    });

    tearDown(() {
      controller.stopPhysicsLoop();
    });

    test('Initial ground state', () {
      expect(controller.altitude, 0.0);
      expect(controller.isAirborne, isFalse);
      expect(controller.conquestMultiplier, 1.0);
      expect(controller.isThrusterEngaged, isFalse);
      expect(controller.energy, 100.0);
    });

    test('Thruster toggle and inverted gravity simulation', () {
      controller.setThruster(true);
      expect(controller.isThrusterEngaged, isTrue);

      controller.setThruster(false);
      expect(controller.isThrusterEngaged, isFalse);
    });

    test('RunnerProfile multiplier applies correctly to XP rewards', () {
      final profile = RunnerProfile(
        id: 'test_runner',
        username: 'AeroAce',
        totalDistanceKm: 5.0,
        xp: 0,
        level: 1,
        badges: [],
        totalHexesClaimed: 0,
        currentStreak: 1,
      );

      // Normal ground claim (1.0x -> +10 XP)
      profile.claimHex(multiplier: 1.0);
      expect(profile.xp, 10);
      expect(profile.totalHexesClaimed, 1);

      // Airborne claim (1.5x -> +15 XP)
      profile.claimHex(multiplier: 1.5);
      expect(profile.xp, 25);
      expect(profile.totalHexesClaimed, 2);
    });
  });
}
