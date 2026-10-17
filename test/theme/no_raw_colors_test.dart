import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No Color(0x or Colors.white outside lib/ui/theme (except designated migration list)', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Whitelist of legacy files scheduled for phased elimination across Phases 2-5.
    // Files that are modified or newly added in Phase 1 MUST NOT appear here.
    final allowedLegacyFiles = <String>{
      'lib/features/auth/auth_screen.dart',
      'lib/features/history/run_history_screen.dart',
      'lib/features/history/widgets/history_run_card.dart',
      'lib/features/history/widgets/run_share_card_modal.dart',
      'lib/features/home/home_screen.dart',
      'lib/features/home/widgets/home_header.dart',
      'lib/features/home/widgets/quick_launch_hero.dart',
      'lib/features/home/widgets/recent_activity_feed.dart',
      'lib/features/home/widgets/weekly_summary_card.dart',
      'lib/features/map/map_screen.dart',
      'lib/features/map/widgets/amoled_battery_saver_overlay.dart',
      'lib/features/map/widgets/claim_planner_sheet.dart',
      'lib/features/map/widgets/demo_controls.dart',
      'lib/features/map/widgets/hold_to_finish_button.dart',
      'lib/features/map/widgets/leaderboard_sheet.dart',
      'lib/features/map/widgets/loop_celebration_overlay.dart',
      'lib/features/map/widgets/map_layers.dart',
      'lib/features/map/widgets/mode_tabs.dart',
      'lib/features/map/widgets/pacer_sheet.dart',
      'lib/features/map/widgets/run_goal_sheet.dart',
      'lib/features/map/widgets/run_hud.dart',
      'lib/features/map/widgets/sos_beacon_sheet.dart',
      'lib/features/map/widgets/summary_sheet.dart',
      'lib/features/profile/widgets/achievements_list.dart',
      'lib/features/profile/widgets/auth_modal.dart',
      'lib/features/profile/widgets/challenges_shelf.dart',
      'lib/features/profile/widgets/emergency_contact_dialog.dart',
      'lib/features/profile/widgets/faction_leaderboard.dart',
      'lib/features/profile/widgets/offline_maps_sheet.dart',
      'lib/features/profile/widgets/privacy_zones_sheet.dart',
      'lib/features/profile/widgets/profile_dialogs.dart',
      'lib/features/profile/widgets/profile_hero.dart',
      'lib/features/profile/widgets/settings_list.dart',
      'lib/features/profile/widgets/stat_grid.dart',
      'lib/features/profile/widgets/weekly_league_view.dart',
      'lib/features/social/widgets/social_hub_sheet.dart',
      'lib/models/territory.dart',
      'lib/services/notification_service.dart',
      'lib/profile_page.dart',
      'lib/main.dart',
    };

    final violations = <String>[];

    for (final file in dartFiles) {
      final normalizedPath = file.path.replaceAll('\\', '/');

      // Skip theme directory itself
      if (normalizedPath.startsWith('lib/ui/theme/')) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNum = i + 1;

        if (line.contains('Colors.white') || line.contains('Color(0x')) {
          if (!allowedLegacyFiles.contains(normalizedPath)) {
            violations.add('$normalizedPath:$lineNum -> ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Raw Colors.white or Color(0x...) found in non-whitelisted files:\n${violations.join('\n')}',
    );
  });
}
