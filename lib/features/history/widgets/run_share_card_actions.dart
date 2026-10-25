import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Row and button controls for exporting/saving run share cards.
class RunShareCardActions extends StatelessWidget {
  final bool isExporting;
  final VoidCallback? onShareCard;
  final VoidCallback? onSaveToGallery;
  final VoidCallback onExportGpx;
  final VoidCallback onExportGeoJson;
  final VoidCallback onExportMlTrace;

  const RunShareCardActions({
    super.key,
    required this.isExporting,
    required this.onShareCard,
    required this.onSaveToGallery,
    required this.onExportGpx,
    required this.onExportGeoJson,
    required this.onExportMlTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: PrimaryButton(
                label: isExporting ? 'Generating 1080p...' : 'Share card',
                icon: Icons.share_rounded,
                onPressed: isExporting ? null : onShareCard,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    'Save to gallery',
                    style: AppText.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: isExporting ? null : onSaveToGallery,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.file_download_outlined,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  label: const Text(
                    'Export GPX',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: onExportGpx,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br12,
                    ),
                  ),
                  icon: const Icon(
                    Icons.polyline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  label: const Text(
                    'Export GeoJSON',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: onExportGeoJson,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.br12,
              ),
            ),
            icon: const Icon(
              Icons.analytics_outlined,
              size: 16,
              color: AppColors.accent,
            ),
            label: const Text(
              'Export ML Debug Trace (JSON)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            onPressed: onExportMlTrace,
          ),
        ),
      ],
    );
  }
}
