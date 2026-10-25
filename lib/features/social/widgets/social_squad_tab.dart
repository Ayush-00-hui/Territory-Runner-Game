import 'package:flutter/material.dart';

import '../../../models/friend.dart';
import '../../../ui/ui.dart';

export 'social_add_friend_dialog.dart';

/// Squad tab displaying active friends and incoming squad invitations.
class SocialSquadTab extends StatelessWidget {
  final List<FriendUser> friends;
  final List<FriendRequestDetail> requests;
  final VoidCallback onAddFriend;
  final Future<void> Function(String reqId, String action) onRespondRequest;
  final void Function(FriendUser friend) onChallengeDuel;

  const SocialSquadTab({
    super.key,
    required this.friends,
    required this.requests,
    required this.onAddFriend,
    required this.onRespondRequest,
    required this.onChallengeDuel,
  });

  @override
  Widget build(BuildContext context) {
    final incomingRequests =
        requests.where((r) => r.isIncoming && r.status == 'pending').toList();

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
        // Action row: Add friend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Athletic squad',
              style: AppText.label.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            TextButton.icon(
              onPressed: onAddFriend,
              icon: const Icon(
                Icons.person_add_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              label: const Text(
                'Add runner',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        // Incoming requests
        if (incomingRequests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      'Incoming squad invitations (${incomingRequests.length})',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                ...incomingRequests.map((r) => _buildRequestCard(r)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],

        // Friends list
        if (friends.isEmpty)
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
                  Icons.group_off_rounded,
                  color: AppColors.textMuted,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.s12),
                const Text(
                  'No squad members yet',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                const Text(
                  'Add rival athletes or team members to monitor their territories and challenge them to duels.',
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
                  onPressed: onAddFriend,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text(
                    'Send friend request',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          ...friends.map((f) => _buildFriendCard(f)),
      ],
    );
  }

  Widget _buildRequestCard(FriendRequestDetail req) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surface2,
            child: Text(
              req.requesterName.isNotEmpty
                  ? req.requesterName[0].toUpperCase()
                  : 'R',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.requesterName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  req.requesterFaction,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.accent,
              size: 28,
            ),
            tooltip: 'Accept',
            onPressed: () => onRespondRequest(req.id, 'accept'),
          ),
          IconButton(
            icon: const Icon(
              Icons.cancel_rounded,
              color: AppColors.error,
              size: 28,
            ),
            tooltip: 'Decline',
            onPressed: () => onRespondRequest(req.id, 'decline'),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendUser friend) {
    final areaFormatted = friend.totalAreaSqm >= 1e6
        ? '${(friend.totalAreaSqm / 1e6).toStringAsFixed(2)} km²'
        : '${friend.totalAreaSqm.toStringAsFixed(0)} m²';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surface2,
            child: Text(
              friend.username.isNotEmpty
                  ? friend.username[0].toUpperCase()
                  : 'R',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      friend.username,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppSpacing.brFull,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        'Lvl ${friend.level}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '${friend.faction} • $areaFormatted claimed • ${friend.totalRuns} runs',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentContainer,
              foregroundColor: AppColors.accent,
              side: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.4),
                width: 1.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s6,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.br10),
            ),
            onPressed: () => onChallengeDuel(friend),
            icon: const Icon(Icons.sports_kabaddi_rounded, size: 14),
            label: const Text(
              'Duel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
