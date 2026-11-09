import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

/// Dialog to send a friend request by Callsign or Runner ID.
void showAddFriendDialog(
  BuildContext context, {
  required ApiClient apiClient,
  required VoidCallback onAdded,
  String? currentCallsign,
}) {
  final controller = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.br20,
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.person_add_rounded,
              color: AppColors.accent,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              'Add Friend',
              style: AppText.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your friend\'s Callsign or Runner ID to send them a friend request:',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (_) {
                if (errorMessage != null) {
                  setDialogState(() => errorMessage = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Callsign or Runner ID',
                hintText: 'e.g. ApexRunner',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                errorText: errorMessage,
                errorMaxLines: 2,
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (currentCallsign != null && currentCallsign.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Your Callsign: $currentCallsign',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            isFullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          PrimaryButton(
            label: 'Add Friend',
            isFullWidth: false,
            isLoading: isLoading,
            onPressed: () async {
              final target = controller.text.trim();
              if (target.isEmpty) {
                setDialogState(
                  () => errorMessage = 'Please enter a Callsign or Runner ID',
                );
                return;
              }

              setDialogState(() {
                isLoading = true;
                errorMessage = null;
              });

              try {
                final ok = await apiClient.sendFriendRequest(target);
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                  AppToast.showGlobal(
                    'Friend request sent to $target!',
                    type: AppToastType.success,
                  );
                  onAdded();
                }
              } catch (e) {
                setDialogState(() {
                  isLoading = false;
                  if (e is ApiException) {
                    errorMessage = e.message;
                  } else {
                    errorMessage = e.toString().replaceFirst('Exception: ', '');
                  }
                });
              }
            },
          ),
        ],
      ),
    ),
  );
}
