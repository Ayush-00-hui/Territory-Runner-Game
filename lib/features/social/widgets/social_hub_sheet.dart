import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/duel.dart';
import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';
import '../../gameplay/territory_service.dart';
import 'friend_requests_inbox_sheet.dart';
import 'social_duel_creator_sheet.dart';
import 'social_duels_tab.dart';
import 'social_hub_cache.dart';
import 'social_hub_header.dart';
import 'social_squad_tab.dart';

export 'friend_requests_inbox_sheet.dart';
export 'social_add_friend_dialog.dart';
export 'social_duel_creator_sheet.dart';
export 'social_duels_tab.dart';
export 'social_hub_header.dart';
export 'social_squad_tab.dart';

/// Opens the Social Hub bottom sheet containing Squad and Head-to-Head Duels.
Future<void> showSocialHubSheet(
  BuildContext context, {
  ApiClient? apiClient,
  String? currentUserId,
}) {
  return AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SocialHubSheet(apiClient: apiClient, currentUserId: currentUserId),
    ),
  );
}

class SocialHubSheet extends StatelessWidget {
  final ApiClient? apiClient;
  final String? currentUserId;

  const SocialHubSheet({super.key, this.apiClient, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: AppSpacing.r24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: AppRadius.brFull,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Expanded(
              child: SocialHubView(
                apiClient: apiClient,
                currentUserId: currentUserId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Social Hub View (embeddable in both bottom sheets and profile tabs).
class SocialHubView extends StatefulWidget {
  final ApiClient? apiClient;
  final String? currentUserId;
  final bool isEmbedded;

  const SocialHubView({
    super.key,
    this.apiClient,
    this.currentUserId,
    this.isEmbedded = false,
  });

  @override
  State<SocialHubView> createState() => _SocialHubViewState();
}

class _SocialHubViewState extends State<SocialHubView> {
  late final ApiClient _apiClient;
  late final String _myUid;
  String? _myCallsign;
  String? _myRunnerId;

  SocialTab _activeTab = SocialTab.squad;
  bool _isLoading = false;
  bool _hasLoadedFromNetwork = false;
  String? _errorMessage;

  List<FriendUser> _friends = [];
  List<FriendRequestDetail> _requests = [];
  List<Duel> _duels = [];

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _myUid = widget.currentUserId ?? FirebaseService().currentUserId;
    try {
      final profile = TerritoryService().getProfile();
      _myCallsign = profile.username;
      _myRunnerId = profile.displayRunnerId;
    } catch (_) {}
    unawaited(_hydrateCacheInitial());
    unawaited(_refreshData());
  }

  Future<void> _hydrateCacheInitial() async {
    final cached = await SocialHubCache.loadCachedData();
    if (!mounted || _hasLoadedFromNetwork) return;
    if (_friends.isEmpty &&
        _duels.isEmpty &&
        (cached.friends.isNotEmpty ||
            cached.requests.isNotEmpty ||
            cached.duels.isNotEmpty)) {
      setState(() {
        _friends = cached.friends;
        _requests = cached.requests;
        _duels = cached.duels;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiClient.getFriends(),
        _apiClient.getFriendRequests(),
        _apiClient.getDuels(),
      ]);

      if (widget.apiClient == null) {
        unawaited(
          TerritoryService().syncIdentityWithBackend().then((profile) {
            if (!mounted) return;
            setState(() {
              _myCallsign = profile.username;
              _myRunnerId = profile.displayRunnerId;
            });
          }),
        );
      }

      if (!mounted) return;
      _hasLoadedFromNetwork = true;
      setState(() {
        _friends = results[0] as List<FriendUser>;
        _requests = results[1] as List<FriendRequestDetail>;
        _duels = results[2] as List<Duel>;
        _isLoading = false;
      });
      await SocialHubCache.saveCachedData(
        friends: _friends,
        requests: _requests,
        duels: _duels,
      );
    } catch (e) {
      if (!mounted) return;
      if (_friends.isEmpty && _duels.isEmpty) {
        final cached = await SocialHubCache.loadCachedData();
        if (mounted &&
            (cached.friends.isNotEmpty ||
                cached.requests.isNotEmpty ||
                cached.duels.isNotEmpty)) {
          setState(() {
            _friends = cached.friends;
            _requests = cached.requests;
            _duels = cached.duels;
          });
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _friends.isNotEmpty || _duels.isNotEmpty
            ? 'Network offline: displaying cached squads'
            : 'Offline mode: add friends by Runner ID or retry sync';
      });
    }
  }

  void _openAddFriendSheet() {
    showAddFriendDialog(
      context,
      apiClient: _apiClient,
      currentCallsign: _myCallsign,
      currentRunnerId: _myRunnerId,
      onAdded: _refreshData,
    );
  }

  void _openInboxSheet() {
    showFriendRequestsInboxSheet(
      context,
      apiClient: _apiClient,
      currentCallsign: _myCallsign,
      currentRunnerId: _myRunnerId,
      initialRequests: _requests,
      onChanged: _refreshData,
    );
  }

  Future<void> _respondRequest(String reqId, String action) async {
    try {
      final ok = await _apiClient.respondFriendRequest(reqId, action);
      if (ok && mounted) {
        AppToast.show(
          context,
          'Friend request ${action}ed',
          type: action == 'accept' ? AppToastType.success : AppToastType.info,
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: AppToastType.error);
      }
    }
  }

  Future<void> _acceptDuel(String duelId) async {
    try {
      final ok = await _apiClient.acceptDuel(duelId);
      if (ok && mounted) {
        AppToast.show(context, 'Duel accepted', type: AppToastType.success);
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: AppToastType.error);
      }
    }
  }

  Future<void> _declineDuel(String duelId) async {
    try {
      final ok = await _apiClient.declineDuel(duelId);
      if (ok && mounted) {
        AppToast.show(context, 'Duel declined', type: AppToastType.info);
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error: $e', type: AppToastType.error);
      }
    }
  }

  Widget _buildSquadTab({required bool embedded}) {
    return SocialSquadTab(
      friends: _friends,
      requests: _requests,
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      myCallsign: _myCallsign,
      myRunnerId: _myRunnerId,
      onAddFriend: _openAddFriendSheet,
      onRespondRequest: _respondRequest,
      onChallengeDuel: (friend) => showCreateDuelSheet(
        context,
        apiClient: _apiClient,
        friends: _friends,
        targetFriend: friend,
        onCreated: _refreshData,
      ),
    );
  }

  Widget _buildDuelsTab({required bool embedded}) {
    return SocialDuelsTab(
      duels: _duels,
      myUid: _myUid,
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      onNewDuel: () => showCreateDuelSheet(
        context,
        apiClient: _apiClient,
        friends: _friends,
        onCreated: _refreshData,
      ),
      onAcceptDuel: _acceptDuel,
      onDeclineDuel: _declineDuel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomingPendingCount = _requests
        .where((r) => r.isIncoming && r.status == 'pending')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialHubHeader(
          activeTab: _activeTab,
          friendsCount: _friends.length,
          activeDuelsCount: _duels.where((d) => d.isActive).length,
          incomingRequestsCount: incomingPendingCount,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          onRefresh: _refreshData,
          onOpenInbox: _openInboxSheet,
          onAddFriend: _openAddFriendSheet,
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: ClipRRect(
              borderRadius: AppRadius.brFull,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.accent,
                backgroundColor: AppColors.surface2,
              ),
            ),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s6,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.br8,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refreshData,
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
            ),
          ),
        const SizedBox(height: AppSpacing.s12),
        widget.isEmbedded
            ? (_activeTab == SocialTab.squad
                  ? _buildSquadTab(embedded: true)
                  : _buildDuelsTab(embedded: true))
            : Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _refreshData,
                  child: _activeTab == SocialTab.squad
                      ? _buildSquadTab(embedded: false)
                      : _buildDuelsTab(embedded: false),
                ),
              ),
      ],
    );
  }
}
