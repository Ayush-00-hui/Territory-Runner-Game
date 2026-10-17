import 'package:flutter/material.dart';
import '../../services/sync_queue.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';
import 'app_toast.dart';

/// Reusable athletic sync status indicator chip wired to [SyncQueueService].
class SyncChip extends StatelessWidget {
  final SyncQueueService? syncQueueService;

  const SyncChip({super.key, this.syncQueueService});

  @override
  Widget build(BuildContext context) {
    final queue = syncQueueService ?? SyncQueueService();

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: queue.statusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<int>(
          valueListenable: queue.unsettledCountNotifier,
          builder: (context, count, _) {
            Color color;
            IconData icon;
            String text;

            switch (status) {
              case SyncStatus.synced:
                color = AppColors.success;
                icon = Icons.cloud_done_rounded;
                text = 'Synced';
                break;
              case SyncStatus.syncing:
                color = AppColors.info;
                icon = Icons.sync_rounded;
                text = 'Syncing';
                break;
              case SyncStatus.pending:
                color = AppColors.warning;
                icon = Icons.cloud_upload_rounded;
                text = count > 0 ? 'Pending ($count)' : 'Pending';
                break;
              case SyncStatus.offline:
                color = AppColors.textMuted;
                icon = Icons.cloud_off_rounded;
                text = count > 0 ? 'Offline ($count)' : 'Offline';
                break;
            }

            return Semantics(
              button: true,
              label: 'Cloud Sync: $text',
              child: GestureDetector(
                onTap: () {
                  AppMotion.selectionTick();
                  queue.syncPendingRuns();
                  AppToast.show(
                    context,
                    status == SyncStatus.synced
                        ? 'All runs synced with server authority.'
                        : 'Triggering background cloud sync...',
                    icon: icon,
                    type: status == SyncStatus.synced ? AppToastType.success : AppToastType.info,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brFull,
                    border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: AppSpacing.s6),
                      Text(
                        text,
                        style: AppText.labelSmall.copyWith(
                          color: color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
