import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../models/runner_profile.dart';
import '../../../services/app_preferences.dart';
import '../../../services/gallery_saver_service.dart';
import '../../../ui/ui.dart';
import '../../coach/llm_coach_service.dart';
import '../../history/widgets/run_share_card_modal.dart';
import 'summary_coach_card.dart';
import 'summary_route_replay.dart';
import 'summary_stats_grid.dart';
import 'summary_victory_header.dart';

/// Modal bottom sheet presented upon completing a run session (Phase D4).
class SummarySheet extends StatefulWidget {
  final double distanceKm;
  final int durationSeconds;
  final int territoriesClaimed;
  final RunnerProfile profile;
  final LLMCoachService coachService;
  final List<LatLng>? routePoints;
  final double? areaSqMeters;
  final String? rejectionReason;

  const SummarySheet({
    super.key,
    required this.distanceKm,
    required this.durationSeconds,
    required this.territoriesClaimed,
    required this.profile,
    required this.coachService,
    this.routePoints,
    this.areaSqMeters,
    this.rejectionReason,
  });

  static Future<void> show({
    required BuildContext context,
    required double distanceKm,
    required int durationSeconds,
    required int territoriesClaimed,
    required RunnerProfile profile,
    required LLMCoachService coachService,
    List<LatLng>? routePoints,
    double? areaSqMeters,
    String? rejectionReason,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SummarySheet(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        territoriesClaimed: territoriesClaimed,
        profile: profile,
        coachService: coachService,
        routePoints: routePoints,
        areaSqMeters: areaSqMeters,
        rejectionReason: rejectionReason,
      ),
    );
  }

  @override
  State<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<SummarySheet>
    with TickerProviderStateMixin {
  late final AnimationController _countUpController;
  late final Animation<double> _countUpAnimation;
  late final AnimationController _replayController;

  @override
  void initState() {
    super.initState();
    _countUpController = AnimationController(
      vsync: this,
      duration: AppMotion.countUp,
    );
    _countUpAnimation = CurvedAnimation(
      parent: _countUpController,
      curve: AppMotion.easeOut,
    );
    _countUpController.forward();

    _replayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.routePoints != null && widget.routePoints!.length >= 2) {
      _replayController.forward();
    } else {
      _replayController.value = 1.0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoSaveRunCard();
    });
  }

  void _triggerAutoSaveRunCard() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
      final route = widget.routePoints;
      if (route == null || route.length < 3) return;
      if (!AppPreferences().isAutoSaveCardEnabled) return;

      final effectiveArea =
          widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
      final renderer = RunShareCardRenderer(
        distanceKm: widget.distanceKm,
        durationSeconds: widget.durationSeconds,
        areaSqMeters: effectiveArea,
        points: route,
        callsign: widget.profile.username.isNotEmpty
            ? widget.profile.username
            : 'RUNNER',
        capturedAt: DateTime.now(),
        theme: ShareCardTheme.athleticDark,
      );

      final pngBytes = await renderer.render();
      final result = await GallerySaverService().savePng(pngBytes);
      if (result.success) {
        AppToast.showGlobal(
          result.message,
          icon: Icons.check_circle_rounded,
          type: AppToastType.success,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countUpController.dispose();
    _replayController.dispose();
    super.dispose();
  }

  String _formatArea() {
    final double effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    if (effectiveArea >= 10000) {
      return '${(effectiveArea / 1000000.0).toStringAsFixed(2)} km²';
    }
    return '${effectiveArea.toStringAsFixed(0)} m²';
  }

  String _buildHeadlineSentence() {
    if (widget.rejectionReason != null) {
      return 'Run completed without claiming territory.';
    }
    final effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    if (effectiveArea > 0) {
      final areaStr = _formatArea();
      if (widget.territoriesClaimed > 1) {
        return 'You claimed $areaStr across ${widget.territoriesClaimed} territories.';
      }
      return 'You claimed $areaStr.';
    }
    return 'You completed ${widget.distanceKm.toStringAsFixed(2)} km.';
  }

  @override
  Widget build(BuildContext context) {
    final effectivePoints = widget.routePoints ?? [];
    final effectiveArea =
        widget.areaSqMeters ?? (widget.territoriesClaimed * 15000.0);
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      AppSpacing.s16,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;
    final calories = (widget.distanceKm * 62).round();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s16,
          AppSpacing.s20,
          bottomInset + AppSpacing.s12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Victory Header
            SummaryVictoryHeader(
              headline: _buildHeadlineSentence(),
              rejectionReason: widget.rejectionReason,
              profile: widget.profile,
              onClose: () => Navigator.pop(context),
            ),

            const SizedBox(height: AppSpacing.s16),

            // 2. Animated Metrics Grid & Splits
            SummaryStatsGrid(
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
              territoriesClaimed: widget.territoriesClaimed,
              effectiveArea: effectiveArea,
              countUpAnimation: _countUpAnimation,
            ),

            const SizedBox(height: AppSpacing.s14),

            // 3. Route Replay & Territory Art
            SummaryRouteReplay(
              routePoints: effectivePoints,
              effectiveArea: effectiveArea,
              calories: calories,
              replayController: _replayController,
            ),

            const SizedBox(height: AppSpacing.s14),

            // 4. AI Coach Card & Actions
            SummaryCoachCard(
              distanceKm: widget.distanceKm,
              durationSeconds: widget.durationSeconds,
              territoriesClaimed: widget.territoriesClaimed,
              effectiveArea: effectiveArea,
              routePoints: effectivePoints,
              profile: widget.profile,
              coachService: widget.coachService,
              onDone: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
