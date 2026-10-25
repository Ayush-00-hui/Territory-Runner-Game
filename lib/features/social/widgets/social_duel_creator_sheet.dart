import 'package:flutter/material.dart';

import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

/// Opens the duel creation modal bottom sheet.
Future<void> showCreateDuelSheet(
  BuildContext context, {
  required ApiClient apiClient,
  required List<FriendUser> friends,
  FriendUser? targetFriend,
  required VoidCallback onCreated,
}) {
  String opponentId =
      targetFriend?.id ?? (friends.isNotEmpty ? friends.first.id : '');
  String targetType = 'area';
  double targetValue = 5000; // 5000 sqm or 5000 meters
  int xpStake = 500;

  final opponentController = TextEditingController(text: opponentId);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s20,
            AppSpacing.s20,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s20,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: AppSpacing.r24),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_kabaddi_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Send duel challenge',
                      style: AppText.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),

                // Opponent Picker
                Text(
                  'Opponent runner',
                  style: AppText.label.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                if (friends.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: friends.any((f) => f.id == opponentId)
                        ? opponentId
                        : friends.first.id,
                    dropdownColor: AppColors.surface2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.br12,
                      ),
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: friends
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text('${f.username} (${f.faction})'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => opponentId = val);
                    },
                  )
                else
                  TextField(
                    controller: opponentController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Opponent User ID',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: AppSpacing.br12,
                      ),
                    ),
                    onChanged: (val) => opponentId = val.trim(),
                  ),

                const SizedBox(height: AppSpacing.s16),

                // Target Type Selector
                Text(
                  'Metric',
                  style: AppText.label.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Area (m²)')),
                        selected: targetType == 'area',
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface2,
                        labelStyle: TextStyle(
                          color: targetType == 'area'
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setSheetState(() {
                          targetType = 'area';
                          targetValue = 5000;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Distance (km)')),
                        selected: targetType == 'distance',
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface2,
                        labelStyle: TextStyle(
                          color: targetType == 'distance'
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setSheetState(() {
                          targetType = 'distance';
                          targetValue = 5000; // 5.0 km
                        }),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),

                // Target Preset Chips
                Text(
                  'Goal target',
                  style: AppText.label.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Wrap(
                  spacing: AppSpacing.s8,
                  children: targetType == 'area'
                      ? [
                          _buildTargetChip(
                            '2,500 m²',
                            2500,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '5,000 m²',
                            5000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '10,000 m²',
                            10000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '25,000 m²',
                            25000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                        ]
                      : [
                          _buildTargetChip(
                            '3.0 km',
                            3000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '5.0 km',
                            5000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '10.0 km',
                            10000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                          _buildTargetChip(
                            '15.0 km',
                            15000,
                            targetValue,
                            (v) => setSheetState(() => targetValue = v),
                          ),
                        ],
                ),

                const SizedBox(height: AppSpacing.s16),

                // XP Stake
                Text(
                  'XP stake',
                  style: AppText.label.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Wrap(
                  spacing: AppSpacing.s8,
                  children: [250, 500, 1000].map((stake) {
                    return ChoiceChip(
                      label: Text('+$stake XP'),
                      selected: xpStake == stake,
                      selectedColor: AppColors.secondary,
                      backgroundColor: AppColors.surface2,
                      labelStyle: TextStyle(
                        color: xpStake == stake
                            ? AppColors.onAccent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setSheetState(() => xpStake = stake),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.s24),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br12,
                    ),
                  ),
                  onPressed: () async {
                    final chosenOpponent = opponentId.isNotEmpty
                        ? opponentId
                        : opponentController.text.trim();
                    if (chosenOpponent.isEmpty) {
                      AppToast.show(
                        context,
                        'Please select or specify an opponent',
                        type: AppToastType.warning,
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    try {
                      final created = await apiClient.createDuel(
                        opponentId: chosenOpponent,
                        targetType: targetType,
                        targetValue: targetValue,
                        xpStake: xpStake,
                      );
                      if (created != null && context.mounted) {
                        AppToast.show(
                          context,
                          'Duel challenge sent. May the fastest runner prevail.',
                          type: AppToastType.success,
                        );
                        onCreated();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.show(
                          context,
                          'Failed: $e',
                          type: AppToastType.error,
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Launch 24-hour duel',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildTargetChip(
  String label,
  double value,
  double selectedValue,
  ValueChanged<double> onSelected,
) {
  final isSelected = (value - selectedValue).abs() < 1e-4;
  return ChoiceChip(
    label: Text(label),
    selected: isSelected,
    selectedColor: AppColors.accent,
    backgroundColor: AppColors.surface2,
    labelStyle: TextStyle(
      color: isSelected ? AppColors.onAccent : AppColors.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),
    onSelected: (_) => onSelected(value),
  );
}
