import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../../../services/sync_queue.dart';

/// Combined status chip displaying active GPS accuracy lock and cloud sync state.
/// Sits in the top-right corner of the map header.
class GpsSyncChip extends StatelessWidget {
  final double? accuracyMeters;
  final bool isGpsSearching;
  final SyncQueueService? syncQueue;

  const GpsSyncChip({
    super.key,
    this.accuracyMeters,
    this.isGpsSearching = false,
    this.syncQueue,
  });

  @override
  Widget build(BuildContext context) {
    final queue = syncQueue ?? SyncQueueService();

    // Determine GPS state
    Color gpsDotColor;
    String gpsLabel;
    if (isGpsSearching || accuracyMeters == null) {
      gpsDotColor = AppColors.warning;
      gpsLabel = 'Acquiring';
    } else if (accuracyMeters! <= 15.0) {
      gpsDotColor = AppColors.success;
      gpsLabel = '${accuracyMeters!.toStringAsFixed(0)}m';
    } else if (accuracyMeters! <= 35.0) {
      gpsDotColor = AppColors.warning;
      gpsLabel = '${accuracyMeters!.toStringAsFixed(0)}m';
    } else {
      gpsDotColor = AppColors.error;
      gpsLabel = 'Weak';
    }

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: queue.statusNotifier,
      builder: (context, syncStatus, _) {
        Color syncColor;
        IconData syncIcon;
        String syncDescription;

        switch (syncStatus) {
          case SyncStatus.synced:
            syncColor = AppColors.success;
            syncIcon = Icons.cloud_done_rounded;
            syncDescription = 'Synced to cloud';
            break;
          case SyncStatus.syncing:
            syncColor = AppColors.info;
            syncIcon = Icons.sync_rounded;
            syncDescription = 'Syncing...';
            break;
          case SyncStatus.pending:
            syncColor = AppColors.warning;
            syncIcon = Icons.cloud_upload_rounded;
            syncDescription = 'Runs pending sync';
            break;
          case SyncStatus.offline:
            syncColor = AppColors.textMuted;
            syncIcon = Icons.cloud_off_rounded;
            syncDescription = 'Offline';
            break;
        }

        return Semantics(
          button: true,
          label: 'Status: GPS $gpsLabel, Cloud $syncDescription',
          child: GestureDetector(
            onTap: () {
              AppMotion.selectionTick();
              final detail = accuracyMeters != null
                  ? 'GPS accuracy: ${accuracyMeters!.toStringAsFixed(1)} m • $syncDescription'
                  : 'GPS acquiring fix • $syncDescription';
              AppToast.show(
                context,
                detail,
                duration: const Duration(seconds: 2),
              );
              if (syncStatus == SyncStatus.offline ||
                  syncStatus == SyncStatus.pending) {
                queue.syncPendingRuns();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: AppRadius.brFull,
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                  boxShadow: AppElevation.floating,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // GPS status dot
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: gpsDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      gpsLabel,
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    // Divider
                    Container(
                      height: 12,
                      width: 1,
                      color: AppColors.borderSubtle,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    // Sync icon
                    Icon(syncIcon, color: syncColor, size: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
