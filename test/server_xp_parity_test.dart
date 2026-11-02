import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/runner_profile.dart';

void main() {
  group('C6 Server & Client XP Parity Tests (Option A)', () {
    test(
      'Loops below the 25 m² floor award zero XP and do not increment count',
      () {
        final profile = RunnerProfile(
          id: 'test_sub_floor',
          username: 'FloorTester',
        );
        final xp = profile.claimPolygonArea(24.9);
        expect(xp, 0);
        expect(profile.xp, 0);
        expect(profile.totalTerritoriesClaimed, 0);
      },
    );

    final testCases = [
      {
        'area': 25.0,
        'expectedXP': 5,
        'desc': '25 m² minimum valid loop (anti-farming floor)',
      },
      {
        'area': 40.0,
        'expectedXP': 5,
        'desc': '40 m² loop (40/20 = 2 -> floor 5)',
      },
      {'area': 100.0, 'expectedXP': 5, 'desc': '100 m² loop (100/20 = 5)'},
      {
        'area': 500.0,
        'expectedXP': 25,
        'desc': '500 m² park loop (500/20 = 25)',
      },
      {
        'area': 2000.0,
        'expectedXP': 100,
        'desc': '2,000 m² neighbourhood loop (2000/20 = 100)',
      },
      {
        'area': 10000.0,
        'expectedXP': 500,
        'desc': '10,000 m² large loop (10000/20 = 500)',
      },
    ];

    for (final tc in testCases) {
      test(
        'Loop of ${tc['area']} m² awards ${tc['expectedXP']} XP (${tc['desc']})',
        () {
          final profile = RunnerProfile(
            id: 'test_${tc['area']}',
            username: 'Runner',
          );
          final double area = tc['area'] as double;
          final int expected = tc['expectedXP'] as int;

          final xp = profile.claimPolygonArea(area);
          expect(xp, expected);
          if (expected < 250) {
            expect(profile.xp, expected);
            expect(profile.level, 1);
          } else {
            expect(profile.level, 2);
            expect(profile.xp, expected - 250);
          }
          expect(profile.totalTerritoriesClaimed, 1);
        },
      );
    }

    test('Multiplier proportionally scales XP award above floor', () {
      final profile = RunnerProfile(
        id: 'test_multiplier',
        username: 'BonusRunner',
      );
      // 2000 m² -> 100 base XP * 1.5 = 150 XP
      final xp = profile.claimPolygonArea(2000.0, multiplier: 1.5);
      expect(xp, 150);
      expect(profile.xp, 150);
    });

    test('Repeated tiny loops cannot farm disproportionate XP', () {
      final profile = RunnerProfile(id: 'test_farmer', username: 'Farmer');
      // 10 tiny loops (25 m² each = 250 m² total)
      for (int i = 0; i < 10; i++) {
        profile.claimPolygonArea(25.0);
      }
      // Previously gave 10 * 100 = 1,000 XP! Now gives 10 * 5 = 50 XP
      expect(profile.xp, 50);
      expect(profile.totalTerritoriesClaimed, 10);
    });
  });
}
