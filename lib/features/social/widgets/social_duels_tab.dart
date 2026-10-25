import 'package:flutter/material.dart';

import '../../../models/duel.dart';
import '../../../ui/ui.dart';

/// Duels tab displaying active, pending, and past head-to-head battles.
class SocialDuelsTab extends StatelessWidget {
  final List<Duel> duels;
  final String myUid;
  final VoidCallback onNewDuel;
  final Future<void> Function(String duelId) onAcceptDuel;
  final Future<void> Function(String duelId) onDeclineDuel;

  const SocialDuelsTab({
    super.key,
    required this.duels,
    required this.myUid,
    required this.onNewDuel,
    required this.onAcceptDuel,
    required this.onDeclineDuel,
  });

  @override
  Widget build(BuildContext context) {
    final activeDuels = duels.where((d) => d.isActive).toList();
    final pendingDuels = duels.where((d) => d.isPending).toList();
    final completedDuels = duels
        .where((d) => d.isCompleted || d.isDeclined || d.isExpired)
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Head-to-head battles',
              style: AppText.label.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            TextButton.icon(
              onPressed: onNewDuel,
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              label: const Text(
                'New duel',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        // Pending challenges
        if (pendingDuels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          ...pendingDuels.map((d) => _buildDuelCard(d)),
        ],

        // Active battles
        if (activeDuels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Active duels (${activeDuels.length})',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          ...activeDuels.map((d) => _buildDuelCard(d)),
        ],

        // Empty state
        if (activeDuels.isEmpty &&
            pendingDuels.isEmpty &&
            completedDuels.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sports_kabaddi_rounded,
                  color: AppColors.textMuted,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.s12),
                const Text(
                  'No duels in progress',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                const Text(
                  'Challenge friends to a 24-hour Area Match or Distance Sprint. Runs submitted during the duel automatically advance your meter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.br12,
                    ),
                  ),
                  onPressed: onNewDuel,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create first duel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

        // Completed history
        if (completedDuels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s20),
          Text(
            'Battle archive (${completedDuels.length})',
            style: AppText.label.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          ...completedDuels.map((d) => _buildDuelCard(d)),
        ],
      ],
    );
  }

  Widget _buildDuelCard(Duel duel) {
    final isMeChallenger = duel.isChallenger(myUid);
    final opponentName = duel.opponentName(myUid);
    final myProgress = duel.myProgress(myUid);
    final theirProgress = duel.theirProgress(myUid);

    final targetDisplay = duel.targetType == 'distance'
        ? '${(duel.targetValue / 1000).toStringAsFixed(1)} km'
        : '${duel.targetValue.toStringAsFixed(0)} m²';

    final myProgressDisplay = duel.targetType == 'distance'
        ? '${(myProgress / 1000).toStringAsFixed(1)} km'
        : '${myProgress.toStringAsFixed(0)} m²';

    final theirProgressDisplay = duel.targetType == 'distance'
        ? '${(theirProgress / 1000).toStringAsFixed(1)} km'
        : '${theirProgress.toStringAsFixed(0)} m²';

    Color statusColor;
    String statusText;
    if (duel.isPending) {
      statusColor = AppColors.warning;
      statusText = isMeChallenger ? 'Awaiting opponent' : 'Challenge received';
    } else if (duel.isActive) {
      statusColor = AppColors.accent;
      statusText = 'Battle in progress';
    } else if (duel.isCompleted) {
      final iWon = duel.didIWin(myUid);
      statusColor = iWon ? AppColors.gold : AppColors.error;
      statusText = iWon ? 'Victory (+${duel.xpStake} XP)' : 'Defeated';
    } else {
      statusColor = AppColors.textMuted;
      statusText = duel.status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(
          color: duel.isActive
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Target & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    duel.targetType == 'distance'
                        ? Icons.directions_run_rounded
                        : Icons.hexagon_outlined,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    '${duel.targetType == 'distance' ? 'Distance' : 'Area'}: $targetDisplay',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.brFull,
                  border: Border.all(color: statusColor, width: 0.8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s10),

          // Opponent info
          Text(
            'VS $opponentName • Stake: ${duel.xpStake} XP',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: AppSpacing.s10),

          // Dual Progress bars (for active or completed duels)
          if (duel.isActive || duel.isCompleted) ...[
            // You progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'You',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$myProgressDisplay / $targetDisplay (${(duel.myProgressFraction(myUid) * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: AppSpacing.brFull,
              child: LinearProgressIndicator(
                value: duel.myProgressFraction(myUid),
                backgroundColor: AppColors.surface2,
                color: AppColors.accent,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),

            // Opponent progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  opponentName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$theirProgressDisplay / $targetDisplay (${(duel.theirProgressFraction(myUid) * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: AppSpacing.brFull,
              child: LinearProgressIndicator(
                value: duel.theirProgressFraction(myUid),
                backgroundColor: AppColors.surface2,
                color: AppColors.secondary,
                minHeight: 6,
              ),
            ),
          ],

          // Actions for incoming pending challenges
          if (duel.isPending && !isMeChallenger) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.br10,
                      ),
                    ),
                    onPressed: () => onAcceptDuel(duel.id),
                    child: const Text(
                      'Accept duel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.br10,
                      ),
                    ),
                    onPressed: () => onDeclineDuel(duel.id),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
