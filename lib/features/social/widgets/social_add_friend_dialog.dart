import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/friend.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

/// Opens a user-friendly modal sheet to find and add friends by Unique Runner ID or Name.
Future<void> showAddFriendDialog(
  BuildContext context, {
  required ApiClient apiClient,
  required VoidCallback onAdded,
  String? currentCallsign,
  String? currentRunnerId,
}) {
  return AppSheet.show<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AppSheet(
      title: 'Add Friend',
      subtitle: 'Search by Unique Runner ID or Name',
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
        tooltip: 'Close',
        onPressed: () => Navigator.pop(ctx),
      ),
      child: AddFriendSheetContent(
        apiClient: apiClient,
        onAdded: onAdded,
        currentCallsign: currentCallsign,
        currentRunnerId: currentRunnerId,
      ),
    ),
  );
}

/// Interactive body for searching and adding friends by Unique Runner ID or Name.
class AddFriendSheetContent extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onAdded;
  final String? currentCallsign;
  final String? currentRunnerId;

  const AddFriendSheetContent({
    super.key,
    required this.apiClient,
    required this.onAdded,
    this.currentCallsign,
    this.currentRunnerId,
  });

  @override
  State<AddFriendSheetContent> createState() => _AddFriendSheetContentState();
}

class _AddFriendSheetContentState extends State<AddFriendSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isSendingDirect = false;
  String? _searchError;
  String? _directError;
  String _lastQuery = '';

  List<RunnerSearchResult> _results = [];
  final Set<String> _sendingIds = {};
  final Set<String> _locallySentIds = {};
  final Set<String> _locallyAcceptedIds = {};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    final trimmed = raw.trim();
    setState(() {
      _directError = null;
      _searchError = null;
    });

    _debounceTimer?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _results = [];
        _lastQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 280), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _lastQuery = trimmed;
    });

    try {
      final matches = await widget.apiClient.searchUsers(trimmed);
      if (!mounted || _searchController.text.trim() != trimmed) return;
      setState(() {
        _results = matches;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || _searchController.text.trim() != trimmed) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _searchError = 'Could not search online right now. You can still send a direct request below.';
      });
    }
  }

  Future<void> _sendRequestToResult(RunnerSearchResult target) async {
    if (_sendingIds.contains(target.id)) return;

    setState(() {
      _sendingIds.add(target.id);
      _directError = null;
    });

    try {
      final ok = await widget.apiClient.sendFriendRequest(target.id);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _sendingIds.remove(target.id);
          _locallySentIds.add(target.id);
        });
        AppToast.showGlobal(
          'Friend request sent to ${target.username}!',
          type: AppToastType.success,
        );
        widget.onAdded();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingIds.remove(target.id));
      final msg = e is ApiException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      AppToast.showGlobal(msg, type: AppToastType.error);
    }
  }

  Future<void> _acceptIncomingForUser(RunnerSearchResult target) async {
    if (_sendingIds.contains(target.id)) return;

    setState(() => _sendingIds.add(target.id));
    try {
      final reqs = await widget.apiClient.getFriendRequests();
      final match = reqs.where(
        (r) => r.isIncoming && r.requesterId == target.id,
      );
      if (match.isNotEmpty) {
        final ok = await widget.apiClient.respondFriendRequest(
          match.first.id,
          'accept',
        );
        if (ok && mounted) {
          setState(() {
            _sendingIds.remove(target.id);
            _locallyAcceptedIds.add(target.id);
          });
          AppToast.showGlobal(
            'You and ${target.username} are now friends!',
            type: AppToastType.success,
          );
          widget.onAdded();
          return;
        }
      }
      if (mounted) {
        setState(() => _sendingIds.remove(target.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingIds.remove(target.id));
      AppToast.showGlobal(
        'Could not accept request: $e',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _sendDirectRequest() async {
    final target = _searchController.text.trim();
    if (target.isEmpty) {
      setState(
        () => _directError = 'Please enter your friend\'s Runner ID or Name.',
      );
      return;
    }

    setState(() {
      _isSendingDirect = true;
      _directError = null;
    });

    try {
      final ok = await widget.apiClient.sendFriendRequest(target);
      if (ok && mounted) {
        setState(() => _isSendingDirect = false);
        Navigator.pop(context);
        AppToast.showGlobal(
          'Friend request sent to $target!',
          type: AppToastType.success,
        );
        widget.onAdded();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingDirect = false;
        if (e is ApiException) {
          _directError = e.message;
        } else {
          _directError = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  String _formatArea(double sqm) {
    if (sqm >= 1e6) return '${(sqm / 1e6).toStringAsFixed(2)} km²';
    if (sqm > 0) return '${sqm.toStringAsFixed(0)} m²';
    return '0 m²';
  }

  @override
  Widget build(BuildContext context) {
    final hasIdentity =
        (widget.currentRunnerId != null &&
            widget.currentRunnerId!.isNotEmpty) ||
        (widget.currentCallsign != null && widget.currentCallsign!.isNotEmpty);
    final query = _searchController.text.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.70,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasIdentity) ...[
              _buildMyIdentityCard(),
              const SizedBox(height: AppSpacing.s16),
            ],

            // Search bar
            TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Runner ID or Name',
                hintText: 'e.g. RUN-7K9M2P or Sarah',
                labelStyle: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
                hintStyle: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.accent,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                errorText: _directError,
                errorMaxLines: 2,
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            if (query.isEmpty)
              _buildSearchGuide()
            else if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Searching runners...',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (_results.isNotEmpty) ...[
              Text(
                'Matching runners (${_results.length})',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              ..._results.map(_buildResultCard),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppSpacing.br14,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_search_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            _searchError ??
                                'No runners found matching "$_lastQuery".',
                            style: AppText.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    SecondaryButton(
                      label: 'Send Direct Request to "$query"',
                      icon: Icons.send_rounded,
                      isLoading: _isSendingDirect,
                      onPressed: _sendDirectRequest,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyIdentityCard() {
    final hasId =
        widget.currentRunnerId != null && widget.currentRunnerId!.isNotEmpty;
    final hasName =
        widget.currentCallsign != null && widget.currentCallsign!.isNotEmpty;
    final copyValue = hasId ? widget.currentRunnerId! : widget.currentCallsign!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br12,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AppColors.accent, size: 18),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasId
                      ? 'Your ID: ${widget.currentRunnerId}'
                      : 'Your Identity',
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (hasName)
                  Text(
                    'Name: ${widget.currentCallsign}',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyValue));
              AppToast.showGlobal(
                'Copied "$copyValue" to clipboard!',
                type: AppToastType.info,
              );
            },
            borderRadius: AppSpacing.brFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.brFull,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Copy',
                    style: AppText.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchGuide() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br14,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two quick ways to connect',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          _buildGuideRow(
            Icons.badge_outlined,
            'By Runner ID',
            'Enter your friend\'s unique RUN-XXXXXX code for an exact match.',
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildGuideRow(
            Icons.person_search_rounded,
            'By Name',
            'Type their runner name to browse matching athletes and verify their ID.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                desc,
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(RunnerSearchResult user) {
    final isSending = _sendingIds.contains(user.id);
    final isLocallySent = _locallySentIds.contains(user.id);
    final isLocallyAccepted = _locallyAcceptedIds.contains(user.id);

    Widget trailing;
    if (user.isSelf) {
      trailing = _buildStatusBadge('You', AppColors.textMuted);
    } else if (user.isFriend || isLocallyAccepted) {
      trailing = _buildStatusBadge('Friends', AppColors.accent);
    } else if (user.isPendingSent || isLocallySent) {
      trailing = _buildStatusBadge('Sent', AppColors.accent);
    } else if (user.isPendingReceived) {
      trailing = PrimaryButton(
        label: 'Accept',
        isFullWidth: false,
        isLoading: isSending,
        onPressed: () => _acceptIncomingForUser(user),
      );
    } else {
      trailing = PrimaryButton(
        label: 'Add',
        icon: Icons.person_add_rounded,
        isFullWidth: false,
        isLoading: isSending,
        onPressed: () => _sendRequestToResult(user),
      );
    }

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
              user.username.isNotEmpty ? user.username[0].toUpperCase() : 'R',
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        style: AppText.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    NeutralChip(
                      label: 'Lvl ${user.level}',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${user.runnerCode.isNotEmpty ? user.runnerCode : user.id}'
                  '${user.faction.isNotEmpty ? ' • ${user.faction}' : ''}'
                  ' • ${_formatArea(user.totalAreaSqm)}',
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          trailing,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppSpacing.brFull,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
