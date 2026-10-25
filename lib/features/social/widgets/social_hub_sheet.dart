import 'package:flutter/material.dart';

import '../../../models/duel.dart';
import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';
import 'social_duel_creator_sheet.dart';
import 'social_duels_tab.dart';
import 'social_hub_cache.dart';
import 'social_hub_header.dart';
import 'social_squad_tab.dart';

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

  const SocialHubView({super.key, this.apiClient, this.currentUserId});

  @override
  State<SocialHubView> createState() => _SocialHubViewState();
}

class _SocialHubViewState extends State<SocialHubView> {
  late final ApiClient _apiClient;
  late final String _myUid;

  SocialTab _activeTab = SocialTab.squad;
  bool _isLoading = false;
  String? _errorMessage;

  List<FriendUser> _friends = [];
  List<FriendRequestDetail> _requests = [];
  List<Duel> _duels = [];

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _myUid = widget.currentUserId ?? FirebaseService().currentUserId;
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = _friends.isEmpty && _duels.isEmpty;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiClient.getFriends(),
        _apiClient.getFriendRequests(),
        _apiClient.getDuels(),
      ]);

      if (!mounted) return;
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
        if (mounted && (cached.friends.isNotEmpty || cached.duels.isNotEmpty)) {
          setState(() {
            _friends = cached.friends;
            _requests = cached.requests;
            _duels = cached.duels;
          });
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network offline: displaying cached syndicates';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialHubHeader(
          activeTab: _activeTab,
          friendsCount: _friends.length,
          activeDuelsCount: _duels.where((d) => d.isActive).length,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
          onRefresh: _refreshData,
        ),
        if (_errorMessage != null && (_friends.isNotEmpty || _duels.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s4,
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
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s12),
        if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (_errorMessage != null && _friends.isEmpty && _duels.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.textMuted,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                      ),
                      onPressed: _refreshData,
                      child: const Text('Retry connection'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: _refreshData,
              child: _activeTab == SocialTab.squad
                  ? SocialSquadTab(
                      friends: _friends,
                      requests: _requests,
                      onAddFriend: () => showAddFriendDialog(
                        context,
                        apiClient: _apiClient,
                        onAdded: _refreshData,
                      ),
                      onRespondRequest: _respondRequest,
                      onChallengeDuel: (friend) => showCreateDuelSheet(
                        context,
                        apiClient: _apiClient,
                        friends: _friends,
                        targetFriend: friend,
                        onCreated: _refreshData,
                      ),
                    )
                  : SocialDuelsTab(
                      duels: _duels,
                      myUid: _myUid,
                      onNewDuel: () => showCreateDuelSheet(
                        context,
                        apiClient: _apiClient,
                        friends: _friends,
                        onCreated: _refreshData,
                      ),
                      onAcceptDuel: _acceptDuel,
                      onDeclineDuel: _declineDuel,
                    ),
            ),
          ),
      ],
    );
  }
}
