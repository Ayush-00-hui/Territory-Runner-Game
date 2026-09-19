import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/models/territory.dart';

void main() {
  group('RunnerProfile Model Tests', () {
    test('addXp correctly increases XP and computes level up threshold', () {
      final profile = RunnerProfile(id: 'test_1', username: 'SpeedRunner');
      expect(profile.level, equals(1));
      expect(profile.xp, equals(0));

      // Level 1 requires 250 XP to reach Level 2
      final bool leveledUp = profile.addXp(260);
      expect(leveledUp, isTrue);
      expect(profile.level, equals(2));
      expect(profile.xp, equals(10)); // 260 - 250
    });

    test('claimHex awards 10 XP and unlocks First Conquest badge', () {
      final profile = RunnerProfile(id: 'test_2', username: 'GridRider');
      expect(profile.totalHexesClaimed, equals(0));

      profile.claimHex();
      expect(profile.totalHexesClaimed, equals(1));
      expect(profile.xp, equals(10));
      expect(profile.badges.contains('First Conquest'), isTrue);
    });

    test('addDistance unlocks 10K Centurion badge when reaching 10km', () {
      final profile = RunnerProfile(id: 'test_3', username: 'Marathoner');
      profile.addDistance(10.5);
      expect(profile.totalDistanceKm, equals(10.5));
      expect(profile.badges.contains('10K Centurion'), isTrue);
    });
  });

  group('Territory Model Tests', () {
    test('Territory JSON serialization and deserialization round-trip', () {
      final territory = Territory(
        id: '8a1072b59ffffff',
        ownerId: 'runner_99',
        polygon: [const LatLng(37.7749, -122.4194), const LatLng(37.7750, -122.4190)],
        areaSqMeters: 15047.0,
        capturedAt: DateTime(2026, 9, 19, 12, 0),
        isPendingReview: false,
      );

      final json = territory.toJson();
      final fromJson = Territory.fromJson(json);

      expect(fromJson.id, equals(territory.id));
      expect(fromJson.ownerId, equals(territory.ownerId));
      expect(fromJson.polygon.length, equals(2));
      expect(fromJson.areaSqMeters, equals(15047.0));
      expect(fromJson.isPendingReview, isFalse);
    });
  });
}
