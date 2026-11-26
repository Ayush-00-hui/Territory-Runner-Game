import 'package:flutter/material.dart';

import '../../../services/app_preferences.dart';
import '../../../ui/ui.dart';

/// Modal bottom sheet allowing runners to configure persisted map overlay layers:
/// - Claimed territory polygons
/// - Explored 100 m fog-of-war blocks
/// - Nearby rival runners and live breadcrumbs
/// - High-contrast outdoor layer
class MapLayersSheet extends StatefulWidget {
  final VoidCallback? onStyleChanged;
  final VoidCallback? onLocateNearestRival;

  const MapLayersSheet({
    super.key,
    this.onStyleChanged,
    this.onLocateNearestRival,
  });

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onStyleChanged,
    VoidCallback? onLocateNearestRival,
  }) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => MapLayersSheet(
        onStyleChanged: onStyleChanged,
        onLocateNearestRival: onLocateNearestRival,
      ),
    );
  }

  @override
  State<MapLayersSheet> createState() => _MapLayersSheetState();
}

class _MapLayersSheetState extends State<MapLayersSheet> {
  final AppPreferences _prefs = AppPreferences();
  late bool _showTerritories;
  late bool _showExploredGrid;
  late bool _showRivals;
  late bool _highContrast;

  @override
  void initState() {
    super.initState();
    _showTerritories = _prefs.showTerritoriesLayer;
    _showExploredGrid = _prefs.showExploredGridLayer;
    _showRivals = _prefs.showRivalsLayer;
    _highContrast = _prefs.highContrastMapLayer;
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Map layers',
      subtitle: 'Configure visible map overlays and display style',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Territories Layer
          _LayerToggleTile(
            icon: Icons.layers_rounded,
            title: 'Territories',
            subtitle: 'Render claimed polygons and team areas',
            value: _showTerritories,
            onChanged: (val) {
              setState(() => _showTerritories = val);
              _prefs.setMapLayerVisibility(showTerritories: val);
              widget.onStyleChanged?.call();
            },
          ),
          const SizedBox(height: AppSpacing.s8),

          // 2. Explored City Blocks Fog-of-War Overlay
          _LayerToggleTile(
            icon: Icons.grid_on_rounded,
            title: 'Explored city blocks',
            subtitle: 'Highlight 100 m blocks uncovered on foot',
            value: _showExploredGrid,
            onChanged: (val) {
              setState(() => _showExploredGrid = val);
              _prefs.setMapLayerVisibility(showExploredGrid: val);
              widget.onStyleChanged?.call();
            },
          ),
          const SizedBox(height: AppSpacing.s8),

          // 3. Rival Presence Layer
          _LayerToggleTile(
            icon: Icons.radar_rounded,
            title: 'Nearby runners',
            subtitle: 'Display live movement of nearby runners',
            value: _showRivals,
            onChanged: (val) {
              setState(() => _showRivals = val);
              _prefs.setMapLayerVisibility(showRivals: val);
              widget.onStyleChanged?.call();
            },
          ),
          const SizedBox(height: AppSpacing.s8),

          // 4. High Contrast Outdoor Mode
          _LayerToggleTile(
            icon: Icons.wb_sunny_rounded,
            title: 'High-contrast outdoor mode',
            subtitle: 'Boost tile contrast and linework for bright sunlight',
            value: _highContrast,
            onChanged: (val) {
              setState(() => _highContrast = val);
              _prefs.setMapLayerVisibility(highContrast: val);
              widget.onStyleChanged?.call();
            },
          ),
          if (widget.onLocateNearestRival != null) ...[
            const SizedBox(height: AppSpacing.s12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onLocateNearestRival!();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br12,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.rival.withValues(alpha: 0.15),
                        borderRadius: AppRadius.br8,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location_rounded,
                          color: AppColors.rival,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pan to nearest runner',
                            style: AppText.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Focus map camera on closest active rival',
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LayerToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LayerToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: value ? AppColors.accent : AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentContainer,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
