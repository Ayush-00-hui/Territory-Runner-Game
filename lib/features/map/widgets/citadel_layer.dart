import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../services/citadel_service.dart';
import '../../../ui/ui.dart';
import 'citadel_detail_sheet.dart';

/// Interactive map layer rendering Landmark Citadels / King of the Hill strongholds.
class CitadelLayer extends StatefulWidget {
  const CitadelLayer({super.key});

  @override
  State<CitadelLayer> createState() => _CitadelLayerState();
}

class _CitadelLayerState extends State<CitadelLayer> {
  final CitadelService _citadelService = CitadelService();

  @override
  void initState() {
    super.initState();
    _citadelService.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _citadelService.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final citadels = _citadelService.citadels;
    if (citadels.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: citadels.map((citadel) {
        final isApex = citadel.controllingFaction.contains('Apex');
        final factionColor = isApex ? AppColors.accent : AppColors.gold;

        return Marker(
          point: citadel.position,
          width: 80.0,
          height: 80.0,
          child: GestureDetector(
            onTap: () => CitadelDetailSheet.show(context, citadel),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7.0),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.94),
                    shape: BoxShape.circle,
                    border: Border.all(color: factionColor, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: factionColor.withValues(alpha: 0.45),
                        blurRadius: 12.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fort_rounded,
                    color: AppColors.textPrimary,
                    size: 22.0,
                  ),
                ),
                const SizedBox(height: 3.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: factionColor.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    citadel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
