import 'package:flutter/material.dart';

import '../../../profile_page.dart';
import '../../../ui/ui.dart';
import 'gps_sync_chip.dart';

/// Minimal Athletic Top Bar: Avatar (opens Profile) + Faction chip (left), GpsSyncChip (right)
class MapTopBar extends StatelessWidget {
  final String athleteName;
  final double? satelliteAccuracyMeters;
  final bool isGpsSearching;

  const MapTopBar({
    super.key,
    required this.athleteName,
    required this.satelliteAccuracyMeters,
    required this.isGpsSearching,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Runner profile for $athleteName. Tap to view profile.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppMotion.selectionTick();
                  Navigator.push(
                    context,
                    AppMotion.pageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                },
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceGlass,
                    child: Text(
                      athleteName.isNotEmpty
                          ? athleteName[0].toUpperCase()
                          : 'R',
                      style: AppText.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        GpsSyncChip(
          accuracyMeters: satelliteAccuracyMeters,
          isGpsSearching: isGpsSearching,
        ),
      ],
    );
  }
}
