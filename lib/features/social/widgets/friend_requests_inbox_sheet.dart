import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';
import '../../gameplay/territory_service.dart';
import 'social_add_friend_dialog.dart';
import 'social_hub_cache.dart';

/// Opens the Friend Requests Inbox sheet showing incoming & sent friend requests,
/// user's unique Runner ID, and a direct `+` Add Friend action.
Future<void> showFriendRequestsInboxSheet(
  BuildContext context, {
  ApiClient? apiClient,
  String? currentCallsign,
  String? currentRunnerId,
  List<FriendRequestDetail>? initialRequests,
  VoidCallback? onChanged,
}) {
  String resolvedName = currentCallsign ?? '';
  String resolvedId = currentRunnerId ?? '';
  if (resolvedName.isEmpty || resolvedId.isEmpty) {
    try {
      final profile = TerritoryService().getProfile();
      if (resolvedName.isEmpty) resolvedName = profile.username;
      if (resolvedId.isEmpty) resolvedId = profile.displayRunnerId;
    } catch (_) {}
  }

  return AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AppSheet(
      title: 'Friend Requests',
      subtitle: 'Inbox & invitations',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.accent,
            ),
            tooltip: 'Add friend by ID',
            onPressed: () {
              showAddFriendDialog(
                ctx,
                apiClient: apiClient ?? ApiClient(),
                currentCallsign: resolvedName,
                currentRunnerId: resolvedId,
                onAdded: () {
                  onChanged?.call();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
      child: FriendRequestsInboxContent(
        apiClient: apiClient,
        currentCallsign: resolvedName,
        currentRunnerId: resolvedId,
        initialRequests: initialRequests,
        onChanged: onChanged,
      ),
    ),
  );
}

/// Interactive Friend Requests Inbox view supporting Incoming/Sent filters,
/// Accept/Decline actions, and direct Unique Runner ID sharing + `+` Add Friend.
class FriendRequestsInboxContent extends StatefulWidget {
  final ApiClient? apiClient;
  final String currentCallsign;
  final String currentRunnerId;
  final List<FriendRequestDetail>? initialRequests;
  final VoidCallback? onChanged;

  const FriendRequestsInboxContent({
    super.key,
    this.apiClient,
    this.currentCallsign = '',
    this.currentRunnerId = '',
    this.initialRequests,
    this.onChanged,
  });

  @override
  State<FriendRequestsInboxContent> createState() =>
      _FriendRequestsInboxContentState();
}

class _FriendRequestsInboxContentState
    extends State<FriendRequestsInboxContent> {
  late final ApiClient _apiClient;
  bool _showSent = false;
  bool _isSyncing = false;
  bool _isOffline = false;
  List<FriendRequestDetail> _requests = [];
  final Set<String> _actingRequestIds = {};

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    if (widget.initialRequests != null) {
      _requests = List.of(widget.initialRequests!);
    }
    _hydrateAndRefresh();
  }

  Future<void> _hydrateAndRefresh() async {
    if (_requests.isEmpty) {
      final cached = await SocialHubCache.loadCachedData();
      if (mounted && cached.requests.isNotEmpty) {
        setState(() => _requests = cached.requests);
      }
    }
    await _refreshRequests();
  }

  Future<void> _refreshRequests() async {
    if (!mounted) return;
    setState(() {
      _isSyncing = true;
      _isOffline = false;
    });
    try {
      final fetched = await _apiClient.getFriendRequests();
      if (!mounted) return;
      setState(() {
        _requests = fetched;
        _isSyncing = false;
        _isOffline = false;
      });
      await SocialHubCache.saveCachedRequests(fetched);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _respond(FriendRequestDetail req, String action) async {
    if (_actingRequestIds.contains(req.id)) return;
    setState(() => _actingRequestIds.add(req.id));
    try {
      final ok = await _apiClient.respondFriendRequest(req.id, action);
      if (!mounted) return;
      setState(() => _actingRequestIds.remove(req.id));
      if (ok) {
        final next = _requests.where((r) => r.id != req.id).toList();
        setState(() => _requests = next);
        await SocialHubCache.saveCachedRequests(next);
        if (mounted) {
          AppToast.show(
            context,
            action == 'accept'
                ? 'You and ${req.requesterName} are now friends!'
                : 'Friend request declined',
            type: action == 'accept' ? AppToastType.success : AppToastType.info,
          );
        }
        widget.onChanged?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _actingRequestIds.remove(req.id));
      AppToast.show(
        context,
        'Could not update request: $e',
        type: AppToastType.error,
      );
    }
  }

  void _openAddFriend() {
    showAddFriendDialog(
      context,
      apiClient: _apiClient,
      currentCallsign: widget.currentCallsign,
      currentRunnerId: widget.currentRunnerId,
      onAdded: () {
        _refreshRequests();
        widget.onChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _requests
        .where((r) => r.isIncoming && r.status == 'pending')
        .toList();
    final sent = _requests
        .where((r) => !r.isIncoming && r.status == 'pending')
        .toList();
    final activeList = _showSent ? sent : incoming;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.68,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.currentRunnerId.isNotEmpty) ...[
            _buildMyRunnerIdStrip(),
            const SizedBox(height: AppSpacing.s12),
          ],

          // Incoming / Sent pill switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.brFull,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterPill(
                    selected: !_showSent,
                    label: 'Inbox (${incoming.length})',
                    icon: Icons.inbox_rounded,
                    onTap: () => setState(() => _showSent = false),
                  ),
                ),
                Expanded(
                  child: _buildFilterPill(
                    selected: _showSent,
                    label: 'Sent (${sent.length})',
                    icon: Icons.outbox_rounded,
                    onTap: () => setState(() => _showSent = true),
                  ),
                ),
              ],
            ),
          ),

          if (_isSyncing) ...[
            const SizedBox(height: AppSpacing.s8),
            ClipRRect(
              borderRadius: AppRadius.brFull,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.surface2,
              ),
            ),
          ] else if (_isOffline) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Text(
                    'Unable to reach server — showing saved requests',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _refreshRequests,
                  child: Text(
                    'Retry',
                    style: AppText.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.s12),

          Flexible(
            child: activeList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: activeList.length,
                    itemBuilder: (context, index) {
                      final req = activeList[index];
                      return _showSent
                          ? _buildSentCard(req)
                          : _buildIncomingCard(req);
                    },
                  ),
          ),

          const SizedBox(height: AppSpacing.s12),
          PrimaryButton(
            label: 'Add Friend by Runner ID',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: _openAddFriend,
          ),
        ],
      ),
    );
  }

  Widget _buildMyRunnerIdStrip() {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: widget.currentRunnerId));
        AppToast.showGlobal(
          'Copied Runner ID "${widget.currentRunnerId}"!',
          type: AppToastType.info,
        );
      },
      borderRadius: AppRadius.br12,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppRadius.br12,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 16, color: AppColors.accent),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                'Your Runner ID: ${widget.currentRunnerId}',
                style: AppText.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            const Icon(Icons.copy_rounded, size: 14, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: AppSpacing.brFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.onAccent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: selected ? AppColors.onAccent : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCard(FriendRequestDetail req) {
    final isActing = _actingRequestIds.contains(req.id);
    final name = req.requesterName.isNotEmpty ? req.requesterName : 'Runner';
    final subParts = <String>[
      if (req.requesterCode.isNotEmpty) req.requesterCode,
      if (req.requesterFaction.isNotEmpty) req.requesterFaction,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br14,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.surface,
            child: Text(
              name[0].toUpperCase(),
              style: AppText.titleSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subParts.join(' • '),
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isActing)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 28,
              ),
              tooltip: 'Accept',
              onPressed: () => _respond(req, 'accept'),
            ),
            IconButton(
              icon: const Icon(
                Icons.cancel_rounded,
                color: AppColors.error,
                size: 28,
              ),
              tooltip: 'Decline',
              onPressed: () => _respond(req, 'decline'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentCard(FriendRequestDetail req) {
    final name = req.addresseeName.isNotEmpty ? req.addresseeName : 'Runner';
    final code = req.addresseeCode.isNotEmpty
        ? req.addresseeCode
        : req.addresseeId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br14,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.surface,
            child: Text(
              name[0].toUpperCase(),
              style: AppText.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: AppSpacing.brFull,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Pending',
              style: AppText.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showSent ? Icons.outbox_rounded : Icons.mark_email_read_outlined,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.s10),
          Text(
            _showSent ? 'No pending sent requests' : 'Inbox is all caught up',
            style: AppText.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            _showSent
                ? 'Tap Add Friend below and search by your friend\'s Runner ID or Name.'
                : 'Share your Runner ID above or tap + Add Friend to connect with athletes.',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Compact reusable action cluster showing Friend Requests Inbox icon (+ live badge)
/// alongside a `+` Add Friend button.
class FriendInboxActionButtons extends StatelessWidget {
  final VoidCallback onOpenInbox;
  final VoidCallback onAddFriend;
  final int? overridePendingCount;
  final bool compact;

  const FriendInboxActionButtons({
    super.key,
    required this.onOpenInbox,
    required this.onAddFriend,
    this.overridePendingCount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildCluster(int count) {
      final iconSize = compact ? 18.0 : 20.0;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.brFull,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: count > 0
                  ? 'Friend requests inbox, $count pending'
                  : 'Friend requests inbox',
              child: Tooltip(
                message: 'Friend requests inbox',
                child: InkWell(
                  onTap: onOpenInbox,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 7 : 8,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          count > 0
                              ? Icons.mark_email_unread_rounded
                              : Icons.inbox_rounded,
                          size: iconSize,
                          color: count > 0
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                        if (count > 0)
                          Positioned(
                            top: -5,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: AppSpacing.brFull,
                              ),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: AppText.labelSmall.copyWith(
                                  color: AppColors.onAccent,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 18, color: AppColors.border),
            Semantics(
              button: true,
              label: 'Add friend by ID',
              child: Tooltip(
                message: 'Add friend by ID',
                child: InkWell(
                  onTap: onAddFriend,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 7 : 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: iconSize,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (overridePendingCount != null) {
      return buildCluster(overridePendingCount!);
    }
    return ValueListenableBuilder<int>(
      valueListenable: SocialHubCache.incomingCountNotifier,
      builder: (context, count, _) => buildCluster(count),
    );
  }
}
