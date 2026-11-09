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
              child: SecondaryButton(
                label: 'Save to gallery',
                icon: Icons.photo_library_outlined,
                height: 48,
                onPressed: isExporting ? null : onSaveToGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Export GPX',
                icon: Icons.file_download_outlined,
                height: 48,
                onPressed: onExportGpx,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: SecondaryButton(
                label: 'Export GeoJSON',
                icon: Icons.polyline_rounded,
                height: 48,
                onPressed: onExportGeoJson,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        SecondaryButton(
          label: 'Export ML Debug Trace (JSON)',
          icon: Icons.analytics_outlined,
          height: 48,
          onPressed: onExportMlTrace,
        ),
      ],
    );
  }
}
