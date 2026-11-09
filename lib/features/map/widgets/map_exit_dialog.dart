import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Shows the confirmation dialog when runner attempts to back out of an active run.
Future<bool> showExitRunConfirmation(BuildContext context) async {
  final bool? shouldExit = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br24,
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
      ),
      title: Text(
        'Pause or keep running?',
        style: AppText.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: Text(
        'Your run is currently active. Do you want to pause your run and exit, or keep running?',
        style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      actions: [
        SecondaryButton(
          label: 'Pause run',
          isFullWidth: false,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
        PrimaryButton(
          label: 'Keep running',
          icon: Icons.directions_run_rounded,
          isFullWidth: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
      ],
    ),
  );

  return shouldExit == true;
}
