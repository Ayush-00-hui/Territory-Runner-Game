import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/feed_item.dart';
import '../../../services/api_client.dart';
import '../../../services/app_preferences.dart';
import '../../../ui/ui.dart';
import 'report_dialog.dart';
import 'social_add_friend_dialog.dart';

/// Tab displaying the activity feed of completed runs shared by mutual friends.
class SocialFeedTab extends StatefulWidget {
  final ApiClient? apiClient;
  final String? currentUserId;

  const SocialFeedTab({super.key, this.apiClient, this.currentUserId});

  @override
  State<SocialFeedTab> createState() => _SocialFeedTabState();
}

class _SocialFeedTabState extends State<SocialFeedTab> {
  late final ApiClient _apiClient;
  final AppPreferences _prefs = AppPreferences();

  List<FeedItem> _feedItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _apiClient.getActivityFeed();
      if (!mounted) return;
      setState(() {
        _feedItems = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load activity feed. Pull down to retry.';
      });
    }
  }

  Future<void> _toggleKudos(FeedItem item, String reaction) async {
    final currentMyKudos = item.myKudos;
    final isRemoving = currentMyKudos == reaction;

    // Optimistic UI update
    final newCounts = Map<String, int>.from(item.kudosCounts);
    if (currentMyKudos != null) {
      newCounts[currentMyKudos] = math.max(
        0,
        (newCounts[currentMyKudos] ?? 1) - 1,
      );
    }
    if (!isRemoving) {
      newCounts[reaction] = (newCounts[reaction] ?? 0) + 1;
    }

    final updated = item.copyWith(
      kudosCounts: newCounts,
      myKudos: isRemoving ? null : reaction,
      clearMyKudos: isRemoving,
    );

    setState(() {
      final idx = _feedItems.indexWhere((e) => e.id == item.id);
      if (idx != -1) {
        _feedItems[idx] = updated;
      }
    });

    try {
      if (isRemoving) {
        await _apiClient.removeKudos(item.id);
      } else {
        await _apiClient.sendKudos(item.id, reaction);
      }
    } catch (_) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        final idx = _feedItems.indexWhere((e) => e.id == item.id);
        if (idx != -1) {
          _feedItems[idx] = item;
        }
      });
      AppToast.show(context, 'Failed to update reaction.');
    }
  }

  Future<void> _hidePost(FeedItem item) async {
    setState(() {
      _feedItems.removeWhere((e) => e.id == item.id);
    });

    try {
      await _apiClient.hidePost(item.id);
      if (mounted) {
        AppToast.show(context, 'Post hidden from your feed.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Network error hiding post.');
      }
    }
  }

  Future<void> _blockUser(FeedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.br16),
        title: Text(
          'Block ${item.username}?',
          style: AppText.headingSmall.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'They will not be able to see your runs, send requests, or compete with you in duels.',
          style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.br8),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Block',
              style: AppText.bodySmall.copyWith(color: AppColors.onAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _feedItems.removeWhere((e) => e.userId == item.userId);
    });

    try {
      await _apiClient.blockUser(item.userId);
      if (mounted) {
        AppToast.show(context, 'User blocked.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Failed to block user. Please retry.');
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.br8),
                ),
                onPressed: _loadFeed,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadFeed,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        children: [
          // Privacy sharing status banner
          ValueListenableBuilder<bool>(
            valueListenable: _prefs.shareRunsWithFriendsNotifier,
            builder: (context, isSharing, _) {
              if (isSharing) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.br12,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your runs are private',
                            style: AppText.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Turn on sharing to let accepted friends see your runs.',
                            style: AppText.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    TextButton(
                      onPressed: () async {
                        await _prefs.toggleShareRunsWithFriends(true);
                        try {
                          await _apiClient.updateSettings({
                            'share_runs_with_friends': true,
                          });
                        } catch (_) {}
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            'Run sharing enabled with friends.',
                          );
                        }
                      },
                      child: Text(
                        'Share',
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_feedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
              child: EmptyState(
                icon: Icons.dynamic_feed_rounded,
                title: 'No friend activities yet',
                message: 'Runs completed by friends who opt in to sharing will appear here.',
                actionLabel: 'Add friends',
                onAction: () => showAddFriendDialog(
                  context,
                  apiClient: _apiClient,
                  onAdded: _loadFeed,
                ),
              ),
            )
          else
            ..._feedItems.map(_buildFeedCard),
        ],
      ),
    );
  }

  Widget _buildFeedCard(FeedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author info & overflow menu
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    item.username.isNotEmpty
                        ? item.username[0].toUpperCase()
                        : 'R',
                    style: AppText.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.faction != null &&
                              item.faction!.isNotEmpty) ...[
                            Text(
                              item.faction!,
                              style: AppText.caption.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                          Text(
                            _formatTimeAgo(item.createdAt),
                            style: AppText.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                  ),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.br8),
                  onSelected: (action) {
                    if (action == 'hide') {
                      _hidePost(item);
                    } else if (action == 'report') {
                      showReportDialog(
                        context,
                        userId: item.userId,
                        runId: item.id,
                        apiClient: _apiClient,
                      );
                    } else if (action == 'block') {
                      _blockUser(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Hide post'),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Report post'),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Text(
                        'Block runner',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s12),

            // Performance metrics row
            Row(
              children: [
                _buildStatPill(
                  label: 'Distance',
                  value:
                      '${(item.distanceMeters / 1000.0).toStringAsFixed(2)} km',
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildStatPill(
                  label: 'Time',
                  value: _formatDuration(item.durationSeconds),
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildStatPill(
                  label: 'Territory',
                  value: '${item.areaClaimed.toStringAsFixed(0)} m²',
                ),
              ],
            ),

            // Route thumbnail preview (privacy-masked coordinates only)
            if (item.routeThumbnail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.br8,
                  child: CustomPaint(
                    painter: _FeedRouteThumbnailPainter(
                      points: item.routeThumbnail,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.s12),

            // Kudos / Reactions bar
            Row(
              children: [
                _buildReactionChip(item, 'kudos', '👍'),
                const SizedBox(width: AppSpacing.s6),
                _buildReactionChip(item, 'clap', '👏'),
                const SizedBox(width: AppSpacing.s6),
                _buildReactionChip(item, 'fire', '🔥'),
                const SizedBox(width: AppSpacing.s6),
                _buildReactionChip(item, 'strong', '💪'),
                const Spacer(),
                if (item.totalKudosCount > 0)
                  Text(
                    '${item.totalKudosCount} ${item.totalKudosCount == 1 ? 'kudo' : 'kudos'}',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionChip(FeedItem item, String reaction, String emoji) {
    final isSelected = item.myKudos == reaction;
    final count = item.kudosCounts[reaction] ?? 0;

    return InkWell(
      onTap: () => _toggleKudos(item, reaction),
      borderRadius: AppRadius.brFull,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: AppRadius.brFull,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: AppText.bodyMedium),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Canvas painter rendering a normalized thumbnail of the masked GPS track.
class _FeedRouteThumbnailPainter extends CustomPainter {
  final List<LatLng> points;

  _FeedRouteThumbnailPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;

    const pad = 12.0;
    final usableW = size.width - pad * 2;
    final usableH = size.height - pad * 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final normX = dLng > 0 ? (points[i].longitude - minLng) / dLng : 0.5;
      final normY = dLat > 0 ? 1.0 - (points[i].latitude - minLat) / dLat : 0.5;

      final px = pad + normX * usableW;
      final py = pad + normY * usableH;

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }

    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FeedRouteThumbnailPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
