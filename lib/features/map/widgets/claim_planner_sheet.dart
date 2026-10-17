import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../routing/route_service.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/motion/motion.dart';

/// Preset area target configuration
class AreaPreset {
  final String label;
  final String title;
  final double areaSqM;

  const AreaPreset({
    required this.label,
    required this.title,
    required this.areaSqM,
  });
}

/// Tactical Explore Claim Planner Modal Sheet.
/// Allows runners to select target territory area (presets or slider),
/// previews the route (real-road OSRM loop or offline synthetic loop),
/// calculates net new unowned area via Clipper2, and starts the run with active guidance.
class ClaimPlannerSheet extends StatefulWidget {
  final LatLng currentLocation;
  final RouteService routeService;
  final ValueChanged<SuggestedRoute> onRouteGenerated;
  final ValueChanged<SuggestedRoute> onStartRun;
  final double initialTargetAreaSqM;
  final SuggestedRoute? initialRoute;

  static const List<AreaPreset> presets = [
    AreaPreset(label: '2,000 m²', title: 'Park', areaSqM: 2000.0),
    AreaPreset(label: '5,000 m²', title: 'District', areaSqM: 5000.0),
    AreaPreset(label: '10,000 m²', title: 'Citadel', areaSqM: 10000.0),
    AreaPreset(label: '25,000 m²', title: 'Empire', areaSqM: 25000.0),
  ];

  const ClaimPlannerSheet({
    super.key,
    required this.currentLocation,
    required this.routeService,
    required this.onRouteGenerated,
    required this.onStartRun,
    this.initialTargetAreaSqM = 5000.0,
    this.initialRoute,
  });

  static Future<void> show({
    required BuildContext context,
    required LatLng currentLocation,
    required RouteService routeService,
    required ValueChanged<SuggestedRoute> onRouteGenerated,
    required ValueChanged<SuggestedRoute> onStartRun,
    double initialTargetAreaSqM = 5000.0,
    SuggestedRoute? initialRoute,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ClaimPlannerSheet(
        currentLocation: currentLocation,
        routeService: routeService,
        onRouteGenerated: onRouteGenerated,
        onStartRun: onStartRun,
        initialTargetAreaSqM: initialTargetAreaSqM,
        initialRoute: initialRoute,
      ),
    );
  }

  @override
  State<ClaimPlannerSheet> createState() => _ClaimPlannerSheetState();
}

class _ClaimPlannerSheetState extends State<ClaimPlannerSheet> {
  late double _targetAreaSqM;
  SuggestedRoute? _currentRoute;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _targetAreaSqM = widget.initialTargetAreaSqM;
    if (widget.initialRoute != null) {
      _currentRoute = widget.initialRoute;
    } else {
      _generateRoute(_targetAreaSqM);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateRoute(double targetArea) async {
    setState(() => _isLoading = true);

    try {
      final route = await widget.routeService.suggestRouteForTargetArea(
        currentLocation: widget.currentLocation,
        targetAreaSqM: targetArea,
      );

      if (mounted) {
        setState(() {
          _currentRoute = route;
          _isLoading = false;
        });
        widget.onRouteGenerated(route);
      }
    } catch (e) {
      // Offline / unexpected error fallback: never crash
      if (mounted) {
        final fallbackRoute = widget.routeService.suggestRoute(
          currentLocation: widget.currentLocation,
          targetDistanceKm: RouteService.targetAreaToDistanceKm(targetArea),
          targetAreaSqM: targetArea,
          isOffline: true,
        );
        setState(() {
          _currentRoute = fallbackRoute;
          _isLoading = false;
        });
        widget.onRouteGenerated(fallbackRoute);
      }
    }
  }

  void _onSliderChanged(double value) {
    setState(() => _targetAreaSqM = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _generateRoute(value);
    });
  }

  void _selectPreset(double area) {
    AppMotion.lightTick();
    setState(() => _targetAreaSqM = area);
    _debounceTimer?.cancel();
    _generateRoute(area);
  }

  @override
  Widget build(BuildContext context) {
    final route = _currentRoute;
    final int projectedXp = route != null
        ? (route.estimatedNewTerritoryAreaSqM / 10.0).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s16, AppSpacing.s20, AppSpacing.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppSpacing.brFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.0),
                ),
                child: const Icon(Icons.explore_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Claim planner',
                      style: AppText.headingSmall,
                    ),
                    Text(
                      'AI loop guidance biased to sovereign expansion',
                      style: AppText.label.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),

          // Area Presets
          Text(
            'Target claim presets',
            style: AppText.label.copyWith(color: AppColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: ClaimPlannerSheet.presets.map((preset) {
              final isSelected = (_targetAreaSqM - preset.areaSqM).abs() < 50.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: GestureDetector(
                    onTap: () => _selectPreset(preset.areaSqM),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: AppSpacing.br12,
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.title,
                            style: TextStyle(
                              color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            preset.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Continuous Target Area Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TARGET AREA',
                style: AppText.label.copyWith(color: AppColors.textSecondary, letterSpacing: 1.1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.br8,
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${_targetAreaSqM.toStringAsFixed(0)} m²',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.secondary,
              inactiveTrackColor: AppColors.surface,
              thumbColor: AppColors.secondary,
              overlayColor: AppColors.secondary.withValues(alpha: 0.2),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: _targetAreaSqM.clamp(1000.0, 50000.0),
              min: 1000.0,
              max: 50000.0,
              divisions: 49,
              onChanged: _onSliderChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Offline Banner / Online Badge
          if (route != null && route.isOffline)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.6), width: 1.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline Mode: Synthetic geodesic loop generated locally without network.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (route != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.0),
              ),
              child: const Row(
                children: [
                  Icon(Icons.directions_walk_rounded, color: AppColors.accent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Real-road pedestrian network matched via OSRM',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Tactical Route Telemetry Grid
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildTelemetryTile(
                      label: 'Est. distance',
                      value: route != null ? '${route.totalDistanceKm.toStringAsFixed(2)} km' : '--',
                      icon: Icons.straighten_rounded,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    _buildTelemetryTile(
                      label: 'Est. duration',
                      value: route != null ? '~${route.estimatedDurationMinutes} min' : '--',
                      icon: Icons.timer_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTelemetryTile(
                      label: 'Est. new area',
                      value: route != null
                          ? '+${route.estimatedNewTerritoryAreaSqM.toStringAsFixed(0)} m²'
                          : '--',
                      icon: Icons.pentagon_outlined,
                      color: AppColors.mine,
                      subtitle: route != null && route.targetAreaSqM > route.estimatedNewTerritoryAreaSqM + 50.0
                          ? 'Overlap deducted'
                          : null,
                    ),
                    const SizedBox(width: 12),
                    _buildTelemetryTile(
                      label: 'Projected XP',
                      value: '+$projectedXp XP',
                      icon: Icons.bolt_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // Action: Start Run with Guidance
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: route != null
                  ? () {
                      AppMotion.mediumTick();
                      Navigator.of(context).maybePop();
                      widget.onStartRun(route);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.surface2,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Start run with route',
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppSpacing.br12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
