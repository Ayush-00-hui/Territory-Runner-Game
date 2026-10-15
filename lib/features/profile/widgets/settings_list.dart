import 'package:flutter/material.dart';
import '../../gameplay/territory_service.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';

class ProfileSettingsList extends StatelessWidget {
  final FirebaseService firebaseService;
  final TerritoryService territoryService;
  final VoidCallback onOpenAuth;

  const ProfileSettingsList({
    super.key,
    required this.firebaseService,
    required this.territoryService,
    required this.onOpenAuth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ProfileOptionTile(
            icon: Icons.cloud_done_rounded,
            title: firebaseService.isInitialized
                ? 'Cloud Connected (${firebaseService.currentUsername})'
                : 'Offline Local Storage (Tap to Sync)',
            onTap: onOpenAuth,
          ),
          const Divider(height: 1, color: AppColors.border),
          ProfileOptionTile(
            icon: Icons.refresh_rounded,
            title: 'Reset Local Territories (Dev Mode)',
            onTap: () async {
              await territoryService.resetTerritories();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Territories reset to initial grid.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const ProfileOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent, size: 22),
        title: Text(
          title,
          style: AppText.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
