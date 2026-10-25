import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

/// Dialog to send a squad invite by Runner ID / Callsign.
void showAddFriendDialog(
  BuildContext context, {
  required ApiClient apiClient,
  required VoidCallback onAdded,
}) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br20),
      title: const Row(
        children: [
          Icon(Icons.person_add_rounded, color: AppColors.accent, size: 22),
          SizedBox(width: AppSpacing.s8),
          Text(
            'Add Squad Runner',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the runner ID or callsign of your friend to issue a squad invite:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: controller,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Runner ID / Callsign',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: AppSpacing.br12),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.br10),
          ),
          onPressed: () async {
            final target = controller.text.trim();
            if (target.isEmpty) return;
            Navigator.pop(ctx);
            try {
              final ok = await apiClient.sendFriendRequest(target);
              if (ok && context.mounted) {
                AppToast.show(
                  context,
                  'Squad invite sent to $target',
                  type: AppToastType.success,
                );
                onAdded();
              }
            } catch (e) {
              if (context.mounted) {
                AppToast.show(context, 'Failed: $e', type: AppToastType.error);
              }
            }
          },
          child: const Text(
            'Send invite',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
