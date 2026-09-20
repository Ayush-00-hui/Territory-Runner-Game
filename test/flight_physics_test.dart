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

    test('Initial ground traction state and friction', () {
      expect(controller.altitude, 0.0);
      expect(controller.isAirborne, isFalse);
      expect(controller.conquestMultiplier, 1.0);
      expect(controller.isThrusterEngaged, isFalse);
      expect(controller.energy, 100.0);
      expect(controller.kinematicState, KinematicState.groundTraction);
      expect(controller.friction, 0.82);
    });

    test('Zero-G sub-orbital glide transition and momentum boost', () {
      controller.setThruster(true, currentRunSpeedMps: 4.0);
      expect(controller.isThrusterEngaged, isTrue);
      expect(controller.kinematicState, KinematicState.zeroGSubOrbitalGlide);
      expect(controller.friction, 0.985);
      expect(controller.momentumBoostActive, isTrue);
      // 4.0 * 1.40 = 5.60 m/s
      expect(controller.forwardVelocity, closeTo(5.60, 0.01));

      controller.setThruster(false);
      expect(controller.isThrusterEngaged, isFalse);
      expect(controller.kinematicState, KinematicState.groundTraction);
      expect(controller.friction, 0.82);
      expect(controller.momentumBoostActive, isFalse);
    });

    test('Quantum flux battery recharge', () {
      controller.rechargeEnergy(15.0);
      expect(controller.energy, 100.0); // Clamped at 100
    });

    test('RunnerProfile multiplier applies correctly to XP rewards and arbitrary polygons', () {
      final profile = RunnerProfile(
        id: 'test_runner',
        username: 'AeroAce',
        totalDistanceKm: 5.0,
        xp: 0,
        level: 1,
        badges: [],
        totalHexesClaimed: 0,
        currentStreak: 1,
        faction: 'Quantum Pulse',
      );

      // Normal ground claim (1.0x -> +10 XP)
      profile.claimHex(multiplier: 1.0);
      expect(profile.xp, 10);
      expect(profile.totalHexesClaimed, 1);

      // Airborne claim (1.5x -> +15 XP)
      profile.claimHex(multiplier: 1.5);
      expect(profile.xp, 25);
      expect(profile.totalHexesClaimed, 2);

      // Arbitrary polygon claim: 1000 m² -> max(100, 1000 / 20) * 1.5 = 150 XP
      final gainedXp = profile.claimPolygonArea(1000.0, multiplier: 1.5);
      expect(gainedXp, 150);
      expect(profile.xp, 175);
      expect(profile.totalHexesClaimed, 3);
      expect(profile.faction, 'Quantum Pulse');

      // Larger polygon claim: 4000 m² -> max(100, 200) * 1.0 = 200 XP
      // Total XP gained = 175 + 200 = 375. Level 1 needs 250 XP -> Level 2 with 125 XP remaining.
      final gainedXp2 = profile.claimPolygonArea(4000.0, multiplier: 1.0);
      expect(gainedXp2, 200);
      expect(profile.level, 2);
      expect(profile.xp, 125);
      expect(profile.totalHexesClaimed, 4);
    });
  });
}
