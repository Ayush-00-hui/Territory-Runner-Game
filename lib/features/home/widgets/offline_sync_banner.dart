import 'package:flutter/material.dart';
import '../../../services/sync_queue.dart';
import '../../../ui/ui.dart';

class OfflineSyncBanner extends StatelessWidget {
  final SyncQueueService? syncQueueService;

  const OfflineSyncBanner({
    super.key,
    this.syncQueueService,
  });

  @override
  Widget build(BuildContext context) {
    final queue = syncQueueService ?? SyncQueueService();

    return ValueListenableBuilder<int>(
      valueListenable: queue.unsettledCountNotifier,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();

        return ValueListenableBuilder<SyncStatus>(
          valueListenable: queue.statusNotifier,
          builder: (context, status, _) {
            final isSyncing = status == SyncStatus.syncing;

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppSpacing.br16,
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSyncing ? Icons.sync_rounded : Icons.cloud_upload_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSyncing ? 'SYNCING RUNS...' : '$count PENDING CONQUEST RUN${count > 1 ? 'S' : ''}',
                          style: AppText.label.copyWith(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSyncing
                              ? 'Uploading GPS coordinates to server...'
                              : 'Waiting to sync with authority server.',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  if (isSyncing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warning,
                      ),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: AppSpacing.br10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        AppMotion.lightTick();
                        queue.syncPendingRuns();
                      },
                      child: Text(
                        'SYNC NOW',
                        style: AppText.label.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
