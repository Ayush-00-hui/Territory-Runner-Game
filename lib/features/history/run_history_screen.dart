import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/run_log_entry.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../services/run_log_service.dart';
import '../../ui/ui.dart';
import '../gameplay/territory_service.dart';
import 'widgets/history_run_card.dart';

enum HistoryFilter { all, loops, claims, thisWeek, thisMonth }

typedef HistoryTimeFilter = HistoryFilter;

enum HistorySortOption { newest, largestArea, longestDistance }

class RunHistoryScreen extends StatefulWidget {
  final List<RunLogEntry>? initialRuns;
  final List<Territory>? initialTerritories;
  final RunnerProfile? initialProfile;

  const RunHistoryScreen({
    super.key,
    this.initialRuns,
    this.initialTerritories,
    this.initialProfile,
  });

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final TerritoryService _territoryService = TerritoryService();
  final RunLogService _runLogService = RunLogService();

  HistoryFilter _timeFilter = HistoryFilter.all;
  HistorySortOption _sortOption = HistorySortOption.newest;

  double _estimateDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    const distance = Distance();
    double meters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      meters += distance(points[i], points[i + 1]);
    }
    meters += distance(points.last, points.first);
    return meters / 1000.0;
  }

  List<RunLogEntry> _filterAndSort(List<RunLogEntry> rawList) {
    final now = DateTime.now();

    final filtered = rawList.where((r) {
      switch (_timeFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.loops:
          return r.samples.length >= 3 && r.claimedAreaSqM > 0;
        case HistoryFilter.claims:
          return r.claimedAreaSqM > 0;
        case HistoryFilter.thisWeek:
          return now.difference(r.startedAt).inDays <= 7;
        case HistoryFilter.thisMonth:
          return now.difference(r.startedAt).inDays <= 30;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case HistorySortOption.newest:
          return b.startedAt.compareTo(a.startedAt);
        case HistorySortOption.largestArea:
          return b.claimedAreaSqM.compareTo(a.claimedAreaSqM);
        case HistorySortOption.longestDistance:
          return b.distanceM.compareTo(a.distanceM);
      }
    });

    return filtered;
  }

  String _groupKeyForDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays <= 7) {
      return 'Current week';
    } else if (diffDays <= 14) {
      return 'Last week';
    } else {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    }
  }

  Map<String, List<RunLogEntry>> _groupByPeriod(List<RunLogEntry> items) {
    final map = <String, List<RunLogEntry>>{};
    for (final r in items) {
      final key = _groupKeyForDate(r.startedAt);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  String _formatPace(double? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0) return '--';
    final mins = (secondsPerKm / 60).floor();
    final secs = (secondsPerKm % 60).round();
    return '$mins\'${secs.toString().padLeft(2, '0')}"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Run history',
          style: AppText.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<RunLogEntry>>(
        valueListenable: _runLogService.runsNotifier,
        builder: (context, liveRuns, _) {
          final profile =
              widget.initialProfile ?? _territoryService.getProfile();

          final List<RunLogEntry> effectiveRuns;
          if (widget.initialRuns != null) {
            effectiveRuns = widget.initialRuns!;
          } else if (widget.initialTerritories != null &&
              widget.initialTerritories!.isNotEmpty) {
            effectiveRuns = widget.initialTerritories!.map((t) {
              final distKm = _estimateDistanceKm(t.polygon);
              return RunLogEntry(
                id: t.id,
                startedAt: t.capturedAt,
                endedAt: t.capturedAt.add(
                  Duration(seconds: (distKm * 330).round()),
                ),
                movingSeconds: (distKm * 330).round(),
                totalSeconds: (distKm * 330).round(),
                distanceM: distKm * 1000.0,
                samples: t.polygon
                    .asMap()
                    .entries
                    .map(
                      (e) => RunSample(
                        timeOffsetMs: e.key * 1000,
                        lat: e.value.latitude,
                        lng: e.value.longitude,
                      ),
                    )
                    .toList(),
                claimedAreaSqM: t.areaSqMeters,
                xp: (t.areaSqMeters / 20.0).round(),
              );
            }).toList();
          } else {
            effectiveRuns = liveRuns;
          }

          return _buildArchiveView(profile, effectiveRuns);
        },
      ),
    );
  }

  Widget _buildArchiveView(RunnerProfile profile, List<RunLogEntry> rawRuns) {
    final runs = _filterAndSort(rawRuns);
    final records = _runLogService.computePersonalRecords(
      overrideRuns: rawRuns,
    );

    // Compute aggregate stats from real runs
    double totalArea = 0.0;
    double totalDistM = 0.0;
    for (final r in rawRuns) {
      totalArea += r.claimedAreaSqM;
      totalDistM += r.distanceM;
    }
    final totalDistKm = totalDistM / 1000.0;

    final totalAreaFormatted = totalArea >= 10000
        ? '${(totalArea / 1000000.0).toStringAsFixed(2)} km²'
        : '${totalArea.toStringAsFixed(0)} m²';

    final hasRuns = rawRuns.isNotEmpty;
    final double longestRunKm = records.longestRunDistanceM / 1000.0;
    final double biggestCaptureSqm = records.biggestCaptureSqm;

    final String biggestCaptureFormatted = hasRuns && biggestCaptureSqm > 0
        ? (biggestCaptureSqm >= 10000
              ? '${(biggestCaptureSqm / 1000000.0).toStringAsFixed(2)} km²'
              : '${biggestCaptureSqm.toStringAsFixed(0)} m²')
        : '--';
    final String longestRunFormatted = hasRuns && longestRunKm > 0
        ? '${longestRunKm.toStringAsFixed(2)} km'
        : '--';
    final int effectiveStreak = math.max(
      profile.currentStreak,
      records.longestStreakDays,
    );
    final String streakFormatted = effectiveStreak > 0
        ? '${effectiveStreak}d'
        : '--';
    final String fastestKmFormatted = _formatPace(records.fastestKmPaceSeconds);

    final isNewestSort = _sortOption == HistorySortOption.newest;
    final groupedRuns = isNewestSort ? _groupByPeriod(runs) : null;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        setState(() {});
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Aggregate metrics summary banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s12,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br16,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMetric(
                        'Total area',
                        totalAreaFormatted,
                        AppColors.accent,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Territories',
                        '${rawRuns.length}',
                        AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Total distance',
                        '${totalDistKm.toStringAsFixed(1)} km',
                        AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Personal records section (Phase D4 & F0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Personal records'),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.br16,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryMetric(
                            'Longest run',
                            longestRunFormatted,
                            AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.borderSubtle,
                        ),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Biggest capture',
                            biggestCaptureFormatted,
                            AppColors.accent,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.borderSubtle,
                        ),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Fastest km',
                            fastestKmFormatted,
                            AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: AppColors.borderSubtle,
                        ),
                        Expanded(
                          child: _buildSummaryMetric(
                            'Streak',
                            streakFormatted,
                            AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter chips row
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Row(
                children: [
                  _buildFilterChip(HistoryFilter.all, 'All runs'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildFilterChip(HistoryFilter.loops, 'Loops'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildFilterChip(HistoryFilter.claims, 'Claims'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildFilterChip(HistoryFilter.thisWeek, 'This week'),
                  const SizedBox(width: AppSpacing.s8),
                  _buildFilterChip(HistoryFilter.thisMonth, 'This month'),
                ],
              ),
            ),
          ),

          // Sort Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s14,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${runs.length} ${runs.length == 1 ? 'session' : 'sessions'}',
                    style: AppText.caption.copyWith(color: AppColors.textMuted),
                  ),
                  PopupMenuButton<HistorySortOption>(
                    initialValue: _sortOption,
                    color: AppColors.bgElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.br12,
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    onSelected: (opt) => setState(() => _sortOption = opt),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.touchTarget,
                        minWidth: AppSpacing.touchTarget,
                      ),
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortLabel(_sortOption),
                            style: AppText.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          const Icon(
                            Icons.sort_rounded,
                            size: 20,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: HistorySortOption.newest,
                        child: Text('Newest'),
                      ),
                      const PopupMenuItem(
                        value: HistorySortOption.largestArea,
                        child: Text('Largest area'),
                      ),
                      const PopupMenuItem(
                        value: HistorySortOption.longestDistance,
                        child: Text('Longest distance'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // If no runs exist, display calm empty state (Task F0)
          if (runs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s24,
                  vertical: AppSpacing.s48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: AppColors.textMuted,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      'No runs in range',
                      style: AppText.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'Try changing your filters or start a new run to claim territory.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isNewestSort && groupedRuns != null)
            ...groupedRuns.entries.expand((entry) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s16,
                      AppSpacing.s6,
                    ),
                    child: Text(
                      entry.key,
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final run = entry.value[index];
                      return HistoryRunCard(
                        run: run,
                        callsign: profile.username,
                        faction: profile.faction,
                        onDelete: () => _runLogService.deleteRun(run.id),
                      );
                    }, childCount: entry.value.length),
                  ),
                ),
              ];
            })
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s32,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final run = runs[index];
                  return HistoryRunCard(
                    run: run,
                    callsign: profile.username,
                    faction: profile.faction,
                    onDelete: () => _runLogService.deleteRun(run.id),
                  );
                }, childCount: runs.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
        ],
      ),
    );
  }

  String _sortLabel(HistorySortOption opt) {
    switch (opt) {
      case HistorySortOption.newest:
        return 'Newest';
      case HistorySortOption.largestArea:
        return 'Largest area';
      case HistorySortOption.longestDistance:
        return 'Longest';
    }
  }

  Widget _buildFilterChip(HistoryFilter filter, String label) {
    final isSelected = _timeFilter == filter;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filter: $label',
      child: GestureDetector(
        onTap: () {
          setState(() => _timeFilter = filter);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: AppRadius.brFull,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.borderSubtle,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.caption.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppText.labelSmall.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppText.statSmall.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
