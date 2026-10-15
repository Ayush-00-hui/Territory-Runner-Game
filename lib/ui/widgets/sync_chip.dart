import 'package:flutter/material.dart';
import '../../services/sync_queue.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

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
                color = AppColors.mine;
                icon = Icons.cloud_done_rounded;
                text = 'SYNCED';
                break;
              case SyncStatus.syncing:
                color = const Color(0xFF29B6F6);
                icon = Icons.sync_rounded;
                text = 'SYNCING';
                break;
              case SyncStatus.pending:
                color = AppColors.warning;
                icon = Icons.cloud_upload_rounded;
                text = count > 0 ? 'PENDING ($count)' : 'PENDING';
                break;
              case SyncStatus.offline:
                color = AppColors.rival;
                icon = Icons.cloud_off_rounded;
                text = count > 0 ? 'OFFLINE ($count)' : 'OFFLINE';
                break;
            }

            return GestureDetector(
              onTap: () {
                AppMotion.lightTick();
                queue.syncPendingRuns();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    duration: const Duration(seconds: 2),
                    content: Text(
                      status == SyncStatus.synced
                          ? 'All runs synced with server authority.'
                          : 'Triggering background cloud sync...',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.fast),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.brFull,
                  border: Border.all(color: color.withValues(alpha: 0.6), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      text,
                      style: AppText.label.copyWith(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
