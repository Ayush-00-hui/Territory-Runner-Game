import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design System Token Enforcement Linter Tests', () {
    test('No new hard-coded fontSize declarations outside lib/ui/theme', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final fontSizeRegex = RegExp(r'fontSize\s*:\s*\d+(\.\d+)?');

      // Baseline allowance map for legacy files.
      // As files are refactored to use AppText tokens, their baseline counts must be decreased,
      // and NO new files or increased counts are permitted.
      final Map<String, int> baselineAllowances = {
        'lib/features/profile/widgets/settings_list.dart': 0,
        'lib/features/profile/widgets/season_crew_view.dart': 26,
        'lib/features/profile/widgets/profile_dialogs.dart': 19,
        'lib/features/profile/widgets/faction_leaderboard.dart': 16,
        'lib/features/auth/auth_screen.dart': 14,
        'lib/features/social/widgets/social_duels_tab.dart': 13,
        'lib/features/map/widgets/run_goal_sheet.dart': 12,
        'lib/features/profile/widgets/weekly_league_view.dart': 12,
        'lib/features/history/widgets/history_run_card.dart': 0,
        'lib/features/history/widgets/run_share_card_renderer.dart': 11,
        'lib/features/map/widgets/amoled_battery_saver_overlay.dart': 11,
        'lib/features/profile/widgets/auth_modal.dart': 11,
        'lib/features/profile/widgets/offline_maps_sheet.dart': 11,
        'lib/features/profile/widgets/privacy_zones_sheet.dart': 0,
        'lib/features/social/widgets/social_squad_tab.dart': 11,
        'lib/features/profile/widgets/challenges_shelf.dart': 0,
        'lib/features/history/run_history_screen.dart': 0,
        'lib/features/history/widgets/splits_table.dart': 9,
        'lib/features/map/widgets/claim_planner_sheet.dart': 9,
        'lib/features/map/widgets/summary_sheet.dart': 0,
        'lib/features/profile/widgets/emergency_contact_dialog.dart': 7,
        'lib/features/social/widgets/social_duel_creator_sheet.dart': 7,
        'lib/ui/widgets/permission_primer_sheet.dart': 7,
        'lib/features/history/widgets/run_share_card_preview.dart': 6,
        'lib/features/map/widgets/run_hud_expanded_drawer.dart': 6,
        'lib/features/map/widgets/run_hud_metrics_card.dart': 0,
        'lib/features/map/widgets/run_recovery_dialog.dart': 6,
        'lib/features/map/widgets/sos_beacon_sheet.dart': 6,
        'lib/features/onboarding/onboarding_screen.dart': 6,
        'lib/features/map/widgets/summary_coach_card.dart': 5,
        'lib/features/map/widgets/summary_stats_grid.dart': 5,
        'lib/ui/widgets/calm_error_screen.dart': 5,
        'lib/profile_page.dart': 0,
        'lib/features/history/widgets/run_share_card_actions.dart': 4,
        'lib/features/map/widgets/run_hud_closure_bar.dart': 4,
        'lib/features/map/widgets/summary_victory_header.dart': 4,
        'lib/features/profile/widgets/profile_hero.dart': 0,
        'lib/features/gallery/design_gallery_screen.dart': 3,
        'lib/features/history/widgets/elevation_profile_chart.dart': 3,
        'lib/features/home/widgets/needs_defending_row.dart': 3,
        'lib/features/map/widgets/ghost_runner_picker_sheet.dart': 3,
        'lib/features/map/widgets/interval_workout_picker_sheet.dart': 3,
        'lib/features/map/widgets/map_layers.dart': 3,
        'lib/features/map/widgets/run_countdown_overlay.dart': 3,
        'lib/features/map/widgets/run_hud.dart': 3,
        'lib/ui/widgets/app_intro_animation.dart': 0,
        'lib/features/history/widgets/run_share_card_export_dialog.dart': 2,
        'lib/features/map/widgets/demo_controls.dart': 2,
        'lib/features/map/widgets/hold_to_finish_button.dart': 2,
        'lib/features/map/widgets/interval_workout_banner.dart': 2,
        'lib/features/map/widgets/loop_celebration_overlay.dart': 2,
        'lib/features/map/widgets/map_layers_sheet.dart': 2,
        'lib/features/map/widgets/summary_route_replay.dart': 2,
        'lib/features/profile/widgets/achievements_list.dart': 2,
        'lib/features/profile/widgets/stat_grid.dart': 2,
        'lib/features/social/widgets/social_add_friend_dialog.dart': 2,
        'lib/features/social/widgets/social_hub_header.dart': 2,
        'lib/features/social/widgets/social_hub_sheet.dart': 2,
        'lib/features/history/widgets/run_share_card_modal.dart': 1,
        'lib/features/history/widgets/run_share_card_theme_selector.dart': 1,
        'lib/features/home/widgets/gps_status_chip.dart': 1,
        'lib/features/home/widgets/recent_activity_feed.dart': 1,
        'lib/features/home/widgets/weekly_summary_card.dart': 1,
        'lib/features/map/widgets/gps_sync_chip.dart': 1,
        'lib/features/map/widgets/leaderboard_sheet.dart': 1,
        'lib/features/map/widgets/map_rival_layer.dart': 1,
        'lib/features/map/widgets/map_tools_sheet.dart': 1,
        'lib/features/map/widgets/run_hud_controls_bar.dart': 1,
        'lib/features/map/widgets/sos_shield_button.dart': 1,
        'lib/features/profile/widgets/body_details_sheet.dart': 1,
        'lib/features/profile/widgets/calorie_factors_sheet.dart': 1,
        'lib/ui/widgets/combined_status_indicator.dart': 1,
        'lib/ui/widgets/premium_bottom_nav.dart': 1,
      };

      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final normalizedPath = entity.path.replaceAll('\\', '/');
        // Exclude design system token definitions themselves
        if (normalizedPath.startsWith('lib/ui/theme/')) continue;

        final content = entity.readAsStringSync();
        final matchCount = fontSizeRegex.allMatches(content).length;

        if (matchCount > 0) {
          final allowedCount = baselineAllowances[normalizedPath] ?? 0;
          if (matchCount > allowedCount) {
            violations.add(
              '$normalizedPath: found $matchCount hardcoded fontSize (allowed: $allowedCount)',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'New hardcoded fontSize declarations detected outside lib/ui/theme:\n'
            '${violations.join('\n')}\n'
            'Use AppText tokens (e.g. AppText.titleSmall, AppText.bodyMedium) instead of raw font sizes.',
      );
    });
  });
}
