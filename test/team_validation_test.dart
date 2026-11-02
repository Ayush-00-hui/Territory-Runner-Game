import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/core/utils/team_validation.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/runner_profile.dart';

void main() {
  group('TeamNameValidator - Parity with Server', () {
    test('valid team names pass validation', () {
      expect(TeamNameValidator.validate('Cyber Vanguard'), isNull);
      expect(TeamNameValidator.validate('   Solaris    Nomads   '), isNull);
      expect(TeamNameValidator.validate('team  a'), isNull);
      expect(TeamNameValidator.validate('Team A'), isNull);
      expect(TeamNameValidator.validate('Iron-Legion_99'), isNull);
      expect(TeamNameValidator.validate('ABC'), isNull);
      expect(TeamNameValidator.validate('123456789012345678901234'), isNull);
      expect(TeamNameValidator.validate('Спартак Москва'), isNull);
      expect(TeamNameValidator.validate('Σπάρτη'), isNull);
      expect(TeamNameValidator.validate('東京ランナー'), isNull);
      expect(TeamNameValidator.validate('فريق النصر'), isNull);
      expect(TeamNameValidator.validate('System Shock'), isNull);
      expect(TeamNameValidator.validate('Staff of Hermes'), isNull);
    });

    test('rejects empty and whitespace only', () {
      expect(TeamNameValidator.validate(''), 'Team name cannot be empty');
      expect(TeamNameValidator.validate('     '), 'Team name cannot be empty');
      expect(TeamNameValidator.validate(null), 'Team name cannot be empty');
    });

    test('rejects length bounds', () {
      expect(
        TeamNameValidator.validate('A'),
        'Team name must be at least 3 characters long',
      );
      expect(
        TeamNameValidator.validate('AB'),
        'Team name must be at least 3 characters long',
      );
      expect(
        TeamNameValidator.validate('  AB  '),
        'Team name must be at least 3 characters long',
      );
      expect(
        TeamNameValidator.validate('1234567890123456789012345'),
        'Team name cannot exceed 24 characters',
      );
    });

    test('rejects control characters, newlines, and tabs', () {
      expect(
        TeamNameValidator.validate('Team\nOne'),
        'Team name cannot contain control characters or newlines',
      );
      expect(
        TeamNameValidator.validate('Team\rTwo'),
        'Team name cannot contain control characters or newlines',
      );
      expect(
        TeamNameValidator.validate('Team\tThree'),
        'Team name cannot contain control characters or newlines',
      );
      expect(
        TeamNameValidator.validate('Team\x00Four'),
        'Team name cannot contain control characters or newlines',
      );
    });

    test('rejects zero-width and look-alike spaces', () {
      expect(
        TeamNameValidator.validate('Team\u200BOne'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
      expect(
        TeamNameValidator.validate('Team\u200DTwo'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
      expect(
        TeamNameValidator.validate('\uFEFFTeamThree'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
      expect(
        TeamNameValidator.validate('Team\u00A0Four'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
      expect(
        TeamNameValidator.validate('Team\u3000Five'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
      expect(
        TeamNameValidator.validate('Team\u2001Six'),
        'Team name cannot contain zero-width or non-standard spaces',
      );
    });

    test('rejects HTML and markup tags', () {
      expect(
        TeamNameValidator.validate('<b>Team Alpha</b>'),
        'Team name cannot contain HTML or markup tags',
      );
      expect(
        TeamNameValidator.validate('<script>bad()</script>'),
        'Team name cannot contain HTML or markup tags',
      );
      expect(
        TeamNameValidator.validate('Team <Pro>'),
        'Team name cannot contain HTML or markup tags',
      );
    });

    test('rejects URLs and links', () {
      expect(
        TeamNameValidator.validate('http://team.com'),
        'Team name cannot contain URLs or web links',
      );
      expect(
        TeamNameValidator.validate('https://myteam.io'),
        'Team name cannot contain URLs or web links',
      );
      expect(
        TeamNameValidator.validate('www.runners.org'),
        'Team name cannot contain URLs or web links',
      );
      expect(
        TeamNameValidator.validate('runners.com'),
        'Team name cannot contain URLs or web links',
      );
      expect(
        TeamNameValidator.validate('fastest.app'),
        'Team name cannot contain URLs or web links',
      );
    });

    test('rejects disallowed characters (emojis, punctuation, symbols)', () {
      expect(
        TeamNameValidator.validate('Runner 🏃 Team'),
        'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
      );
      expect(
        TeamNameValidator.validate('Fire Squad 🔥'),
        'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
      );
      expect(
        TeamNameValidator.validate('Go Team!'),
        'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
      );
      expect(
        TeamNameValidator.validate('Team @Home'),
        'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
      );
      expect(
        TeamNameValidator.validate('Team #1'),
        'Team name can only contain letters, numbers, spaces, hyphens, and underscores',
      );
    });

    test('rejects reserved words (case-insensitive and formatted)', () {
      expect(
        TeamNameValidator.validate('admin'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('ADMIN'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('  support  '),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('moderator'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('_official_'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('-staff-'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('System'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('null'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
      expect(
        TeamNameValidator.validate('undefined'),
        'Team name cannot be a reserved word (e.g., admin, support, official)',
      );
    });
  });

  group('TeamNameValidator - Sanitizer and Model Resilience', () {
    test('sanitize safely maps legacy invalid values to empty string', () {
      expect(TeamNameValidator.sanitize(null), '');
      expect(TeamNameValidator.sanitize(''), '');
      expect(TeamNameValidator.sanitize('   '), '');
      expect(TeamNameValidator.sanitize('<script>alert(1)</script>'), '');
      expect(TeamNameValidator.sanitize('<b>Hacker</b>'), '');
      expect(TeamNameValidator.sanitize('admin'), '');
      expect(TeamNameValidator.sanitize('_official_'), '');
      expect(TeamNameValidator.sanitize('http://scam.org'), '');
      expect(TeamNameValidator.sanitize('AB'), '');
      expect(TeamNameValidator.sanitize('1234567890123456789012345'), '');
      expect(TeamNameValidator.sanitize('Runner 🏃 Squad'), '');
      expect(TeamNameValidator.sanitize('Team\x00Bad'), '');
      expect(TeamNameValidator.sanitize('Team\nBad'), '');
      expect(TeamNameValidator.sanitize('Team\u200BBad'), '');
      expect(TeamNameValidator.sanitize('Team\u00A0Bad'), '');

      // Valid values are cleaned and returned
      expect(TeamNameValidator.sanitize('Cyber Vanguard'), 'Cyber Vanguard');
      expect(
        TeamNameValidator.sanitize('  Solaris    Nomads  '),
        'Solaris Nomads',
      );
      expect(TeamNameValidator.sanitize('team  a'), 'team a');
    });

    test(
      'FactionStanding.canonicalFaction never crashes on odd legacy values',
      () {
        expect(FactionStanding.canonicalFaction(null), '');
        expect(FactionStanding.canonicalFaction(''), '');
        expect(FactionStanding.canonicalFaction('   '), '');
        expect(
          FactionStanding.canonicalFaction('<script>alert("xss")</script>'),
          '',
        );
        expect(FactionStanding.canonicalFaction('admin'), '');
        expect(FactionStanding.canonicalFaction('Runner 🏃'), '');
        expect(FactionStanding.canonicalFaction('http://evil.com'), '');
        expect(
          FactionStanding.canonicalFaction('Solaris Nomads'),
          'Solaris Nomads',
        );
      },
    );

    test(
      'RunnerProfile with odd stored faction never crashes and displays safely',
      () {
        final profile = RunnerProfile(
          id: 'usr_test_odd',
          username: 'TestOddRunner',
          faction: '<script>evil()</script>',
        );

        // Raw may hold legacy value, but displayFaction sanitizes to empty
        expect(profile.displayFaction, '');
        expect(
          profile.displayFaction.isEmpty
              ? 'Independent'
              : profile.displayFaction,
          'Independent',
        );
      },
    );
  });
}
