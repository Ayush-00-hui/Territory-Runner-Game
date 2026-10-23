import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/runner_profile.dart';

void main() {
  group('Badge & Faction Alias / Migration Tests', () {
    test('legacy badges from JSON or Hive are migrated without dropping already-earned badges', () {
      final legacyJson = {
        'id': 'legacy_runner_1',
        'username': 'LegacyAthlete',
        'faction': 'Cyber Vanguard',
        'totalDistanceKm': 15.5,
        'xp': 1200,
        'level': 3,
        'badges': [
          'Cyber Rookie',
          'First Conquest',
          'Territory Sovereign',
          '10K Centurion',
        ],
        'totalHexesClaimed': 10,
        'currentStreak': 5,
      };

      final profile = RunnerProfile.fromJson(legacyJson);

      // Verify legacy badge names are preserved (backward-compatible)
      expect(
        profile.badges.contains('Territory Sovereign'),
        isTrue,
        reason: 'Legacy Territory Sovereign badge must not be dropped',
      );
      expect(profile.badges.contains('First Conquest'), isTrue);
      expect(profile.badges.contains('Cyber Rookie'), isTrue);
      expect(profile.badges.contains('10K Centurion'), isTrue);

      // Verify canonical alias badges are automatically available
      expect(
        profile.badges.contains('Territory Master'),
        isTrue,
        reason: 'Canonical Territory Master badge must be populated',
      );
      expect(profile.badges.contains('First Claim'), isTrue);
      expect(profile.badges.contains('Rookie Runner'), isTrue);

      // Verify hasBadge resolver works seamlessly with both old and new names
      expect(profile.hasBadge('Territory Sovereign'), isTrue);
      expect(profile.hasBadge('Territory Master'), isTrue);
      expect(profile.hasBadge('First Conquest'), isTrue);
      expect(profile.hasBadge('First Claim'), isTrue);
      expect(profile.hasBadge('Cyber Rookie'), isTrue);
      expect(profile.hasBadge('Rookie Runner'), isTrue);
      expect(profile.hasBadge('10K Centurion'), isTrue);
      expect(profile.hasBadge('Nonexistent Badge'), isFalse);
    });

    test('faction alias maps Cyber Vanguard to calm display faction Vanguard while keeping raw value', () {
      final profile = RunnerProfile(
        id: 'usr_vanguard',
        username: 'PacerOne',
        faction: 'Cyber Vanguard',
      );

      // Raw value preserved for API / backend parity
      expect(profile.faction, equals('Cyber Vanguard'));

      // Calm display faction
      expect(profile.displayFaction, equals('Vanguard'));
      expect(
        RunnerProfile.factionAliases['Cyber Vanguard'],
        equals('Vanguard'),
      );
    });

    test('other factions map cleanly via factionAliases', () {
      final syndicateProfile = RunnerProfile(
        id: 'usr_syndicate',
        username: 'IronRunner',
        faction: 'Iron Syndicate',
      );
      expect(syndicateProfile.displayFaction, equals('Syndicate'));

      final nomadProfile = RunnerProfile(
        id: 'usr_nomad',
        username: 'NeonRunner',
        faction: 'Neon Nomads',
      );
      expect(nomadProfile.displayFaction, equals('Nomads'));
    });

    test('claiming territory awards both canonical and legacy alias badges to keep all consumers working', () {
      final profile = RunnerProfile(
        id: 'usr_new',
        username: 'NewRunner',
        totalHexesClaimed: 0,
        badges: ['Rookie Runner', 'Cyber Rookie'],
      );

      expect(profile.hasBadge('Territory Sovereign'), isFalse);
      expect(profile.hasBadge('Territory Master'), isFalse);

      // Claim polygon area
      profile.claimPolygonArea(15000.0);

      expect(profile.totalHexesClaimed, equals(1));
      expect(profile.badges.contains('Territory Master'), isTrue);
      expect(profile.badges.contains('Territory Sovereign'), isTrue);
      expect(profile.hasBadge('Territory Master'), isTrue);
      expect(profile.hasBadge('Territory Sovereign'), isTrue);

      expect(profile.badges.contains('First Claim'), isTrue);
      expect(profile.badges.contains('First Conquest'), isTrue);
      expect(profile.hasBadge('First Claim'), isTrue);
      expect(profile.hasBadge('First Conquest'), isTrue);
    });

    test('leveling and milestone evaluations award Area Leader and Grid Leader aliases', () {
      final profile = RunnerProfile(
        id: 'usr_milestone',
        username: 'EliteRunner',
        totalHexesClaimed: 24,
        badges: ['Rookie Runner'],
      );

      // Reach 25 claimed
      profile.claimHex();
      expect(profile.totalHexesClaimed, equals(25));
      expect(profile.hasBadge('Area Leader'), isTrue);
      expect(profile.hasBadge('Sector Commander'), isTrue);
    });
  });
}
