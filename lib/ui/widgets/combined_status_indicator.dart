import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';
import 'app_sheet.dart';
import '../../services/sync_queue.dart';

enum SystemStatusSeverity {
  neutral,
  active,
  warning,
  error,
}

/// Unified, calm, single status indicator.
/// Combines GPS and Cloud Sync status into a single neutral dot + label.
/// Tapping opens an AppSheet with exact diagnostic details.
class CombinedStatusIndicator extends StatefulWidget {
  final double? accuracyMeters;
  final bool isGpsSearching;
  final VoidCallback? onExpanded;

  const CombinedStatusIndicator({
    super.key,
    this.accuracyMeters,
    this.isGpsSearching = false,
    this.onExpanded,
  });

  @override
  State<CombinedStatusIndicator> createState() =>
      _CombinedStatusIndicatorState();
}

class _CombinedStatusIndicatorState extends State<CombinedStatusIndicator> {
  final SyncQueueService _syncQueue = SyncQueueService();
  VoidCallback? _unsettledListener;
  VoidCallback? _statusListener;
  int _pendingRuns = 0;
  bool _isSyncing = false;
  bool _isLocationServiceEnabled = true;

  @override
  void initState() {
    super.initState();
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
        setState(() => _isSyncing = _syncQueue.statusNotifier.value == SyncStatus.syncing);
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
    AppMotion.lightTick();
    widget.onExpanded?.call();

    AppSheet.show(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: 'System status',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. GPS Diagnostic Row
            _buildDiagnosticRow(
              icon: Icons.my_location_rounded,
              title: 'GPS satellite telemetry',
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
            _buildDiagnosticRow(
              icon: Icons.cloud_sync_rounded,
              title: 'Cloud sync queue',
              subtitle: _pendingRuns == 0
                  ? 'All runs and territory claims are synchronized.'
                  : '$_pendingRuns run loop(s) waiting for connection.',
              statusText: _pendingRuns == 0 ? 'Up to date' : '$_pendingRuns pending',
              statusColor:
                  _pendingRuns == 0 ? AppColors.accent : AppColors.warning,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.br8,
                    ),
                  ),
                  onPressed: () async {
                    setState(() => _isSyncing = true);
                    await _syncQueue.syncPendingRuns();
                    if (mounted) {
                      setState(() {
                        _isSyncing = false;
                        _pendingRuns = _syncQueue.unsettledCountNotifier.value;
                      });
                      Navigator.of(context).maybePop();
                    }
                  },
                  child: const Text('Sync now'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow({
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
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
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
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1.0,
            ),
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
