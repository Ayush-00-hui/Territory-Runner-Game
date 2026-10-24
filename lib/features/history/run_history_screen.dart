import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../gameplay/territory_service.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../ui/ui.dart';
import 'widgets/history_run_card.dart';

enum HistoryFilter { all, loops, claims, thisWeek, thisMonth }

typedef HistoryTimeFilter = HistoryFilter;

enum HistorySortOption { newest, largestArea, longestDistance }

class RunHistoryScreen extends StatefulWidget {
  final List<Territory>? initialTerritories;
  final RunnerProfile? initialProfile;

  const RunHistoryScreen({
    super.key,
    this.initialTerritories,
    this.initialProfile,
  });

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final TerritoryService _territoryService = TerritoryService();
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

  List<Territory> _filterAndSort(List<Territory> rawList) {
    final now = DateTime.now();

    final filtered = rawList.where((t) {
      switch (_timeFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.loops:
          return t.polygon.length >= 3;
        case HistoryFilter.claims:
          return t.areaSqMeters > 0;
        case HistoryFilter.thisWeek:
          return now.difference(t.capturedAt).inDays <= 7;
        case HistoryFilter.thisMonth:
          return now.difference(t.capturedAt).inDays <= 30;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case HistorySortOption.newest:
          return b.capturedAt.compareTo(a.capturedAt);
        case HistorySortOption.largestArea:
          return b.areaSqMeters.compareTo(a.areaSqMeters);
        case HistorySortOption.longestDistance:
          return _estimateDistanceKm(b.polygon)
              .compareTo(_estimateDistanceKm(a.polygon));
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

  Map<String, List<Territory>> _groupByPeriod(List<Territory> items) {
    final map = <String, List<Territory>>{};
    for (final t in items) {
      final key = _groupKeyForDate(t.capturedAt);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
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
          style: AppText.headingSmall.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: widget.initialProfile != null
          ? _buildArchiveView(
              widget.initialProfile!,
              widget.initialTerritories ?? [],
            )
          : ValueListenableBuilder(
              valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
              builder: (context, Box<RunnerProfile> profileBox, _) {
                final profile = _territoryService.getProfile();

                return ValueListenableBuilder(
                  valueListenable: Hive.box<Territory>('territories_v3')
                      .listenable(),
                  builder: (context, Box<Territory> territoryBox, _) {
                    final rawTerritories = _territoryService
                        .getCapturedTerritoryObjects();
                    return _buildArchiveView(profile, rawTerritories);
                  },
                );
              },
            ),
    );
  }

  Widget _buildArchiveView(
    RunnerProfile profile,
    List<Territory> rawTerritories,
  ) {
    final territories = _filterAndSort(rawTerritories);

    // Compute aggregate stats
    double totalArea = 0.0;
    double totalDist = 0.0;
    for (final t in rawTerritories) {
      totalArea += t.areaSqMeters;
      totalDist += _estimateDistanceKm(t.polygon);
    }

    final totalAreaFormatted = totalArea >= 10000
        ? '${(totalArea / 1000000.0).toStringAsFixed(2)} km²'
        : '${totalArea.toStringAsFixed(0)} m²';

    final isNewestSort = _sortOption == HistorySortOption.newest;
    final groupedRuns = isNewestSort ? _groupByPeriod(territories) : null;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Aggregate metrics summary banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.br20,
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
                      '${rawTerritories.length}',
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
                      '${totalDist.toStringAsFixed(1)} km',
                      AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
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

        // Sort selector row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${territories.length} runs',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                PopupMenuButton<HistorySortOption>(
                  initialValue: _sortOption,
                  color: AppColors.bgElevated,
                  shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                  onSelected: (opt) {
                    AppMotion.selectionTick();
                    setState(() => _sortOption = opt);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: HistorySortOption.newest,
                      child: Text('Newest', style: AppText.bodyMedium),
                    ),
                    const PopupMenuItem(
                      value: HistorySortOption.largestArea,
                      child: Text('Largest area', style: AppText.bodyMedium),
                    ),
                    const PopupMenuItem(
                      value: HistorySortOption.longestDistance,
                      child: Text(
                        'Longest distance',
                        style: AppText.bodyMedium,
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.br8,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortLabel(_sortOption),
                          style: AppText.labelSmall.copyWith(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // List of runs (or Empty state)
        if (territories.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No runs in range',
                  message: 'Try changing your filters or start a new run to claim territory.',
                  actionLabel: _timeFilter != HistoryFilter.all
                      ? 'Reset filters'
                      : null,
                  onAction: _timeFilter != HistoryFilter.all
                      ? () => setState(() => _timeFilter = HistoryFilter.all)
                      : null,
                ),
              ),
            ),
          )
        else if (isNewestSort && groupedRuns != null)
          // Grouped by week/month
          ...groupedRuns.entries.expand((entry) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    AppSpacing.s16,
                    AppSpacing.s20,
                    AppSpacing.s8,
                  ),
                  child: Text(
                    entry.key,
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final territory = entry.value[index];
                    return HistoryRunCard(
                      territory: territory,
                      callsign: profile.username,
                      faction: profile.faction,
                    );
                  }, childCount: entry.value.length),
                ),
              ),
            ];
          })
        else
          // Flat sorted list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s32,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final territory = territories[index];
                return HistoryRunCard(
                  territory: territory,
                  callsign: profile.username,
                  faction: profile.faction,
                );
              }, childCount: territories.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
      ],
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
          AppMotion.selectionTick();
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
              style: AppText.labelSmall.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                fontSize: 11,
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
            style: AppText.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppText.statSmall.copyWith(
              fontSize: 16,
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
