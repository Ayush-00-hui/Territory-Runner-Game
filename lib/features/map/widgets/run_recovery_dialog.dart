import 'package:flutter/material.dart';

import '../../../services/run_recovery_service.dart';
import '../../../ui/ui.dart';

/// Modal dialog presented when an unfinished run session is detected on launch.
class RunRecoveryDialog extends StatelessWidget {
  final ActiveRunSnapshot snapshot;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const RunRecoveryDialog({
    super.key,
    required this.snapshot,
    required this.onResume,
    required this.onDiscard,
  });

  static Future<void> show(
    BuildContext context, {
    required ActiveRunSnapshot snapshot,
    required VoidCallback onResume,
    required VoidCallback onDiscard,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RunRecoveryDialog(
        snapshot: snapshot,
        onResume: () {
          Navigator.of(ctx).pop();
          onResume();
        },
        onDiscard: () {
          Navigator.of(ctx).pop();
          onDiscard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            'RESUME RUN?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'An interrupted run with ${snapshot.distanceKm.toStringAsFixed(2)} km recorded was recovered from local cache.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${snapshot.distanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${snapshot.coordinates.length} GPS Points',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDiscard,
          child: const Text(
            'Discard',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.bgDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: onResume,
          child: const Text(
            'Resume Session',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
