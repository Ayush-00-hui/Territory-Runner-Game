import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/faction_standing.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/profile/widgets/profile_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C2 Teams User-Created & Honest State Tests', () {
    test('FactionStanding.canonicalFaction has no hardcoded default team or legacy aliases', () {
      expect(FactionStanding.canonicalFaction(null), '');
      expect(FactionStanding.canonicalFaction(''), '');
      expect(FactionStanding.canonicalFaction('  '), '');

      // Persisted strings preserved without crashing
      expect(FactionStanding.canonicalFaction('Cyber Vanguard'), 'Cyber Vanguard');
      expect(FactionStanding.canonicalFaction('Iron Syndicate'), 'Iron Syndicate');
      expect(FactionStanding.canonicalFaction('Neon Nomads'), 'Neon Nomads');
      expect(FactionStanding.canonicalFaction('Morning Striders'), 'Morning Striders');
    });

    test('RunnerProfile defaults to empty team and Rookie Runner badge', () {
      final profile = RunnerProfile(id: 'usr_new', username: 'NewRunner');
      expect(profile.faction, '');
      expect(profile.displayFaction, '');
      expect(profile.badges, ['Rookie Runner']);

      // Legacy Cyber Rookie badge migrates to Rookie Runner
      final legacy = RunnerProfile.fromJson({
        'id': 'usr_legacy',
        'username': 'OldRunner',
        'badges': ['Cyber Rookie'],
      });
      expect(legacy.badges.contains('Rookie Runner'), isTrue);
      expect(legacy.hasBadge('Rookie Runner'), isTrue);
    });

    testWidgets('TeamSelectionSheet renders calm empty state and allows custom team creation', (tester) async {
      final profile = RunnerProfile(id: 'usr_test', username: 'Tester', faction: '');
      final territoryService = TerritoryService();

      bool wasUpdated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeamSelectionSheet(
              profile: profile,
              territoryService: territoryService,
              onUpdated: () {
                wasUpdated = true;
              },
            ),
          ),
        ),
      );

      // Wait for future to settle (empty server response fallback)
      await tester.pumpAndSettle();

      // Verify calm empty state is shown
      expect(find.textContaining('No teams currently active'), findsOneWidget);

      // Verify custom team input is present
      expect(find.text('Create or enter team name:'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Enter a user-created team name
      await tester.enterText(find.byType(TextField), 'Harbor Striders');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.faction, 'Harbor Striders');
      expect(wasUpdated, isTrue);
    });
  });
}

