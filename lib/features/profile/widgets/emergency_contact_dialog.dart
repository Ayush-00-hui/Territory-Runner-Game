import 'package:flutter/material.dart';
import '../../../services/safety_service.dart';
import '../../../ui/ui.dart';

void showEmergencyContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const _EmergencyContactDialog(),
  );
}

class _EmergencyContactDialog extends StatefulWidget {
  const _EmergencyContactDialog();

  @override
  State<_EmergencyContactDialog> createState() => _EmergencyContactDialogState();
}

class _EmergencyContactDialogState extends State<_EmergencyContactDialog> {
  final SafetyService _safetyService = SafetyService();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _messageController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    await _safetyService.loadSettings();
    if (mounted) {
      setState(() {
        _nameController.text = _safetyService.contactName;
        _phoneController.text = _safetyService.contactPhone;
        _messageController.text = _safetyService.customMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    await _safetyService.saveSettings(
      name: _nameController.text,
      phone: _phoneController.text,
      message: _messageController.text,
    );
    if (mounted) {
      Navigator.of(context).pop();
      AppToast.show(context, 'Emergency contact settings updated');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        backgroundColor: AppColors.surface,
        content: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.br20,
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: AppSpacing.br10,
            ),
            child: const Icon(Icons.emergency_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: AppSpacing.s10),
          Text(
            'Emergency SOS Contact',
            style: AppText.headingSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a trusted contact to receive 1-tap distress SMS alerts with your real-time GPS coordinate link during runs:',
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Contact Name
            Text('Contact Name', style: AppText.labelSmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Partner, Mom, Roommate',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Contact Phone
            Text('Phone Number (with Country Code)', style: AppText.labelSmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. +1 555 123 4567',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // SOS Message template
            Text('Distress Message Preview', style: AppText.labelSmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        SecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(
          label: 'Save Settings',
          onPressed: _save,
        ),
      ],
    );
  }
}
