import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';
import 'app_sheet.dart';
import '../../services/sync_queue.dart';

import '../../services/websocket_service.dart';

enum SystemStatusSeverity { neutral, active, warning, error }

/// Unified, calm, single status indicator.
/// Combines GPS and Cloud Sync status into a single neutral dot + label.
/// Tapping opens an AppSheet with exact diagnostic details.
class CombinedStatusIndicator extends StatefulWidget {
  final double? accuracyMeters;
  final bool isGpsSearching;
  final VoidCallback? onExpanded;
  final SyncQueueService? syncQueue;
  final WebSocketService? webSocketService;

  const CombinedStatusIndicator({
    super.key,
    this.accuracyMeters,
    this.isGpsSearching = false,
    this.onExpanded,
    this.syncQueue,
    this.webSocketService,
  });

  /// Static helper to show the system status diagnostic sheet from any context.
  static void showDiagnosticSheet(
    BuildContext context, {
    double? accuracyMeters,
    bool isGpsSearching = false,
    SyncQueueService? syncQueue,
    WebSocketService? webSocketService,
    VoidCallback? onExpanded,
  }) {
    AppMotion.lightTick();
    onExpanded?.call();

    AppSheet.show(
      context: context,
      builder: (sheetContext) => _DiagnosticSheetContent(
        accuracyMeters: accuracyMeters,
        isGpsSearching: isGpsSearching,
        syncQueue: syncQueue ?? SyncQueueService(),
        webSocketService: webSocketService ?? WebSocketService(),
      ),
    );
  }

  @override
  State<CombinedStatusIndicator> createState() =>
      _CombinedStatusIndicatorState();
}

class _CombinedStatusIndicatorState extends State<CombinedStatusIndicator> {
  late final SyncQueueService _syncQueue;
  late final WebSocketService _wsService;
  VoidCallback? _unsettledListener;
  VoidCallback? _statusListener;
  int _pendingRuns = 0;
  bool _isSyncing = false;
  bool _isLocationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _syncQueue = widget.syncQueue ?? SyncQueueService();
    _wsService = widget.webSocketService ?? WebSocketService();

    _pendingRuns = _syncQueue.unsettledCountNotifier.value;
    _unsettledListener = () {
      if (mounted) {
        setState(() => _pendingRuns = _syncQueue.unsettledCountNotifier.value);
      }
    };
    _syncQueue.unsettledCountNotifier.addListener(_unsettledListener!);

    _isSyncing = _syncQueue.statusNotifier.value == SyncStatus.syncing;
    _statusListener = () {
      if (mounted) {
        setState(
          () => _isSyncing =
              _syncQueue.statusNotifier.value == SyncStatus.syncing,
        );
      }
    };
    _syncQueue.statusNotifier.addListener(_statusListener!);

    _checkLocationService();
  }

  @override
  void dispose() {
    if (_unsettledListener != null) {
      _syncQueue.unsettledCountNotifier.removeListener(_unsettledListener!);
    }
    if (_statusListener != null) {
      _syncQueue.statusNotifier.removeListener(_statusListener!);
    }
    super.dispose();
  }

  Future<void> _checkLocationService() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) setState(() => _isLocationServiceEnabled = enabled);
    } catch (_) {}
  }

  ({String label, Color dotColor, SystemStatusSeverity severity})
  _computeStatus() {
    if (!_isLocationServiceEnabled) {
      return (
        label: 'Location off',
        dotColor: AppColors.error,
        severity: SystemStatusSeverity.error,
      );
    }

    if (widget.isGpsSearching) {
      return (
        label: 'Locating...',
        dotColor: AppColors.textMuted,
        severity: SystemStatusSeverity.neutral,
      );
    }

    if (_isSyncing) {
      return (
        label: 'Syncing...',
        dotColor: AppColors.accent,
        severity: SystemStatusSeverity.active,
      );
    }

    if (_pendingRuns > 0) {
      return (
        label: '$_pendingRuns pending',
        dotColor: AppColors.warning,
        severity: SystemStatusSeverity.warning,
      );
    }

    if (widget.accuracyMeters != null) {
      final acc = widget.accuracyMeters!;
      if (acc <= 10) {
        return (
          label: '±${acc.round()}m',
          dotColor: AppColors.textSecondary,
          severity: SystemStatusSeverity.neutral,
        );
      } else if (acc <= 25) {
        return (
          label: '±${acc.round()}m',
          dotColor: AppColors.textSecondary,
          severity: SystemStatusSeverity.neutral,
        );
      } else {
        return (
          label: 'Weak GPS',
          dotColor: AppColors.warning,
          severity: SystemStatusSeverity.warning,
        );
      }
    }

    return (
      label: 'Ready',
      dotColor: AppColors.textSecondary,
      severity: SystemStatusSeverity.neutral,
    );
  }

  void _showDiagnosticSheet() {
    CombinedStatusIndicator.showDiagnosticSheet(
      context,
      accuracyMeters: widget.accuracyMeters,
      isGpsSearching: widget.isGpsSearching,
      syncQueue: _syncQueue,
      webSocketService: _wsService,
      onExpanded: widget.onExpanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _computeStatus();

    return Semantics(
      button: true,
      label: 'System status: ${status.label}. Tap for details.',
      child: GestureDetector(
        onTap: _showDiagnosticSheet,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadius.brFull,
            border: Border.all(color: AppColors.borderSubtle, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.dotColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticSheetContent extends StatefulWidget {
  final double? accuracyMeters;
  final bool isGpsSearching;
  final SyncQueueService syncQueue;
  final WebSocketService webSocketService;

  const _DiagnosticSheetContent({
    this.accuracyMeters,
    this.isGpsSearching = false,
    required this.syncQueue,
    required this.webSocketService,
  });

  @override
  State<_DiagnosticSheetContent> createState() =>
      _DiagnosticSheetContentState();
}

class _DiagnosticSheetContentState extends State<_DiagnosticSheetContent> {
  VoidCallback? _unsettledListener;
  int _pendingRuns = 0;
  bool _isSyncing = false;
  bool _isLocationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _pendingRuns = widget.syncQueue.unsettledCountNotifier.value;
    _unsettledListener = () {
      if (mounted) {
        setState(
          () => _pendingRuns = widget.syncQueue.unsettledCountNotifier.value,
        );
      }
    };
    widget.syncQueue.unsettledCountNotifier.addListener(_unsettledListener!);
    _checkLocation();
  }

  @override
  void dispose() {
    if (_unsettledListener != null) {
      widget.syncQueue.unsettledCountNotifier.removeListener(
        _unsettledListener!,
      );
    }
    super.dispose();
  }

  Future<void> _checkLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) setState(() => _isLocationServiceEnabled = enabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext buildContext) {
    return AppSheet(
      title: 'System status',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. GPS Diagnostic Row
          _buildRow(
            icon: Icons.my_location_rounded,
            title: 'GPS signal',
            subtitle: !_isLocationServiceEnabled
                ? 'Location services are disabled on this device.'
                : widget.isGpsSearching
                ? 'Searching for satellite lock...'
                : 'Active lock (±${widget.accuracyMeters?.toStringAsFixed(1) ?? "--"}m precision).',
            statusText: !_isLocationServiceEnabled
                ? 'Disabled'
                : widget.isGpsSearching
                ? 'Searching'
                : 'Locked',
            statusColor: !_isLocationServiceEnabled
                ? AppColors.error
                : widget.isGpsSearching
                ? AppColors.textMuted
                : AppColors.accent,
          ),
          const Divider(height: AppSpacing.s24),

          // 2. Cloud Sync Diagnostic Row
          _buildRow(
            icon: Icons.cloud_sync_rounded,
            title: 'Cloud sync queue',
            subtitle: _pendingRuns == 0
                ? 'All runs and territory claims are synchronized.'
                : '$_pendingRuns run loop(s) waiting for connection.',
            statusText: _pendingRuns == 0
                ? 'Up to date'
                : '$_pendingRuns pending',
            statusColor: _pendingRuns == 0
                ? AppColors.accent
                : AppColors.warning,
          ),

          // 3. Live updates calm optional status line (inside sheet only)
          StreamBuilder<bool>(
            stream: widget.webSocketService.isConnectedStream,
            initialData: widget.webSocketService.isConnected,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              if (isConnected) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Live updates unavailable',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.s16),

          // Manual sync trigger
          if (_pendingRuns > 0)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.br8),
                ),
                onPressed: _isSyncing
                    ? null
                    : () async {
                        setState(() => _isSyncing = true);
                        await widget.syncQueue.syncPendingRuns();
                        if (mounted) {
                          setState(() {
                            _isSyncing = false;
                            _pendingRuns =
                                widget.syncQueue.unsettledCountNotifier.value;
                          });
                          Navigator.of(context).maybePop();
                        }
                      },
                child: Text(_isSyncing ? 'Syncing...' : 'Sync now'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String statusText,
    required Color statusColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: AppText.titleSmall),
                  Text(
                    statusText,
                    style: AppText.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                subtitle,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
