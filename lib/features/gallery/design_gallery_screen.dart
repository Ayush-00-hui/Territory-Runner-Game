import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../ui/ui.dart';

/// Debug-only Design Gallery showcasing all Graphite + Bone + Moss design tokens,
/// typography styles, and component states.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  int _selectedChipIndex = 0;
  bool _isButtonLoading = false;
  double _progressVal = 0.68;
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: Center(child: Text('Debug Mode Only')));
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Design System Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s20,
        ),
        children: [
          // 1. Color Palette
          const SectionHeader(
            title: 'Graphite + Bone + Moss Palette',
            overline: 'COLOR SYSTEM',
            subtitle: 'Calm, minimal, human-designed athletic tokens',
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildColorGrid([
            _ColorSwatch('bgDeep', AppColors.bgDeep, '#0D0E0C'),
            _ColorSwatch('bgElevated', AppColors.bgElevated, '#11120F'),
            _ColorSwatch('surface', AppColors.surface, '#141512'),
            _ColorSwatch('surface2', AppColors.surface2, '#1B1C18'),
            _ColorSwatch('border', AppColors.border, '#2A2B26'),
            _ColorSwatch('accent (mine)', AppColors.accent, '#A3C586'),
            _ColorSwatch('rival', AppColors.rival, '#86A5D3'),
            _ColorSwatch('warning', AppColors.warning, '#D9A441'),
            _ColorSwatch('error', AppColors.error, '#E0716B'),
            _ColorSwatch('success', AppColors.success, '#A3C586'),
            _ColorSwatch('info', AppColors.info, '#94A3B8'),
            _ColorSwatch('gold', AppColors.gold, '#CDAE6A'),
            _ColorSwatch('silver', AppColors.silver, '#B5B6B0'),
            _ColorSwatch('bronze', AppColors.bronze, '#B0825A'),
          ]),

          const SizedBox(height: AppSpacing.s24),

          // 2. Typography Scale
          const SectionHeader(
            title: 'Typography & Tabular Readouts',
            overline: 'TYPE SCALE',
            subtitle:
                'Inter w600-w700 with tabular figures and negative tracking',
          ),
          const SizedBox(height: AppSpacing.s8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('displayLarge (44sp)', style: AppText.labelSmall),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('14.85', style: AppText.displayLarge),
                    const SizedBox(width: AppSpacing.s6),
                    Text('KM', style: AppText.statUnit.copyWith(fontSize: 16)),
                  ],
                ),
                const Divider(height: AppSpacing.s24),
                const Text('displayMedium (36sp)', style: AppText.labelSmall),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('01:14:28', style: AppText.displayMedium),
                    const SizedBox(width: AppSpacing.s6),
                    Text('Moving', style: AppText.statUnit),
                  ],
                ),
                const Divider(height: AppSpacing.s24),
                const Text('displaySmall (28sp)', style: AppText.labelSmall),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('4:58', style: AppText.displaySmall),
                    const SizedBox(width: AppSpacing.s6),
                    Text('/KM', style: AppText.statUnit),
                  ],
                ),
                const Divider(height: AppSpacing.s24),
                const Text(
                  'titleLarge / titleMedium / bodyMedium',
                  style: AppText.labelSmall,
                ),
                const SizedBox(height: AppSpacing.s4),
                const Text('Territory 04-A Active', style: AppText.titleLarge),
                const SizedBox(height: AppSpacing.s4),
                const Text(
                  'Territory Claim Completed',
                  style: AppText.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s4),
                const Text(
                  'Your GPS tracking has sealed the perimeter with 99.4% precision accuracy.',
                  style: AppText.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s24),

          // 3. Buttons & States
          const SectionHeader(
            title: 'Interactive Buttons',
            overline: 'COMPONENTS',
            subtitle: 'Ember primary and surface secondary buttons with 0.97 press scale',
          ),
          const SizedBox(height: AppSpacing.s8),
          PrimaryButton(
            label: 'Start Run',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              AppToast.show(
                context,
                'Primary Button Triggered',
                type: AppToastType.success,
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'View Division Standings',
            icon: Icons.leaderboard_rounded,
            onPressed: () {
              AppToast.show(
                context,
                'Secondary Button Triggered',
                type: AppToastType.info,
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _isButtonLoading ? 'Loading' : 'Toggle Spinner',
                  isLoading: _isButtonLoading,
                  onPressed: () {
                    setState(() => _isButtonLoading = !_isButtonLoading);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              const Expanded(
                child: PrimaryButton(label: 'Disabled', onPressed: null),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s24),

          // 4. Chips & Status
          const SectionHeader(
            title: 'Chips & Status Badges',
            overline: 'SELECTORS',
            subtitle:
                'Clean subtle fills, hairline borders, no colored shadows',
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              AppChip(
                label: 'All Runs',
                isSelected: _selectedChipIndex == 0,
                onTap: () => setState(() => _selectedChipIndex = 0),
              ),
              AppChip(
                label: 'This Week',
                isSelected: _selectedChipIndex == 1,
                onTap: () => setState(() => _selectedChipIndex = 1),
              ),
              AppChip(
                label: 'This Month',
                isSelected: _selectedChipIndex == 2,
                onTap: () => setState(() => _selectedChipIndex = 2),
              ),
              NeutralChip(
                label: 'Neutral chip',
                onTap: () {},
              ),
              const CombinedStatusIndicator(
                isGpsSearching: false,
                accuracyMeters: 4.8,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s24),

          // 5. Stat Tiles & Progress Ring
          const SectionHeader(
            title: 'Stats & Progress',
            overline: 'ATHLETIC DATA',
            subtitle: 'Animated count-ups and circular progress rings',
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total Distance',
                  numericValue: 42.8,
                  unit: 'KM',
                  precision: 1,
                  delta: '+12% this week',
                  icon: Icons.directions_run_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: StatTile(
                  label: 'Territory',
                  numericValue: 124800,
                  unit: 'SQM',
                  icon: Icons.layers_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Row(
              children: [
                ProgressRing(
                  progress: _progressVal,
                  size: 72,
                  strokeWidth: 7,
                  center: Text(
                    '${(_progressVal * 100).round()}%',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Territory Goal',
                        style: AppText.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      const Text(
                        '3.4 / 5.0 km completed today',
                        style: AppText.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      GestureDetector(
                        onTap: () => setState(
                          () => _progressVal = (_progressVal >= 1.0)
                              ? 0.3
                              : _progressVal + 0.2,
                        ),
                        child: Text(
                          'Simulate Progress',
                          style: AppText.labelLarge.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s24),

          // 6. Toast, Sheets & Dialogs
          const SectionHeader(
            title: 'Modals, Sheets & Toasts',
            overline: 'OVERLAYS',
            subtitle:
                'Unified squircle dialogs, bottom sheets, and floating toasts',
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              SecondaryButton(
                label: 'Show Toast',
                isFullWidth: false,
                icon: Icons.notifications_active_rounded,
                onPressed: () {
                  AppToast.show(
                    context,
                    'Territory claimed! +450 XP awarded.',
                    type: AppToastType.success,
                  );
                },
              ),
              SecondaryButton(
                label: 'Show Sheet',
                isFullWidth: false,
                icon: Icons.vertical_align_top_rounded,
                onPressed: () {
                  AppSheet.show(
                    context: context,
                    builder: (ctx) => AppSheet(
                      title: 'Route Planner',
                      subtitle: 'Choose planned territory loop',
                      child: Column(
                        children: [
                          const StatTile(
                            label: 'Projected Route',
                            stringValue: 'Park Loop',
                            unit: 'PRESET',
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          PrimaryButton(
                            label: 'Confirm Route',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SecondaryButton(
                label: 'Confirm Dialog',
                isFullWidth: false,
                icon: Icons.help_outline_rounded,
                onPressed: () async {
                  final confirmed = await AppDialog.showConfirmation(
                    context: context,
                    title: 'Discard In-Progress Run?',
                    message: 'Your route coordinates and loop closure will be deleted permanently.',
                    confirmLabel: 'Discard Run',
                    cancelLabel: 'Keep Running',
                    isDestructive: true,
                  );
                  if (context.mounted && confirmed == true) {
                    AppToast.show(
                      context,
                      'Run discarded',
                      type: AppToastType.error,
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s24),

          // 7. Error & Empty States
          const SectionHeader(
            title: 'Empty & Error States',
            overline: 'FALLBACKS',
            subtitle: 'Consistent feedback containers',
          ),
          const SizedBox(height: AppSpacing.s8),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: ErrorState(
              title: 'GPS Signal Lost',
              message: 'Check outdoor line of sight or location permissions to continue.',
              onRetry: () {
                AppToast.show(
                  context,
                  'Retrying GPS acquisition...',
                  type: AppToastType.info,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // 8. Territory Art & Hero Card
          const SectionHeader(
            title: 'Territory Art & Hero Card',
            overline: 'OFFLINE VECTOR ART',
            subtitle: 'Flat polygon silhouettes with contour motifs and count-up',
          ),
          const SizedBox(height: AppSpacing.s8),
          TerritoryHeroCard(
            territories: const [],
            totalAreaSqm: 142500,
            weeklyGainedAreaSqm: 12400,
            onStartRun: () {
              AppToast.show(
                context,
                'Start run triggered from gallery',
                type: AppToastType.info,
              );
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          const TerritoryArt(
            polygons: [
              [
                LatLng(37.7749, -122.4194),
                LatLng(37.7799, -122.4194),
                LatLng(37.7799, -122.4144),
                LatLng(37.7749, -122.4144),
              ],
            ],
            totalAreaSqm: 38200,
            subtitle: 'Mission District Loop',
            height: 180,
          ),

          const SizedBox(height: AppSpacing.s24),

          // 9. Premium Bottom Navigation
          const SectionHeader(
            title: 'Premium Bottom Navigation',
            overline: 'PRIMARY NAVIGATION',
            subtitle: '5 destinations with prominent circular Run action',
          ),
          const SizedBox(height: AppSpacing.s8),
          ClipRRect(
            borderRadius: AppRadius.br12,
            child: PremiumBottomNav(
              selectedIndex: _bottomNavIndex,
              onTabSelected: (i) => setState(() => _bottomNavIndex = i),
              onStartRun: () {
                AppToast.show(
                  context,
                  'Run button tapped',
                  type: AppToastType.info,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
        ],
      ),
    );
  }

  Widget _buildColorGrid(List<_ColorSwatch> swatches) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: swatches.map((s) {
        return Container(
          width: 104,
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br12,
            border: Border.all(color: AppColors.borderSubtle, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                s.name,
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  letterSpacing: 0.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(s.hex, style: AppText.caption.copyWith(fontSize: 9)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ColorSwatch {
  final String name;
  final Color color;
  final String hex;

  const _ColorSwatch(this.name, this.color, this.hex);
}
