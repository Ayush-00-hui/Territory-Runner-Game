import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/export_service.dart';
import '../../../ui/ui.dart';

/// Modal dialog allowing the runner to export an ML debug trace.
void showMlDebugExportDialog(
  BuildContext context, {
  required String callsign,
  required List<LatLng> points,
  required double distanceKm,
  required int durationSeconds,
}) {
  String selectedMode = 'run';
  String userTag = callsign.replaceAll(' ', '_').toLowerCase();
  if (userTag.isEmpty) userTag = 'team_member';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.br16,
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.science_rounded, color: AppColors.accent),
            SizedBox(width: AppSpacing.s8),
            Text(
              'ML Debug Trace Export',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select true transport modality to label this session for anti-cheat model training:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s12),
            DropdownButtonFormField<String>(
              initialValue: selectedMode,
              dropdownColor: AppColors.surface,
              decoration: InputDecoration(
                labelText: 'Transport Mode',
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'run', child: Text('Running (Athletic)')),
                DropdownMenuItem(value: 'walk', child: Text('Walking (Athletic)')),
                DropdownMenuItem(value: 'cycle', child: Text('Cycling (Athletic)')),
                DropdownMenuItem(value: 'bus', child: Text('Bus (Vehicle)')),
                DropdownMenuItem(value: 'auto', child: Text('Auto-Rickshaw (Vehicle)')),
                DropdownMenuItem(value: 'car', child: Text('Car / Taxi (Vehicle)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setModalState(() => selectedMode = val);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.surface,
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Export & Share'),
            onPressed: () async {
              Navigator.pop(ctx);
              final sessionId =
                  '${userTag}_${DateTime.now().millisecondsSinceEpoch}_$selectedMode';
              await ExportService().exportAndShareDebugTrace(
                sessionId: sessionId,
                userTag: userTag,
                transportMode: selectedMode,
                coordinates: points,
                totalDistanceMeters: distanceKm * 1000.0,
                durationSeconds: durationSeconds,
              );
            },
          ),
        ],
      ),
    ),
  );
}
