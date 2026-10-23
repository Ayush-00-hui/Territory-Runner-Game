import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/features/gameplay/territory_service.dart';
import 'package:territory_runner/features/map/widgets/run_goal_sheet.dart';
import 'package:territory_runner/features/profile/widgets/challenges_shelf.dart';
import 'package:territory_runner/features/profile/widgets/stat_grid.dart';
import 'package:territory_runner/models/run_goal.dart';
import 'package:territory_runner/models/runner_profile.dart';
import 'package:territory_runner/ui/widgets/permission_primer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Banned Words & Calm Tone Audit', () {
    final bannedWords = [
      'telemetry',
      'sector',
      'sectors',
      'cyber',
      'tactical',
      'conquer',
      'conquered',
      'conquering',
      'conquest',
      'conquests',
      'sovereign',
    ];
    final bannedRegex = RegExp(
      '\\b(${bannedWords.join('|')})\\b',
      caseSensitive: false,
    );

    // Persisted or raw backwards-compatibility keys that are explicitly permitted
    // in internal migration tables or backward compatibility code.
    final allowedRawSubstrings = [
      'Cyber Vanguard', // Raw DB/Hive faction value
      'Territory Sovereign', // Raw badge alias key
      'First Conquest', // Raw badge alias key
      'Sector Commander', // Raw badge alias key
      'Hex Grid Overlord', // Raw badge alias key
      'Cyber Rookie', // Raw badge alias key
      "'cyber'", // Internal faction color lookup key
      '"cyber"', // Internal faction color lookup key
    ];

    test('lib/ directory contains zero banned jargon in user-visible strings', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final stringLiteralRegex = RegExp(r'''(["'])(?:(?=(\\?))\2.)*?\1''');
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();
            // Skip comments
            if (trimmed.startsWith('//') ||
                trimmed.startsWith('///') ||
                trimmed.startsWith('*')) {
              continue;
            }

            for (final match in stringLiteralRegex.allMatches(line)) {
              final literal = match.group(0)!;
              if (bannedRegex.hasMatch(literal)) {
                // Check if it is an allowed raw key
                final isAllowed = allowedRawSubstrings.any((allowed) => literal.contains(allowed));
                if (!isAllowed) {
                  violations.add('${entity.path}:${i + 1} -> $literal');
                }
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found banned words in user-visible strings:\n${violations.join('\n')}',
      );
    });

    testWidgets('PermissionPrimerSheet renders calm text without banned words or ALL-CAPS alerts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionPrimerSheet(
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        final content = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(
          bannedRegex.hasMatch(content),
          isFalse,
          reason: 'PermissionPrimerSheet contains banned jargon: "$content"',
        );
        // Assert no emoji or shouting ALL-CAPS alert headlines
        expect(
          content.contains('🚨') || content.contains('⚠️') || content.contains('TACTICAL'),
          isFalse,
          reason: 'Alert text should be calm, not shouting: "$content"',
        );
      }
    });

    testWidgets('ChallengesShelf renders calm sports terminology',
        (WidgetTester tester) async {
      final profile = RunnerProfile(
        id: 'test_p',
        username: 'Runner1',
        badges: ['Territory Master', 'First Claim'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengesShelf(
                profile: profile,
                territoriesCount: 5,
                totalAreaSqMeters: 50000.0,
              ),
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        final content = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(
          bannedRegex.hasMatch(content),
          isFalse,
          reason: 'ChallengesShelf contains banned jargon: "$content"',
        );
      }
    });

    testWidgets('ProfileStatGrid renders calm metrics without sector/telemetry jargon',
        (WidgetTester tester) async {
      final profile = RunnerProfile(
        id: 'test_p2',
        username: 'Runner2',
        totalHexesClaimed: 42,
        totalDistanceKm: 120.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileStatGrid(
                profile: profile,
                territoryService: TerritoryService(),
              ),
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        final content = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(
          bannedRegex.hasMatch(content),
          isFalse,
          reason: 'ProfileStatGrid contains banned jargon: "$content"',
        );
      }
    });

    testWidgets('RunGoalSheet renders calm area and distance goals',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RunGoalSheet(
              currentGoal: RunGoal.none,
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        final content = text.data ?? text.textSpan?.toPlainText() ?? '';
        expect(
          bannedRegex.hasMatch(content),
          isFalse,
          reason: 'RunGoalSheet contains banned jargon: "$content"',
        );
      }
    });
  });
}
