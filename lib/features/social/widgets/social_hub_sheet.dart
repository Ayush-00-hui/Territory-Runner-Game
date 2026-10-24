import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/duel.dart';
import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../services/firebase_service.dart';
import '../../../ui/ui.dart';

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
            // Handle bar
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

enum _SocialTab { squad, duels }

class _SocialHubViewState extends State<SocialHubView> {
  late final ApiClient _apiClient;
  late final String _myUid;

  static const String _cachedFriendsKey = 'territory_runner_cached_friends';
  static const String _cachedRequestsKey =
      'territory_runner_cached_friend_requests';
  static const String _cachedDuelsKey = 'territory_runner_cached_duels';

  _SocialTab _activeTab = _SocialTab.squad;
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

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = prefs.getString(_cachedFriendsKey);
      final requestsJson = prefs.getString(_cachedRequestsKey);
      final duelsJson = prefs.getString(_cachedDuelsKey);

      final cachedFriends = <FriendUser>[];
      if (friendsJson != null && friendsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(friendsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedFriends.add(FriendUser.fromJson(item));
          }
        }
      }

      final cachedRequests = <FriendRequestDetail>[];
      if (requestsJson != null && requestsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(requestsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedRequests.add(FriendRequestDetail.fromJson(item));
          }
        }
      }

      final cachedDuels = <Duel>[];
      if (duelsJson != null && duelsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(duelsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedDuels.add(Duel.fromJson(item));
          }
        }
      }

      if (mounted &&
          (cachedFriends.isNotEmpty ||
              cachedRequests.isNotEmpty ||
              cachedDuels.isNotEmpty)) {
        setState(() {
          if (_friends.isEmpty) _friends = cachedFriends;
          if (_requests.isEmpty) _requests = cachedRequests;
          if (_duels.isEmpty) _duels = cachedDuels;
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load cached social data: $e',
        tag: 'SocialHubView',
      );
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedFriendsKey,
        jsonEncode(_friends.map((f) => f.toJson()).toList()),
      );
      await prefs.setString(
        _cachedRequestsKey,
        jsonEncode(_requests.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        _cachedDuelsKey,
        jsonEncode(_duels.map((d) => d.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to cache social data: $e',
        tag: 'SocialHubView',
      );
    }
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
      await _saveCachedData();
    } catch (e) {
      if (!mounted) return;
      if (_friends.isEmpty && _duels.isEmpty) {
        await _loadCachedData();
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network offline: displaying cached syndicates';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              const Icon(Icons.hub_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Social Syndicate & Duels',
                  style: AppText.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Refresh Hub',
                onPressed: _refreshData,
              ),
            ],
          ),
        ),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.brFull,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTab(
                    tab: _SocialTab.squad,
                    label: 'Squad (${_friends.length})',
                    icon: Icons.people_rounded,
                  ),
                ),
                Expanded(
                  child: _buildSubTab(
                    tab: _SocialTab.duels,
                    label: 'Duels (${_duels.where((d) => d.isActive).length})',
                    icon: Icons.sports_kabaddi_rounded,
                  ),
                ),
              ],
            ),
          ),
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
                      child: const Text('RETRY CONNECTION'),
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
              child: _activeTab == _SocialTab.squad
                  ? _buildSquadTab()
                  : _buildDuelsTab(),
            ),
          ),
      ],
    );
  }

  Widget _buildSubTab({
    required _SocialTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: AppSpacing.brFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.onAccent : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onAccent
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadTab() {
    final incomingRequests = _requests
        .where((r) => r.isIncoming && r.status == 'pending')
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
              onPressed: _showAddFriendDialog,
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
        if (_friends.isEmpty)
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
                  onPressed: _showAddFriendDialog,
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
          ..._friends.map((f) => _buildFriendCard(f)),
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
            onPressed: () => _respondRequest(req.id, 'accept'),
          ),
          IconButton(
            icon: const Icon(
              Icons.cancel_rounded,
              color: AppColors.error,
              size: 28,
            ),
            tooltip: 'Decline',
            onPressed: () => _respondRequest(req.id, 'decline'),
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
            onPressed: () => _showCreateDuelDialog(targetFriend: friend),
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

  Widget _buildDuelsTab() {
    final activeDuels = _duels.where((d) => d.isActive).toList();
    final pendingDuels = _duels.where((d) => d.isPending).toList();
    final completedDuels = _duels
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
              onPressed: () => _showCreateDuelDialog(),
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
                  onPressed: () => _showCreateDuelDialog(),
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
    final isMeChallenger = duel.isChallenger(_myUid);
    final opponentName = duel.opponentName(_myUid);
    final myProgress = duel.myProgress(_myUid);
    final theirProgress = duel.theirProgress(_myUid);

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
      final iWon = duel.didIWin(_myUid);
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
                  'YOU',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$myProgressDisplay / $targetDisplay (${(duel.myProgressFraction(_myUid) * 100).toStringAsFixed(0)}%)',
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
                value: duel.myProgressFraction(_myUid),
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
                  '$theirProgressDisplay / $targetDisplay (${(duel.theirProgressFraction(_myUid) * 100).toStringAsFixed(0)}%)',
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
                value: duel.theirProgressFraction(_myUid),
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
                    onPressed: () => _acceptDuel(duel.id),
                    child: const Text(
                      'ACCEPT DUEL',
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
                    onPressed: () => _declineDuel(duel.id),
                    child: const Text('DECLINE'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
        AppToast.show(
          context,
          'Error: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _acceptDuel(String duelId) async {
    try {
      final ok = await _apiClient.acceptDuel(duelId);
      if (ok && mounted) {
        AppToast.show(
          context,
          'Duel accepted',
          type: AppToastType.success,
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Error: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _declineDuel(String duelId) async {
    try {
      final ok = await _apiClient.declineDuel(duelId);
      if (ok && mounted) {
        AppToast.show(
          context,
          'Duel declined',
          type: AppToastType.info,
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Error: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.br20),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: AppSpacing.s8),
            Text(
              'Add Squad Runner',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the runner ID or callsign of your friend to issue a squad invite:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: controller,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Runner ID / Callsign',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderRadius: AppSpacing.br12),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.br10),
            ),
            onPressed: () async {
              final target = controller.text.trim();
              if (target.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final ok = await _apiClient.sendFriendRequest(target);
                if (ok && mounted) {
                  AppToast.show(
                    context,
                    'Squad invite sent to $target',
                    type: AppToastType.success,
                  );
                  _refreshData();
                }
              } catch (e) {
                if (mounted) {
                  AppToast.show(
                    context,
                    'Failed: $e',
                    type: AppToastType.error,
                  );
                }
              }
            },
            child: const Text(
              'DISPATCH INVITE',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDuelDialog({FriendUser? targetFriend}) {
    String opponentId =
        targetFriend?.id ?? (_friends.isNotEmpty ? _friends.first.id : '');
    String targetType = 'area';
    double targetValue = 5000; // 5000 sqm or 5000 meters
    int xpStake = 500;

    final opponentController = TextEditingController(text: opponentId);

    showModalBottomSheet(
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
                    'OPPONENT RUNNER',
                    style: AppText.label.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  if (_friends.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _friends.any((f) => f.id == opponentId)
                          ? opponentId
                          : _friends.first.id,
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
                      items: _friends
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
                    'BATTLE METRIC',
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
                          label: const Center(child: Text('AREA (m²)')),
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
                          label: const Center(child: Text('DISTANCE (km)')),
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
                    'XP STAKE',
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
                        final created = await _apiClient.createDuel(
                          opponentId: chosenOpponent,
                          targetType: targetType,
                          targetValue: targetValue,
                          xpStake: xpStake,
                        );
                        if (created != null && mounted) {
                          AppToast.show(
                            context,
                            'Duel challenge sent. May the fastest runner prevail.',
                            type: AppToastType.success,
                          );
                          _refreshData();
                        }
                      } catch (e) {
                        if (mounted) {
                          AppToast.show(
                            context,
                            'Failed: $e',
                            type: AppToastType.error,
                          );
                        }
                      }
                    },
                    child: const Text(
                      'LAUNCH 24-HOUR DUEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1.0,
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
}
