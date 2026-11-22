import 'package:flutter/material.dart';

import '../../core/utils/constants.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'primary_button.dart';

/// Modal bottom sheet presenting verified map data sources, attributions, and license details.
Future<void> showMapAttributionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const MapAttributionSheet(),
  );
}

class MapAttributionSheet extends StatelessWidget {
  const MapAttributionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: AppSpacing.r24),
        border: Border(top: BorderSide(color: palette.border, width: 1.0)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        MediaQuery.paddingOf(context).bottom + AppSpacing.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.disabled,
                borderRadius: AppRadius.brFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Icon(Icons.map_outlined, color: palette.accent, size: 22),
              const SizedBox(width: AppSpacing.s10),
              Text(
                'Map Data & Attribution',
                style: AppText.titleMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // Primary Attribution
          Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: AppRadius.br16,
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cartographic Basemaps',
                  style: AppText.labelLarge.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  AppConstants.tileAttribution,
                  style: AppText.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s10),
                Text(
                  'Map data is provided by OpenStreetMap contributors under the Open Database License (ODbL). Basemap tile rendering and styling is provided by CARTO.',
                  style: AppText.caption.copyWith(
                    color: palette.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Fair Use Policy
          Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: AppRadius.br16,
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tile Usage & Fair Play',
                  style: AppText.labelLarge.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'Map tiles are cached locally on-device during active runs to minimize network traffic and battery consumption. Automated bulk scraping or scraping of external tiles is prohibited.',
                  style: AppText.caption.copyWith(
                    color: palette.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Dismiss Button
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
