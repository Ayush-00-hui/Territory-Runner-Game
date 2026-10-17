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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Emergency contact settings updated! 🛡️', style: TextStyle(color: AppColors.accent)),
        ),
      );
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
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.br24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: AppSpacing.br10,
            ),
            child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: AppSpacing.s10),
          Text(
            'Emergency SOS Contact',
            style: AppText.headingSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
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
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.3),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Contact Name
            Text('CONTACT NAME', style: AppText.label.copyWith(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Partner, Mom, Roommate',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgDeep,
                border: OutlineInputBorder(borderRadius: AppSpacing.br12, borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Contact Phone
            Text('PHONE NUMBER (WITH COUNTRY CODE)', style: AppText.label.copyWith(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. +1 555 123 4567',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgDeep,
                border: OutlineInputBorder(borderRadius: AppSpacing.br12, borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // SOS Message template
            Text('DISTRESS MESSAGE PREVIEW', style: AppText.label.copyWith(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgDeep,
                border: OutlineInputBorder(borderRadius: AppSpacing.br12, borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.br12),
          ),
          onPressed: _save,
          child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}
