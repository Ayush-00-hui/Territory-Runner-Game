import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

/// Displays a modal sheet to report a user or inappropriate run activity.
Future<void> showReportDialog(
  BuildContext context, {
  required String userId,
  String? runId,
  ApiClient? apiClient,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) =>
        ReportDialog(userId: userId, runId: runId, apiClient: apiClient),
  );
}

class ReportDialog extends StatefulWidget {
  final String userId;
  final String? runId;
  final ApiClient? apiClient;

  const ReportDialog({
    super.key,
    required this.userId,
    this.runId,
    this.apiClient,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const List<String> _reasons = [
    'Harassment or bullying',
    'Inappropriate route shape',
    'Suspected vehicular cheat or fake GPS',
    'Spam or advertising',
    'Other conduct violation',
  ];

  String _selectedReason = _reasons.first;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    final client = widget.apiClient ?? ApiClient();
    try {
      final success = await client.reportContent(
        reportedUserId: widget.userId,
        runId: widget.runId,
        reason: _selectedReason,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (success) {
        AppToast.show(context, 'Report submitted for review. Thank you.');
      } else {
        AppToast.show(context, 'Failed to submit report. Please retry.');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(context, 'Network error. Please try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Activity',
                style: AppText.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Help keep our athletic community safe and fair. Reports are reviewed privately.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Reason',
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedReason,
                    dropdownColor: AppColors.surface,
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    items: _reasons.map((r) {
                      return DropdownMenuItem<String>(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedReason = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Additional details (optional)',
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                style: AppText.bodySmall.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  hintStyle: AppText.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.br8,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.br8,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.br8,
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.br8,
                      ),
                      minimumSize: const Size(100, 48),
                    ),
                    onPressed: _isSubmitting ? null : _submitReport,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : Text(
                            'Submit report',
                            style: AppText.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onAccent,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
